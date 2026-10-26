"""Web Push: the server's signing keys, sending, and the daily reminder.

Browsers (including iPhone home-screen web apps, iOS 16.4+) receive pushes
through their vendor's push service. Each push is signed with this server's
VAPID key pair, which is made on first use and kept beside the database.
"""

import base64
import json
import logging
from datetime import datetime
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError

from cryptography.hazmat.primitives import serialization
from py_vapid import Vapid
from pywebpush import WebPushException, webpush

from .. import config, db
from ..brain import service as brain

log = logging.getLogger("kognitiv.push")


def _vapid() -> Vapid:
    path = config.VAPID_KEY_FILE
    if not path.exists():
        key = Vapid()
        key.generate_keys()
        path.parent.mkdir(parents=True, exist_ok=True)
        key.save_key(str(path))
        path.chmod(0o600)
    return Vapid.from_file(str(path))


def public_key() -> str:
    """The key browsers subscribe with: base64url, uncompressed P-256 point."""
    raw = _vapid().public_key.public_bytes(
        serialization.Encoding.X962, serialization.PublicFormat.UncompressedPoint
    )
    return base64.urlsafe_b64encode(raw).rstrip(b"=").decode()


def send(user_id: int, title: str, body: str, url: str = "/") -> int:
    """Sends to every device the player subscribed. Returns how many took it.
    Subscriptions the push service says are gone are deleted."""
    with db.connect() as conn:
        subs = conn.execute(
            "SELECT * FROM push_subscriptions WHERE user_id = ?", (user_id,)
        ).fetchall()
    payload = json.dumps({"title": title, "body": body, "url": url})
    sent = 0
    for s in subs:
        info = {"endpoint": s["endpoint"], "keys": {"p256dh": s["p256dh"], "auth": s["auth"]}}
        try:
            webpush(
                info,
                data=payload,
                vapid_private_key=str(config.VAPID_KEY_FILE),
                vapid_claims={"sub": config.VAPID_SUBJECT},
                ttl=6 * 3600,
            )
            sent += 1
        except WebPushException as e:
            status = e.response.status_code if e.response is not None else None
            if status in (404, 410):
                with db.connect() as conn:
                    conn.execute("DELETE FROM push_subscriptions WHERE endpoint = ?", (s["endpoint"],))
            else:
                log.warning("push to user %s failed: %s", user_id, e)
    return sent


def local_now(timezone: str, now: datetime | None = None) -> datetime:
    try:
        zone = ZoneInfo(timezone)
    except (ZoneInfoNotFoundError, ValueError):
        zone = ZoneInfo("UTC")
    return (now or datetime.now(ZoneInfo("UTC"))).astimezone(zone)


def send_due_reminders(now: datetime | None = None) -> int:
    """One pass of the reminder loop: everyone whose reminder time has come
    today (in their own time zone), who hasn't had one today and hasn't
    finished today's session, gets a notification. Returns how many were sent."""
    with db.connect() as conn:
        due = conn.execute(
            "SELECT r.* FROM reminders r WHERE r.enabled = 1"
            " AND EXISTS (SELECT 1 FROM push_subscriptions s WHERE s.user_id = r.user_id)"
        ).fetchall()
    count = 0
    for r in due:
        local = local_now(r["timezone"], now)
        today = local.date().isoformat()
        if r["last_sent_day"] == today or local.strftime("%H:%M") < r["time"]:
            continue
        plan = brain.session(r["user_id"])
        if not plan["completed"]:
            left = sum(1 for g in plan["games"] if g["playable"] and not g["done"])
            body = (
                f"{left} game{'s' if left != 1 else ''} waiting. A few minutes keeps your streak going."
            )
            if send(r["user_id"], "Your session is ready", body, "/#/session"):
                count += 1
        # Marked either way: one chance a day, even if the session was done.
        with db.connect() as conn:
            conn.execute(
                "UPDATE reminders SET last_sent_day = ? WHERE user_id = ?", (today, r["user_id"])
            )
    return count
