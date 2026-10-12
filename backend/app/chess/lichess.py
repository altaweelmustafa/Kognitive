"""Lichess puzzle API client. Free, no key needed."""

import io
from dataclasses import dataclass

import chess
import chess.pgn
import httpx

from .. import config


class LichessError(Exception):
    pass


@dataclass
class Puzzle:
    id: str
    fen: str
    last_move: str | None
    solution: list[str]
    rating: int | None
    themes: list[str]


def _get(path: str) -> dict:
    headers = {"Accept": "application/json"}
    if config.LICHESS_TOKEN:
        headers["Authorization"] = f"Bearer {config.LICHESS_TOKEN}"
    try:
        r = httpx.get(config.LICHESS_URL + path, headers=headers, timeout=10)
        r.raise_for_status()
        return r.json()
    except (httpx.HTTPError, ValueError) as e:
        raise LichessError(str(e)) from e


def parse(data: dict) -> Puzzle:
    """Lichess gives the game's moves up to the puzzle; the puzzle starts after
    the last of them. Replay them to get the start position."""
    try:
        puzzle = data["puzzle"]
        game = chess.pgn.read_game(io.StringIO(data["game"]["pgn"]))
        board = game.end().board()
        return Puzzle(
            id=puzzle["id"],
            fen=board.fen(),
            last_move=board.peek().uci() if board.move_stack else None,
            solution=list(puzzle["solution"]),
            rating=puzzle.get("rating"),
            themes=list(puzzle.get("themes", [])),
        )
    except (KeyError, AttributeError, TypeError) as e:
        raise LichessError(f"unexpected puzzle payload: {e}") from e


def daily() -> Puzzle:
    return parse(_get("/api/puzzle/daily"))


def next_puzzle() -> Puzzle:
    return parse(_get("/api/puzzle/next"))
