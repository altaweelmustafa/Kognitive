import os
from pathlib import Path

_ROOT = Path(__file__).parent.parent

DB_PATH = Path(os.environ.get("KOGNITIV_DB", _ROOT / "kognitiv.db"))
LICHESS_URL = os.environ.get("LICHESS_URL", "https://lichess.org")
# Optional. Anonymous access works; a token only raises rate limits.
LICHESS_TOKEN = os.environ.get("LICHESS_TOKEN")

# Testing phase: session games can be replayed on the same day. Every play is
# stored, and a day's score is the average of them. Set KOGNITIV_ALLOW_REPLAYS=0
# to go back to once a day.
ALLOW_REPLAYS = os.environ.get("KOGNITIV_ALLOW_REPLAYS", "1") != "0"

# Library articles: one Markdown file each.
CONTENT_DIR = Path(os.environ.get("KOGNITIV_CONTENT", _ROOT / "content"))

# The website: the Flutter web build, put here by scripts/deploy_web.sh.
WEB_DIR = Path(os.environ.get("KOGNITIV_WEB", _ROOT / "web"))

# Notifications (Web Push). The key pair is made on first use, next to the
# database. Push services want a contact for the sender: set
# KOGNITIV_VAPID_SUBJECT to a mailto: or https: address you control.
VAPID_KEY_FILE = Path(os.environ.get("KOGNITIV_VAPID_KEY", DB_PATH.parent / "vapid_private.pem"))
VAPID_SUBJECT = os.environ.get("KOGNITIV_VAPID_SUBJECT", "mailto:admin@example.com")
# How often the reminder loop looks for reminders that are due, in seconds.
# 0 turns the loop off (tests).
REMINDER_INTERVAL = int(os.environ.get("KOGNITIV_REMINDER_INTERVAL", "60"))

# Email for verification codes. Until SMTP_USER and SMTP_PASSWORD are set, no
# email is sent and the code is returned to the app instead (development only).
SMTP_HOST = os.environ.get("SMTP_HOST", "smtp.gmail.com")
SMTP_PORT = int(os.environ.get("SMTP_PORT", "587"))
SMTP_USER = os.environ.get("SMTP_USER")
SMTP_PASSWORD = os.environ.get("SMTP_PASSWORD")
SMTP_FROM = os.environ.get("SMTP_FROM") or SMTP_USER
