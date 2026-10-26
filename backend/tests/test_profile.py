"""Profile photo and password, saved library articles, notifications."""

import base64
from datetime import UTC, datetime

import pytest
from fastapi.testclient import TestClient

from app import config, db
from app.push import service as push

from .helpers import signed_up

PNG = b"\x89PNG\r\n\x1a\n" + b"\x00" * 64


@pytest.fixture
def client(tmp_path, monkeypatch):
    monkeypatch.setattr(config, "DB_PATH", tmp_path / "test.db")
    monkeypatch.setattr(config, "VAPID_KEY_FILE", tmp_path / "vapid.pem")
    monkeypatch.setattr(config, "REMINDER_INTERVAL", 0)
    monkeypatch.setattr(config, "ALLOW_REPLAYS", False)
    from app.main import app

    with TestClient(app) as c:
        yield c


def test_avatar(client):
    auth = signed_up(client)
    assert client.get("/me", headers=auth).json()["avatar_version"] == 0
    assert client.get("/me/avatar", headers=auth).json() == {"version": 0, "image": None}

    image = base64.b64encode(PNG).decode()
    assert client.put("/me/avatar", json={"image": "not base64!"}, headers=auth).status_code == 422
    gif = base64.b64encode(b"GIF89a" + b"\x00" * 10).decode()
    assert client.put("/me/avatar", json={"image": gif}, headers=auth).status_code == 422
    huge = base64.b64encode(PNG + b"\x00" * 600_000).decode()
    assert client.put("/me/avatar", json={"image": huge}, headers=auth).status_code == 413

    user = client.put("/me/avatar", json={"image": image}, headers=auth).json()
    assert user["avatar_version"] == 1 and user["name"] == "Dash"
    assert client.get("/me/avatar", headers=auth).json() == {"version": 1, "image": image}
    # Removing it bumps the version too, so other devices drop their copy.
    assert client.delete("/me/avatar", headers=auth).json()["avatar_version"] == 2
    assert client.get("/me/avatar", headers=auth).json()["image"] is None


def test_name_and_password(client):
    auth = signed_up(client, password="correct-horse")
    assert client.patch("/me", json={"name": "Dashiell"}, headers=auth).json()["name"] == "Dashiell"

    # A second device, logged in with the old password.
    login = {"email": "dash@example.com", "password": "correct-horse"}
    other = {"Authorization": f"Bearer {client.post('/auth/login', json=login).json()['token']}"}

    url = "/me/password"
    assert client.post(url, json={"current": "wrong-horse", "new": "battery-staple"}, headers=auth).status_code == 400
    assert client.post(url, json={"current": "correct-horse", "new": "short"}, headers=auth).status_code == 422
    assert client.post(url, json={"current": "correct-horse", "new": "battery-staple"}, headers=auth).json() == {"ok": True}

    # This device stays in; the other is signed out; the new password works.
    assert client.get("/me", headers=auth).status_code == 200
    assert client.get("/me", headers=other).status_code == 401
    assert client.post("/auth/login", json=login).status_code == 401
    assert client.post("/auth/login", json={**login, "password": "battery-staple"}).status_code == 200


def test_library_favourites(client, tmp_path, monkeypatch):
    folder = tmp_path / "content" / "library"
    folder.mkdir(parents=True)
    for slug in ("sleep-well", "walk-more", "eat-fish"):
        (folder / f"{slug}.md").write_text(f"---\ntitle: {slug}\n---\nBody.")
    monkeypatch.setattr(config, "CONTENT_DIR", tmp_path / "content")
    auth = signed_up(client)

    assert client.get("/library/favorites").status_code == 401
    assert client.get("/library/favorites", headers=auth).json() == {"ids": []}
    assert client.put("/library/favorites/no-such-article", headers=auth).status_code == 404
    for slug in ("walk-more", "sleep-well", "walk-more"):  # saving twice is fine
        assert client.put(f"/library/favorites/{slug}", headers=auth).json() == {"saved": True}
    # Most recently saved first.
    assert client.get("/library/favorites", headers=auth).json() == {"ids": ["sleep-well", "walk-more"]}

    assert client.delete("/library/favorites/sleep-well", headers=auth).json() == {"saved": False}
    # An article removed from the library drops out of the list.
    (folder / "walk-more.md").unlink()
    assert client.get("/library/favorites", headers=auth).json() == {"ids": []}


