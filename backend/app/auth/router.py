"""Accounts: sign up with an emailed code, log in, profile, activity."""

import hmac
from datetime import UTC, date, datetime, timedelta
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel, Field

from .. import db, mailer
from . import security

router = APIRouter(tags=["account"])
_bearer = HTTPBearer(auto_error=False)

CODE_LIFETIME = timedelta(minutes=10)
CODE_MAX_ATTEMPTS = 5
RESEND_WAIT = timedelta(seconds=60)

Email = Field(pattern=r"^[^@\s]+@[^@\s]+\.[^@\s]+$", max_length=254)
Gender = Literal["male", "female"]


class SignupIn(BaseModel):
    name: str = Field(min_length=1, max_length=80)
    gender: Gender
    email: str = Email
    password: str = Field(min_length=8, max_length=200)


class VerifyIn(BaseModel):
    email: str = Email
    code: str = Field(pattern=r"^\d{6}$")


class EmailIn(BaseModel):
    email: str = Email


class LoginIn(BaseModel):
    email: str = Email
    password: str = Field(max_length=200)


class ProfileIn(BaseModel):
    name: str | None = Field(default=None, min_length=1, max_length=80)
    gender: Gender | None = None


def _now() -> datetime:
    return datetime.now(UTC)


def _user_out(row) -> dict:
    return {
        "id": row["id"],
        "name": row["name"],
        "gender": row["gender"],
        "email": row["email"],
        "created_at": row["created_at"],
    }


def _find(email: str):
    with db.connect() as conn:
        return conn.execute("SELECT * FROM users WHERE email = ?", (email.lower(),)).fetchone()


def optional_user(cred: HTTPAuthorizationCredentials | None = Depends(_bearer)):
    if cred is None:
        return None
    with db.connect() as conn:
        return conn.execute(
            "SELECT users.* FROM sessions JOIN users ON users.id = sessions.user_id"
            " WHERE token_hash = ?",
            (security.digest(cred.credentials),),
        ).fetchone()


def current_user(user=Depends(optional_user)):
    if user is None:
        raise HTTPException(401, "Please log in again.")
    return user


def _send_code(user) -> dict:
    """Issues a fresh code. Without SMTP set up, hands it back to the app
    instead of emailing it."""
    code = security.new_code()
    with db.connect() as conn:
        conn.execute(
            "UPDATE users SET otp_hash = ?, otp_expires = ?, otp_attempts = 0, otp_sent_at = ?"
            " WHERE id = ?",
            (
                security.digest(f"{user['email']}:{code}"),
                (_now() + CODE_LIFETIME).isoformat(),
                _now().isoformat(),
                user["id"],
            ),
        )
    if not mailer.configured():
        print(f"[dev] verification code for {user['email']}: {code}", flush=True)
        return {"ok": True, "dev_code": code}
    try:
        mailer.send_code(user["email"], user["name"], code)
    except mailer.MailError:
        raise HTTPException(502, "Couldn't send the email. Try again.") from None
    return {"ok": True}


def _start_session(user) -> dict:
    token = security.new_token()
    with db.connect() as conn:
        conn.execute(
            "INSERT INTO sessions (token_hash, user_id) VALUES (?, ?)",
            (security.digest(token), user["id"]),
        )
    return {"token": token, "user": _user_out(user)}


@router.post("/auth/signup")
def signup(body: SignupIn):
    existing = _find(body.email)
    if existing and existing["verified"]:
        raise HTTPException(409, "An account with this email already exists.")
    password_hash = security.hash_password(body.password)
    with db.connect() as conn:
        if existing:  # never verified: start over
            conn.execute(
                "UPDATE users SET name = ?, gender = ?, password_hash = ? WHERE id = ?",
                (body.name.strip(), body.gender, password_hash, existing["id"]),
            )
        else:
            conn.execute(
                "INSERT INTO users (email, name, gender, password_hash) VALUES (?, ?, ?, ?)",
                (body.email.lower(), body.name.strip(), body.gender, password_hash),
            )
    return _send_code(_find(body.email))


