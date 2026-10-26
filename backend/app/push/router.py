"""Notifications: subscribing a browser, the daily reminder, a test push."""

import re

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field, field_validator

from .. import db
from ..auth.router import current_user
from . import service

router = APIRouter(tags=["push"])


class SubscriptionKeys(BaseModel):
    p256dh: str = Field(min_length=1, max_length=200)
    auth: str = Field(min_length=1, max_length=100)


class SubscriptionIn(BaseModel):
    """What the browser's PushSubscription.toJSON() gives."""

    endpoint: str = Field(pattern=r"^https://", max_length=1000)
    keys: SubscriptionKeys


class EndpointIn(BaseModel):
    endpoint: str = Field(max_length=1000)


class ReminderIn(BaseModel):
    enabled: bool
    time: str = Field(pattern=r"^([01]\d|2[0-3]):[0-5]\d$")
    timezone: str = Field(max_length=64)

    @field_validator("timezone")
    @classmethod
    def _known(cls, v: str) -> str:
        if not re.match(r"^[A-Za-z_]+(/[A-Za-z0-9_+\-]+)*$", v):
            raise ValueError("not a time zone name")
        return v


@router.get("/push/key")
def key():
    """The public key browsers need to subscribe."""
    return {"key": service.public_key()}


@router.post("/push/subscriptions", status_code=201)
def subscribe(body: SubscriptionIn, user=Depends(current_user)):
    with db.connect() as conn:
        # A browser moved to another account belongs to that account now.
        conn.execute(
            "INSERT OR REPLACE INTO push_subscriptions (endpoint, user_id, p256dh, auth)"
            " VALUES (?, ?, ?, ?)",
            (body.endpoint, user["id"], body.keys.p256dh, body.keys.auth),
        )
    return {"ok": True}


@router.post("/push/subscriptions/remove")
def unsubscribe(body: EndpointIn, user=Depends(current_user)):
    with db.connect() as conn:
        conn.execute(
            "DELETE FROM push_subscriptions WHERE endpoint = ? AND user_id = ?",
            (body.endpoint, user["id"]),
        )
    return {"ok": True}


def _reminder_out(user_id: int) -> dict:
    with db.connect() as conn:
        r = conn.execute("SELECT * FROM reminders WHERE user_id = ?", (user_id,)).fetchone()
        devices = conn.execute(
            "SELECT COUNT(*) FROM push_subscriptions WHERE user_id = ?", (user_id,)
        ).fetchone()[0]
    return {
        "enabled": bool(r and r["enabled"]),
        "time": r["time"] if r else "19:00",
        "timezone": r["timezone"] if r else "UTC",
        "devices": devices,  # browsers that will get the notification
    }


@router.get("/me/reminder")
def get_reminder(user=Depends(current_user)):
    return _reminder_out(user["id"])


@router.put("/me/reminder")
def set_reminder(body: ReminderIn, user=Depends(current_user)):
    with db.connect() as conn:
        conn.execute(
            "INSERT INTO reminders (user_id, enabled, time, timezone) VALUES (?, ?, ?, ?)"
            " ON CONFLICT (user_id) DO UPDATE SET enabled = excluded.enabled,"
            " time = excluded.time, timezone = excluded.timezone, last_sent_day = NULL",
            (user["id"], int(body.enabled), body.time, body.timezone),
        )
    return _reminder_out(user["id"])


@router.post("/push/test")
def test(user=Depends(current_user)):
    """A notification right now, to check this device gets them."""
    sent = service.send(user["id"], "Kognitiv", "Notifications are on. See you at reminder time!")
    if sent == 0:
        raise HTTPException(409, "No device is set up for notifications yet.")
    return {"sent": sent}
