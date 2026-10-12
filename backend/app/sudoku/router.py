import json
import re
import secrets
from datetime import UTC, datetime
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from .. import db
from ..auth.router import current_user, optional_user
from . import generator

router = APIRouter(prefix="/sudoku/puzzles", tags=["sudoku"])

Difficulty = Literal["easy", "medium", "hard"]
DAILY_DIFFICULTY: Difficulty = "medium"

# Ids carry everything needed to rebuild the puzzle:
#   daily-2026-10-12        the daily puzzle for that UTC date
#   hard-1a2b3c4d           a practice puzzle: difficulty + random seed
_ID = re.compile(r"^(?:daily-\d{4}-\d{2}-\d{2}|(?:easy|medium|hard)-[0-9a-f]{8})$")


class AttemptIn(BaseModel):
    solved: bool
    mistakes: int = Field(ge=0)
    hints: int = Field(ge=0)
    duration_ms: int = Field(ge=0)


class SaveIn(BaseModel):
    cells: str = Field(pattern=r"^[0-9]{81}$")
    # Pencil marks per cell, as a bitmask: bit d-1 set means digit d is noted.
    notes: list[int] = Field(min_length=81, max_length=81)
    elapsed_ms: int = Field(ge=0)
    mistakes: int = Field(ge=0)
    hints: int = Field(ge=0)


def _difficulty(puzzle_id: str) -> str:
    kind = puzzle_id.split("-", 1)[0]
    return DAILY_DIFFICULTY if kind == "daily" else kind


def _check(puzzle_id: str) -> None:
    if not _ID.match(puzzle_id):
        raise HTTPException(404, "Unknown puzzle")


def _out(puzzle_id: str, user) -> dict:
    """The puzzle, plus the player's unfinished game on it if there is one."""
    difficulty = _difficulty(puzzle_id)
    puzzle, solution = generator.generate(puzzle_id, difficulty)
    save = None
    if user is not None:
        with db.connect() as conn:
            row = conn.execute(
                "SELECT * FROM sudoku_saves WHERE user_id = ? AND puzzle_id = ?",
                (user["id"], puzzle_id),
            ).fetchone()
        if row:
            save = {
                "cells": row["cells"],
                "notes": json.loads(row["notes"]),
                "elapsed_ms": row["elapsed_ms"],
                "mistakes": row["mistakes"],
                "hints": row["hints"],
            }
    return {
        "id": puzzle_id,
        "difficulty": difficulty,
        "puzzle": puzzle,
        "solution": solution,
        "save": save,
    }


@router.get("/daily")
def daily(user=Depends(optional_user)):
    return _out(f"daily-{datetime.now(UTC).date().isoformat()}", user)


@router.get("/next")
def next_puzzle(difficulty: Difficulty = "medium", user=Depends(optional_user)):
    return _out(f"{difficulty}-{secrets.token_hex(4)}", user)


def list_saves(user_id: int) -> list[dict]:
    """A player's unfinished games, most recent first."""
    with db.connect() as conn:
        rows = conn.execute(
            "SELECT * FROM sudoku_saves WHERE user_id = ? ORDER BY updated_at DESC LIMIT 10",
            (user_id,),
        ).fetchall()
    return [
        {
            "puzzle_id": r["puzzle_id"],
            "difficulty": r["difficulty"],
            "daily": r["puzzle_id"].startswith("daily-"),
            "elapsed_ms": r["elapsed_ms"],
            "filled": 81 - r["cells"].count("0"),
            "updated_at": r["updated_at"],
        }
        for r in rows
    ]


def daily_solved(user_id: int) -> bool:
    """Whether the player has solved today's daily Sudoku."""
    with db.connect() as conn:
        return (
            conn.execute(
                "SELECT 1 FROM sudoku_attempts WHERE user_id = ? AND solved = 1 AND puzzle_id = ?",
                (user_id, f"daily-{datetime.now(UTC).date().isoformat()}"),
            ).fetchone()
            is not None
        )


@router.get("/saves")
def saves(user=Depends(current_user)):
    return {"saves": list_saves(user["id"])}


@router.get("/{puzzle_id}")
def puzzle(puzzle_id: str, user=Depends(optional_user)):
    _check(puzzle_id)
    return _out(puzzle_id, user)


@router.put("/{puzzle_id}/save")
def save(puzzle_id: str, body: SaveIn, user=Depends(current_user)):
    _check(puzzle_id)
    if any(not 0 <= n < 512 for n in body.notes):
        raise HTTPException(422, "Bad notes")
    with db.connect() as conn:
        conn.execute(
            "INSERT OR REPLACE INTO sudoku_saves"
            " (user_id, puzzle_id, difficulty, cells, notes, elapsed_ms, mistakes, hints, updated_at)"
            " VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
            (
                user["id"],
                puzzle_id,
                _difficulty(puzzle_id),
                body.cells,
                json.dumps(body.notes),
                body.elapsed_ms,
                body.mistakes,
                body.hints,
                datetime.now(UTC).isoformat(),
            ),
        )
    return {"ok": True}


@router.delete("/{puzzle_id}/save")
def discard(puzzle_id: str, user=Depends(current_user)):
    with db.connect() as conn:
        conn.execute(
            "DELETE FROM sudoku_saves WHERE user_id = ? AND puzzle_id = ?", (user["id"], puzzle_id)
        )
    return {"ok": True}


@router.post("/{puzzle_id}/attempts", status_code=201)
def attempt(puzzle_id: str, body: AttemptIn, user=Depends(current_user)):
    """Stores a finished game and clears its save."""
    _check(puzzle_id)
    with db.connect() as conn:
        conn.execute(
            "INSERT INTO sudoku_attempts"
            " (user_id, puzzle_id, difficulty, solved, mistakes, hints, duration_ms)"
            " VALUES (?, ?, ?, ?, ?, ?, ?)",
            (
                user["id"],
                puzzle_id,
                _difficulty(puzzle_id),
                int(body.solved),
                body.mistakes,
                body.hints,
                body.duration_ms,
            ),
        )
        conn.execute(
            "DELETE FROM sudoku_saves WHERE user_id = ? AND puzzle_id = ?", (user["id"], puzzle_id)
        )
    return {"ok": True}