@router.post("/auth/resend")
def resend(body: EmailIn):
    user = _find(body.email)
    if user is None or user["verified"]:
        raise HTTPException(404, "No sign-up is waiting for this email.")
    wait = RESEND_WAIT - (_now() - datetime.fromisoformat(user["otp_sent_at"]))
    if wait > timedelta(0):
        raise HTTPException(429, f"Wait {int(wait.total_seconds()) + 1}s before asking for another code.")
    return _send_code(user)


@router.post("/auth/verify")
def verify(body: VerifyIn):
    user = _find(body.email)
    if user is None or user["verified"] or user["otp_hash"] is None:
        raise HTTPException(404, "No sign-up is waiting for this email.")
    if _now() > datetime.fromisoformat(user["otp_expires"]) or user["otp_attempts"] >= CODE_MAX_ATTEMPTS:
        raise HTTPException(400, "This code has expired. Ask for a new one.")
    if not hmac.compare_digest(security.digest(f"{user['email']}:{body.code}"), user["otp_hash"]):
        with db.connect() as conn:
            conn.execute("UPDATE users SET otp_attempts = otp_attempts + 1 WHERE id = ?", (user["id"],))
        raise HTTPException(400, "That code isn't right.")
    with db.connect() as conn:
        conn.execute("UPDATE users SET verified = 1, otp_hash = NULL WHERE id = ?", (user["id"],))
    return _start_session(user)


@router.post("/auth/login")
def login(body: LoginIn):
    user = _find(body.email)
    if user is None or not security.check_password(body.password, user["password_hash"]):
        raise HTTPException(401, "Wrong email or password.")
    if not user["verified"]:
        raise HTTPException(403, "This email isn't verified yet. Sign up again to get a new code.")
    return _start_session(user)


@router.post("/auth/logout")
def logout(cred: HTTPAuthorizationCredentials | None = Depends(_bearer)):
    if cred:
        with db.connect() as conn:
            conn.execute("DELETE FROM sessions WHERE token_hash = ?", (security.digest(cred.credentials),))
    return {"ok": True}


@router.get("/me")
def me(user=Depends(current_user)):
    return _user_out(user)


@router.patch("/me")
def update_me(body: ProfileIn, user=Depends(current_user)):
    with db.connect() as conn:
        conn.execute(
            "UPDATE users SET name = COALESCE(?, name), gender = COALESCE(?, gender) WHERE id = ?",
            (body.name.strip() if body.name else None, body.gender, user["id"]),
        )
        return _user_out(conn.execute("SELECT * FROM users WHERE id = ?", (user["id"],)).fetchone())


@router.get("/me/activity")
def activity(user=Depends(current_user)):
    """Days (UTC) on which the player finished a game, and the streak."""
    with db.connect() as conn:
        days = [
            row[0]
            for row in conn.execute(
                "SELECT DISTINCT date(played_at) FROM ("
                " SELECT played_at FROM chess_attempts WHERE user_id = :u AND solved = 1"
                " UNION ALL"
                " SELECT played_at FROM sudoku_attempts WHERE user_id = :u AND solved = 1"
                " UNION ALL"
                " SELECT played_at FROM game_results WHERE user_id = :u"
                " UNION ALL"
                " SELECT played_at FROM quick_math_attempts WHERE user_id = :u"
                ") ORDER BY 1",
                {"u": user["id"]},
            )
        ]
        counts = {
            game: conn.execute(
                f"SELECT COUNT(*) FROM {game}_attempts WHERE user_id = ? AND solved = 1", (user["id"],)
            ).fetchone()[0]
            for game in ("chess", "sudoku")
        }
    played = {date.fromisoformat(d) for d in days}
    # The streak survives until the end of the day after the last play.
    day = _now().date()
    if day not in played:
        day -= timedelta(days=1)
    streak = 0
    while day in played:
        streak += 1
        day -= timedelta(days=1)
    return {"days": days, "streak": streak, "solved": counts}
