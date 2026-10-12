"""What's My Name?: five new people a day, recalled by typing, with old faces
returning on an SM-2 schedule."""

import json
import random
from datetime import UTC, date, datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from .. import config, db
from ..auth.router import current_user
from ..brain import service as brain
from . import matching, srs
from .people import BY_ID, PEOPLE

router = APIRouter(prefix="/games/whats-my-name", tags=["whats-my-name"])

NEW_PER_DAY = 5
MAX_REVIEWS = 20
GAME_ID = "whats-my-name"


class AnswerIn(BaseModel):
    id: str
    question: str = Field(pattern="^(name|profession|detail)$")
    answer: str = Field(max_length=200)


def _today() -> date:
    return datetime.now(UTC).date()


def _plan(user_id: int, day: date) -> dict:
    """Today's session: who is new and who is up for review. Decided on first
    request and then fixed, so answering doesn't reshuffle it."""
    key = day.isoformat()
    with db.connect() as conn:
        row = conn.execute(
            "SELECT * FROM names_sessions WHERE user_id = ? AND day = ?", (user_id, key)
        ).fetchone()
        if row:
            return {
                "new": json.loads(row["new_ids"]),
                "reviews": json.loads(row["reviews"]),
                "finished": bool(row["finished"]),
                "score": row["score"],
            }

        met = {r["face_id"] for r in conn.execute("SELECT face_id FROM names_cards WHERE user_id = ?", (user_id,))}
        new = [p.id for p in PEOPLE if p.id not in met][:NEW_PER_DAY]
        due = conn.execute(
            "SELECT face_id FROM names_cards WHERE user_id = ? AND due_day <= ? ORDER BY due_day, face_id LIMIT ?",
            (user_id, key, MAX_REVIEWS),
        ).fetchall()
        # Each review asks one thing, picked the same way all day.
        rng = random.Random(f"{user_id}/{key}")
        reviews = [{"id": r["face_id"], "question": rng.choice(matching.QUESTIONS)} for r in due]
        rng.shuffle(reviews)

        for face_id in new:
            conn.execute(
                "INSERT INTO names_cards (user_id, face_id, introduced_day, ease, due_day) VALUES (?, ?, ?, ?, ?)",
                (user_id, face_id, key, srs.START_EASE, (day + timedelta(days=1)).isoformat()),
            )
        conn.execute(
            "INSERT INTO names_sessions (user_id, day, new_ids, reviews) VALUES (?, ?, ?, ?)",
            (user_id, key, json.dumps(new), json.dumps(reviews)),
        )
    return {"new": new, "reviews": reviews, "finished": False, "score": None}


def _answers(user_id: int, day: date) -> list:
    with db.connect() as conn:
        return conn.execute(
            "SELECT * FROM names_answers WHERE user_id = ? AND day = ? ORDER BY id",
            (user_id, day.isoformat()),
        ).fetchall()


def _pool(user_id: int, day: date) -> dict:
    tomorrow = (day + timedelta(days=1)).isoformat()
    with db.connect() as conn:
        people = conn.execute("SELECT COUNT(*) FROM names_cards WHERE user_id = ?", (user_id,)).fetchone()[0]
        due = conn.execute(
            "SELECT COUNT(*) FROM names_cards WHERE user_id = ? AND due_day <= ?", (user_id, tomorrow)
        ).fetchone()[0]
    return {"people": people, "due_tomorrow": due, "still_to_meet": len(PEOPLE) - people}


@router.get("/session")
def session(user=Depends(current_user)):
    day = _today()
    plan = _plan(user["id"], day)
    return {
        "day": day.isoformat(),
        "finished": plan["finished"],
        "score": plan["score"],
        # New people come with everything to study. Reviews come with only the
        # question: the answer stays here.
        "new": [
            {"id": p.id, "name": p.name, "profession": p.profession, "detail": p.detail}
            for p in (BY_ID[i] for i in plan["new"])
        ],
        "reviews": plan["reviews"],
        "answered": [
            {"id": a["face_id"], "question": a["question"], "correct": bool(a["correct"])}
            for a in _answers(user["id"], day)
        ],
        "pool": _pool(user["id"], day),
        "can_reset": config.ALLOW_REPLAYS,
    }


