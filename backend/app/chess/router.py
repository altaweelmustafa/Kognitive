import chess
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from ..auth.router import current_user
from . import lichess, service

router = APIRouter(prefix="/chess/puzzles", tags=["chess"])


class MoveIn(BaseModel):
    step: int = Field(ge=0)
    move: str = Field(pattern=r"^[a-h][1-8][a-h][1-8][qrbn]?$")


class AttemptIn(BaseModel):
    solved: bool
    mistakes: int = Field(ge=0)
    hints: int = Field(ge=0)
    duration_ms: int = Field(ge=0)


def _puzzle_out(p: lichess.Puzzle) -> dict:
    return {
        "id": p.id,
        "rating": p.rating,
        "themes": p.themes,
        "player_color": "white" if chess.Board(p.fen).turn == chess.WHITE else "black",
        "state": service.state(p, 0),
    }


def _load(puzzle_id: str) -> lichess.Puzzle:
    try:
        return service.get(puzzle_id)
    except service.PuzzleNotFound:
        raise HTTPException(404, "Unknown puzzle") from None


@router.get("/daily")
def daily():
    try:
        return _puzzle_out(service.daily())
    except lichess.LichessError:
        raise HTTPException(503, "Could not reach Lichess") from None


@router.get("/next")
def next_puzzle():
    try:
        return _puzzle_out(service.another())
    except lichess.LichessError:
        raise HTTPException(503, "Could not reach Lichess") from None


@router.post("/{puzzle_id}/moves")
def move(puzzle_id: str, body: MoveIn):
    try:
        return service.play(_load(puzzle_id), body.step, body.move)
    except service.BadMove as e:
        raise HTTPException(422, str(e)) from None


@router.get("/{puzzle_id}/hint")
def hint(puzzle_id: str, step: int = 0):
    try:
        return service.hint(_load(puzzle_id), step)
    except service.BadMove as e:
        raise HTTPException(422, str(e)) from None


@router.post("/{puzzle_id}/attempts", status_code=201)
def attempt(puzzle_id: str, body: AttemptIn, user=Depends(current_user)):
    _load(puzzle_id)
    service.record_attempt(
        user["id"], puzzle_id, body.solved, body.mistakes, body.hints, body.duration_ms
    )
    return {"ok": True}
