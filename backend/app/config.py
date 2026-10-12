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

# Email for verification codes. Until SMTP_USER and SMTP_PASSWORD are set, no
# email is sent and the code is returned to the app instead (development only).
SMTP_HOST = os.environ.get("SMTP_HOST", "smtp.gmail.com")
SMTP_PORT = int(os.environ.get("SMTP_PORT", "587"))
SMTP_USER = os.environ.get("SMTP_USER")
SMTP_PASSWORD = os.environ.get("SMTP_PASSWORD")
SMTP_FROM = os.environ.get("SMTP_FROM") or SMTP_USER