def _reschedule(conn, user_id: int, face_id: str, quality: int, day: date) -> None:
    row = conn.execute(
        "SELECT * FROM names_cards WHERE user_id = ? AND face_id = ?", (user_id, face_id)
    ).fetchone()
    card = srs.review(srs.Card(row["repetitions"], row["ease"], row["interval"]), quality)
    conn.execute(
        "UPDATE names_cards SET repetitions = ?, ease = ?, interval = ?, due_day = ?,"
        " lapses = lapses + ? WHERE user_id = ? AND face_id = ?",
        (
            card.repetitions,
            card.ease,
            card.interval,
            (day + timedelta(days=card.interval)).isoformat(),
            int(quality < 3),
            user_id,
            face_id,
        ),
    )


@router.post("/answer")
def answer(body: AnswerIn, user=Depends(current_user)):
    """Judges one typed answer. Only the first try at each question counts."""
    day = _today()
    plan = _plan(user["id"], day)
    is_new = body.id in plan["new"]
    is_review = {"id": body.id, "question": body.question} in plan["reviews"]
    if not (is_new or is_review):
        raise HTTPException(404, "That question isn't part of today's session.")
    done = _answers(user["id"], day)
    if any(a["face_id"] == body.id and a["question"] == body.question for a in done):
        raise HTTPException(409, "Already answered.")

    person = BY_ID[body.id]
    correct, close = matching.judge(person, body.question, body.answer)
    with db.connect() as conn:
        conn.execute(
            "INSERT INTO names_answers (user_id, day, face_id, question, phase, answer, correct, close)"
            " VALUES (?, ?, ?, ?, ?, ?, ?, ?)",
            (
                user["id"],
                day.isoformat(),
                body.id,
                body.question,
                "new" if is_new else "review",
                body.answer,
                int(correct),
                int(close),
            ),
        )
        if is_review:
            quality = srs.WRONG if not correct else (srs.TYPO if close else srs.EXACT)
            _reschedule(conn, user["id"], body.id, quality, day)
        else:
            # A new person is scheduled once all three questions are in: back
            # tomorrow either way, on a firmer footing if all three were right.
            mine = [a for a in done if a["face_id"] == body.id]
            if len(mine) == len(matching.QUESTIONS) - 1:
                right = sum(a["correct"] for a in mine) + int(correct)
                quality = {3: srs.EXACT, 2: 3}.get(right, srs.WRONG)
                _reschedule(conn, user["id"], body.id, quality, day)
    return {"correct": correct, "close": close, "expected": matching.expected(person, body.question)}


@router.post("/finish")
def finish(user=Depends(current_user)):
    """Closes today's session and scores it: 1000 times the share of answers
    that were right."""
    day = _today()
    plan = _plan(user["id"], day)
    done = _answers(user["id"], day)
    if not done:
        raise HTTPException(400, "Nothing answered yet.")
    correct = sum(a["correct"] for a in done)
    score = plan["score"]
    if not plan["finished"]:
        score = round(1000 * correct / len(done), 1)
        with db.connect() as conn:
            conn.execute(
                "UPDATE names_sessions SET finished = 1, score = ? WHERE user_id = ? AND day = ?",
                (score, user["id"], day.isoformat()),
            )
        try:
            brain.record(
                user["id"],
                GAME_ID,
                score,
                {
                    "asked": len(done),
                    "correct": correct,
                    "new_people": len(plan["new"]),
                    "reviews": len(plan["reviews"]),
                },
            )
        except brain.AlreadyPlayed:
            pass
    return {"score": score, "correct": correct, "asked": len(done), "pool": _pool(user["id"], day)}


@router.post("/reset")
def reset(user=Depends(current_user)):
    """Testing only: forget everyone, so the game starts again from day one."""
    if not config.ALLOW_REPLAYS:
        raise HTTPException(403, "Not available.")
    with db.connect() as conn:
        for table in ("names_cards", "names_answers", "names_sessions"):
            conn.execute(f"DELETE FROM {table} WHERE user_id = ?", (user["id"],))
    return {"ok": True}