SUB = {"endpoint": "https://web.push.apple.com/abc", "keys": {"p256dh": "BPk", "auth": "xyz"}}


@pytest.fixture
def pushes(monkeypatch):
    """Records pushes instead of sending them."""
    sent = []

    def fake_webpush(info, data, **kwargs):
        sent.append((info["endpoint"], data))

    monkeypatch.setattr(push, "webpush", fake_webpush)
    return sent


def test_push_key_and_subscriptions(client, pushes):
    key = client.get("/push/key").json()["key"]
    # An uncompressed P-256 point: 65 bytes, base64url without padding.
    assert len(base64.urlsafe_b64decode(key + "=")) == 65
    assert client.get("/push/key").json()["key"] == key  # made once, then kept

    auth = signed_up(client)
    assert client.post("/push/test", headers=auth).status_code == 409  # no device yet
    assert client.post("/push/subscriptions", json={**SUB, "endpoint": "http://evil"}, headers=auth).status_code == 422
    assert client.post("/push/subscriptions", json=SUB, headers=auth).status_code == 201
    assert client.get("/me/reminder", headers=auth).json()["devices"] == 1
    assert client.post("/push/test", headers=auth).json() == {"sent": 1}
    assert pushes[0][0] == SUB["endpoint"] and "Notifications are on" in pushes[0][1]

    client.post("/push/subscriptions/remove", json={"endpoint": SUB["endpoint"]}, headers=auth)
    assert client.get("/me/reminder", headers=auth).json()["devices"] == 0


def test_gone_subscriptions_are_dropped(client, monkeypatch):
    from pywebpush import WebPushException

    class Gone:
        status_code = 410

    def gone(*_, **__):
        raise WebPushException("gone", response=Gone())

    monkeypatch.setattr(push, "webpush", gone)
    auth = signed_up(client)
    client.post("/push/subscriptions", json=SUB, headers=auth)
    assert client.post("/push/test", headers=auth).status_code == 409
    assert client.get("/me/reminder", headers=auth).json()["devices"] == 0


def test_daily_reminder(client, pushes):
    auth = signed_up(client)
    client.post("/push/subscriptions", json=SUB, headers=auth)
    assert client.get("/me/reminder", headers=auth).json() == {
        "enabled": False, "time": "19:00", "timezone": "UTC", "devices": 1,
    }
    body = {"enabled": True, "time": "18:30", "timezone": "Europe/Berlin"}
    assert client.put("/me/reminder", json={**body, "time": "25:00"}, headers=auth).status_code == 422
    assert client.put("/me/reminder", json=body, headers=auth).json()["enabled"] is True

    # 16:00 UTC is 17:00 in Berlin in winter: not yet.
    assert push.send_due_reminders(datetime(2026, 1, 15, 16, 0, tzinfo=UTC)) == 0
    # 17:45 UTC is 18:45 in Berlin: due, and only once that day.
    assert push.send_due_reminders(datetime(2026, 1, 15, 17, 45, tzinfo=UTC)) == 1
    assert push.send_due_reminders(datetime(2026, 1, 15, 19, 0, tzinfo=UTC)) == 0
    assert "Your session is ready" in pushes[-1][1] and "4 games waiting" in pushes[-1][1]

    # Switched off: nothing.
    client.put("/me/reminder", json={**body, "enabled": False}, headers=auth)
    assert push.send_due_reminders(datetime(2026, 1, 16, 17, 45, tzinfo=UTC)) == 0


def test_no_reminder_once_the_session_is_done(client, pushes, monkeypatch):
    auth = signed_up(client)
    client.post("/push/subscriptions", json=SUB, headers=auth)
    client.put("/me/reminder", json={"enabled": True, "time": "00:00", "timezone": "UTC"}, headers=auth)
    monkeypatch.setattr(push.brain, "session", lambda _: {"completed": True, "games": []})
    assert push.send_due_reminders() == 0 and pushes == []
    with db.connect() as conn:  # but the day is used up
        assert conn.execute("SELECT last_sent_day FROM reminders").fetchone()[0] is not None
