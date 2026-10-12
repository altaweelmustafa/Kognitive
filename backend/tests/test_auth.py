from datetime import UTC, datetime, timedelta

import pytest
from fastapi.testclient import TestClient

from app import config, db, mailer
from app.auth import router as auth

from .helpers import signed_up

SIGNUP = {"name": " Dash ", "gender": "male", "email": "Dash@Example.com", "password": "correct-horse"}


@pytest.fixture
def client(tmp_path, monkeypatch):
    monkeypatch.setattr(config, "DB_PATH", tmp_path / "test.db")
    monkeypatch.setattr(config, "SMTP_USER", None)
    from app.main import app

    with TestClient(app) as c:
        yield c


def test_signup_verify_login_logout(client):
    code = client.post("/auth/signup", json=SIGNUP).json()["dev_code"]
    login = {"email": "dash@example.com", "password": "correct-horse"}
    assert client.post("/auth/login", json=login).status_code == 403  # not verified yet

    wrong = "000000" if code != "000000" else "111111"
    assert client.post("/auth/verify", json={"email": "dash@example.com", "code": wrong}).status_code == 400
    r = client.post("/auth/verify", json={"email": "DASH@example.com", "code": code}).json()
    assert r["user"]["name"] == "Dash" and r["user"]["email"] == "dash@example.com"
    assert "password_hash" not in r["user"]
    assert client.post("/auth/verify", json={"email": "dash@example.com", "code": code}).status_code == 404

    assert client.post("/auth/signup", json=SIGNUP).status_code == 409
    assert client.post("/auth/login", json={**login, "password": "nope-nope"}).status_code == 401
    token = client.post("/auth/login", json=login).json()["token"]
    auth_header = {"Authorization": f"Bearer {token}"}

    assert client.get("/me").status_code == 401
    assert client.get("/me", headers=auth_header).json()["gender"] == "male"
    changed = client.patch("/me", json={"name": "D", "gender": "female"}, headers=auth_header).json()
    assert (changed["name"], changed["gender"]) == ("D", "female")

    client.post("/auth/logout", headers=auth_header)
    assert client.get("/me", headers=auth_header).status_code == 401

    with db.connect() as conn:
        stored = conn.execute("SELECT password_hash FROM users").fetchone()[0]
    assert "correct-horse" not in stored


def test_bad_input(client):
    assert client.post("/auth/signup", json={**SIGNUP, "password": "short"}).status_code == 422
    assert client.post("/auth/signup", json={**SIGNUP, "email": "nope"}).status_code == 422
    assert client.post("/auth/signup", json={**SIGNUP, "gender": "x"}).status_code == 422


def test_codes_expire_lock_and_resend(client, monkeypatch):
    email = {"email": "dash@example.com"}
    code = client.post("/auth/signup", json=SIGNUP).json()["dev_code"]
    assert client.post("/auth/resend", json=email).status_code == 429  # too soon

    wrong = "000000" if code != "000000" else "111111"
    for _ in range(auth.CODE_MAX_ATTEMPTS):
        assert client.post("/auth/verify", json={**email, "code": wrong}).status_code == 400
    # Locked: even the right code is refused now.
    assert client.post("/auth/verify", json={**email, "code": code}).status_code == 400

    later = datetime.now(UTC) + timedelta(minutes=2)
    monkeypatch.setattr(auth, "_now", lambda: later)
    fresh = client.post("/auth/resend", json=email).json()["dev_code"]
    much_later = later + timedelta(minutes=11)
    monkeypatch.setattr(auth, "_now", lambda: much_later)
    assert client.post("/auth/verify", json={**email, "code": fresh}).status_code == 400  # expired
    fresh = client.post("/auth/resend", json=email).json()["dev_code"]
    assert client.post("/auth/verify", json={**email, "code": fresh}).status_code == 200


def test_code_is_emailed_not_returned_when_smtp_is_set(client, monkeypatch):
    sent = []
    monkeypatch.setattr(config, "SMTP_USER", "kognitiv@gmail.com")
    monkeypatch.setattr(config, "SMTP_PASSWORD", "app-password")
    monkeypatch.setattr(mailer, "send_code", lambda email, name, code: sent.append((email, code)))
    body = client.post("/auth/signup", json=SIGNUP).json()
    assert body == {"ok": True}
    assert sent[0][0] == "dash@example.com" and len(sent[0][1]) == 6


def test_activity_and_streak(client):
    headers = signed_up(client)
    assert client.get("/me/activity", headers=headers).json() == {
        "days": [],
        "streak": 0,
        "solved": {"chess": 0, "sudoku": 0},
    }
    today = datetime.now(UTC).date()
    with db.connect() as conn:
        for ago in (0, 1, 2, 5):
            conn.execute(
                "INSERT INTO sudoku_attempts"
                " (user_id, puzzle_id, difficulty, solved, mistakes, hints, duration_ms, played_at)"
                " VALUES (1, 'easy-00000000', 'easy', 1, 0, 0, 1, ?)",
                ((today - timedelta(days=ago)).isoformat() + " 12:00:00",),
            )
    body = client.get("/me/activity", headers=headers).json()
    assert body["streak"] == 3 and len(body["days"]) == 4 and body["solved"]["sudoku"] == 4


def test_library(client, tmp_path, monkeypatch):
    listed = client.get("/library/articles").json()["articles"]
    assert [a["id"] for a in listed][:2] == ["feed-your-brain", "up-your-omega-3s"]
    assert listed[0]["category"] == "foods" and "body" not in listed[0]
    assert "## What to eat" in client.get("/library/articles/feed-your-brain").json()["body"]
    assert client.get("/library/articles/nope").status_code == 404

    folder = tmp_path / "library"
    folder.mkdir()
    (folder / "my-note.md").write_text("---\ntitle: My Note\ncategory: to-do\n---\n" + "word " * 450)
    (folder / "no-header.md").write_text("Just text.")
    monkeypatch.setattr(config, "CONTENT_DIR", tmp_path)
    listed = client.get("/library/articles").json()["articles"]
    assert [(a["id"], a["title"], a["minutes"]) for a in listed] == [
        ("my-note", "My Note", 2),
        ("no-header", "No Header", 1),
    ]
