"""Puzzle storage and move checking. The solution never leaves the server."""

import json
from datetime import UTC, datetime

import chess

from .. import db
from . import lichess
from .lichess import Puzzle


class PuzzleNotFound(Exception):
    pass


class BadMove(Exception):
    pass


# ── storage ────────────────────────────────────────────────


def _save(p: Puzzle) -> None:
    with db.connect() as conn:
        conn.execute(
            "INSERT OR REPLACE INTO chess_puzzles (id, fen, last_move, solution, rating, themes)"
            " VALUES (?, ?, ?, ?, ?, ?)",
            (p.id, p.fen, p.last_move, json.dumps(p.solution), p.rating, json.dumps(p.themes)),
        )


def _from_row(row) -> Puzzle:
    return Puzzle(
        id=row["id"],
        fen=row["fen"],
        last_move=row["last_move"],
        solution=json.loads(row["solution"]),
        rating=row["rating"],
        themes=json.loads(row["themes"]),
    )


def get(puzzle_id: str) -> Puzzle:
    with db.connect() as conn:
        row = conn.execute("SELECT * FROM chess_puzzles WHERE id = ?", (puzzle_id,)).fetchone()
    if row is None:
        raise PuzzleNotFound(puzzle_id)
    return _from_row(row)


def daily() -> Puzzle:
    """Today's Lichess puzzle, fetched once per UTC day. If Lichess is
    unreachable, falls back to the most recent daily we have."""
    today = datetime.now(UTC).date().isoformat()
    with db.connect() as conn:
        row = conn.execute("SELECT puzzle_id FROM chess_daily WHERE day = ?", (today,)).fetchone()
    if row:
        return get(row["puzzle_id"])
    try:
        puzzle = lichess.daily()
    except lichess.LichessError:
        with db.connect() as conn:
            row = conn.execute(
                "SELECT puzzle_id FROM chess_daily ORDER BY day DESC LIMIT 1"
            ).fetchone()
        if row is None:
            raise
        return get(row["puzzle_id"])
    _save(puzzle)
    with db.connect() as conn:
        conn.execute("INSERT OR REPLACE INTO chess_daily (day, puzzle_id) VALUES (?, ?)", (today, puzzle.id))
    return puzzle


def daily_solved(user_id: int) -> bool:
    """Whether the player has solved today's daily puzzle."""
    today = datetime.now(UTC).date().isoformat()
    with db.connect() as conn:
        return (
            conn.execute(
                "SELECT 1 FROM chess_attempts a JOIN chess_daily d ON d.puzzle_id = a.puzzle_id"
                " WHERE a.user_id = ? AND a.solved = 1 AND d.day = ?",
                (user_id, today),
            ).fetchone()
            is not None
        )


def another() -> Puzzle:
    """A fresh puzzle for extra practice."""
    puzzle = lichess.next_puzzle()
    _save(puzzle)
    return puzzle


def record_attempt(
    user_id: int, puzzle_id: str, solved: bool, mistakes: int, hints: int, duration_ms: int
) -> None:
    get(puzzle_id)
    with db.connect() as conn:
        conn.execute(
            "INSERT INTO chess_attempts (user_id, puzzle_id, solved, mistakes, hints, duration_ms)"
            " VALUES (?, ?, ?, ?, ?, ?)",
            (user_id, puzzle_id, int(solved), mistakes, hints, duration_ms),
        )


# ── play ───────────────────────────────────────────────────
# `step` = how many moves the player has made. The solution alternates
# player, opponent, player, ... so the position at a step is the start
# position plus the first 2*step solution moves.


def total_steps(p: Puzzle) -> int:
    return (len(p.solution) + 1) // 2


def board_at(p: Puzzle, step: int) -> chess.Board:
    if not 0 <= step <= total_steps(p):
        raise BadMove(f"step must be between 0 and {total_steps(p)}")
    board = chess.Board(p.fen)
    for uci in p.solution[: 2 * step]:
        board.push(board.parse_uci(uci))
    return board


def state(p: Puzzle, step: int, board: chess.Board | None = None, solved: bool | None = None) -> dict:
    board = board or board_at(p, step)
    solved = step >= total_steps(p) if solved is None else solved
    if board.move_stack:
        last_move = board.peek().uci()
    else:
        last_move = p.last_move
    return {
        "fen": board.fen(),
        "last_move": last_move,
        "legal_moves": [] if solved else [m.uci() for m in board.legal_moves],
        "check": board.is_check(),
        "step": step,
        "total_steps": total_steps(p),
        "solved": solved,
    }


def play(p: Puzzle, step: int, uci: str) -> dict:
    """Check the player's move at `step`. On a correct move, also plays the
    opponent's reply."""
    if step >= total_steps(p):
        raise BadMove("puzzle already solved")
    board = board_at(p, step)
    try:
        move = board.parse_uci(uci)
    except ValueError as e:
        raise BadMove(f"illegal move: {uci}") from e
    expected = board.parse_uci(p.solution[2 * step])

    board.push(move)
    # Any checkmate counts, even if it isn't the listed one.
    mate = board.is_checkmate()
    if move != expected and not mate:
        return {"correct": False, "after_move": None, "state": state(p, step)}

    after_move = state(p, step, board, solved=False)
    after_move["legal_moves"] = []
    step += 1
    if mate or step >= total_steps(p):
        return {"correct": True, "after_move": after_move, "state": state(p, step, board, solved=True)}
    board.push(board.parse_uci(p.solution[2 * step - 1]))
    return {"correct": True, "after_move": after_move, "state": state(p, step, board)}


def hint(p: Puzzle, step: int) -> dict:
    if step >= total_steps(p):
        raise BadMove("puzzle already solved")
    move = board_at(p, step).parse_uci(p.solution[2 * step])
    return {"from": chess.square_name(move.from_square), "to": chess.square_name(move.to_square)}
