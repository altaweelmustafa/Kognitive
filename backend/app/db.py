import sqlite3
from collections.abc import Iterator
from contextlib import contextmanager

from . import config

SCHEMA = """
CREATE TABLE IF NOT EXISTS chess_puzzles (
    id         TEXT PRIMARY KEY,
    fen        TEXT NOT NULL,      -- position the player starts from
    last_move  TEXT,               -- opponent move that led to it (UCI)
    solution   TEXT NOT NULL,      -- JSON list of UCI moves, player first
    rating     INTEGER,
    themes     TEXT NOT NULL,      -- JSON list
    fetched_at TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE TABLE IF NOT EXISTS chess_daily (
    day       TEXT PRIMARY KEY,    -- UTC date, YYYY-MM-DD
    puzzle_id TEXT NOT NULL REFERENCES chess_puzzles(id)
);
CREATE TABLE IF NOT EXISTS chess_attempts (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    puzzle_id   TEXT NOT NULL REFERENCES chess_puzzles(id),
    solved      INTEGER NOT NULL,
    mistakes    INTEGER NOT NULL,
    hints       INTEGER NOT NULL,
    duration_ms INTEGER NOT NULL,
    played_at   TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE TABLE IF NOT EXISTS sudoku_attempts (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    puzzle_id   TEXT NOT NULL,     -- encodes seed + difficulty, see sudoku/router.py
    difficulty  TEXT NOT NULL,
    solved      INTEGER NOT NULL,
    mistakes    INTEGER NOT NULL,
    hints       INTEGER NOT NULL,
    duration_ms INTEGER NOT NULL,
    played_at   TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE TABLE IF NOT EXISTS users (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    email         TEXT NOT NULL UNIQUE,   -- lowercase
    name          TEXT NOT NULL,
    gender        TEXT NOT NULL,
    password_hash TEXT NOT NULL,
    verified      INTEGER NOT NULL DEFAULT 0,
    otp_hash      TEXT,
    otp_expires   TEXT,
    otp_attempts  INTEGER NOT NULL DEFAULT 0,
    otp_sent_at   TEXT,
    created_at    TEXT NOT NULL DEFAULT (datetime('now'))
);
CREATE TABLE IF NOT EXISTS sessions (
    token_hash TEXT PRIMARY KEY,
    user_id    INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
-- A Sudoku left unfinished, one per player and puzzle.
CREATE TABLE IF NOT EXISTS sudoku_saves (
    user_id     INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    puzzle_id   TEXT NOT NULL,
    difficulty  TEXT NOT NULL,
    cells       TEXT NOT NULL,     -- 81 digits, 0 = empty
    notes       TEXT NOT NULL,     -- JSON list of 81 bitmasks (bit d-1 = digit d)
    elapsed_ms  INTEGER NOT NULL,
    mistakes    INTEGER NOT NULL,
    hints       INTEGER NOT NULL,
    updated_at  TEXT NOT NULL DEFAULT (datetime('now')),
    PRIMARY KEY (user_id, puzzle_id)
);
-- One scored play of a session game. Feeds the KPI and the forecasts.
CREATE TABLE IF NOT EXISTS game_results (
    id        INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id   INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    game_id   TEXT NOT NULL,
    domain    TEXT NOT NULL,
    score     REAL NOT NULL,
    detail    TEXT NOT NULL,       -- JSON, game specific
    day       TEXT NOT NULL,       -- UTC date
    played_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS game_results_user_day ON game_results (user_id, day);
-- One 60-second run of Quick Math.
CREATE TABLE IF NOT EXISTS quick_math_attempts (
    id        INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id   INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    correct   INTEGER NOT NULL,
    answered  INTEGER NOT NULL,
    played_at TEXT NOT NULL DEFAULT (datetime('now'))
);
-- Library articles a player has saved, newest first by saved_at.
CREATE TABLE IF NOT EXISTS library_favorites (
    user_id    INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    article_id TEXT NOT NULL,
    saved_at   TEXT NOT NULL DEFAULT (datetime('now')),
    PRIMARY KEY (user_id, article_id)
);
-- A browser that agreed to receive notifications (Web Push), one per device.
CREATE TABLE IF NOT EXISTS push_subscriptions (
    endpoint   TEXT PRIMARY KEY,
    user_id    INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    p256dh     TEXT NOT NULL,
    auth       TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
);
-- The daily reminder: a notification at the player's chosen local time if
-- today's session isn't finished.
CREATE TABLE IF NOT EXISTS reminders (
    user_id       INTEGER PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    enabled       INTEGER NOT NULL DEFAULT 0,
    time          TEXT NOT NULL DEFAULT '19:00',   -- HH:MM, local
    timezone      TEXT NOT NULL DEFAULT 'UTC',     -- IANA name
    last_sent_day TEXT                             -- local date, YYYY-MM-DD
);
-- What's My Name?: one card per person a player has met, on an SM-2 schedule.
CREATE TABLE IF NOT EXISTS names_cards (
    user_id        INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    face_id        TEXT NOT NULL,
    introduced_day TEXT NOT NULL,
    repetitions    INTEGER NOT NULL DEFAULT 0,
    ease           REAL NOT NULL,
    interval       INTEGER NOT NULL DEFAULT 0,   -- days
    due_day        TEXT NOT NULL,
    lapses         INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (user_id, face_id)
);
-- A day's session: who was new, who was reviewed and with which question.
CREATE TABLE IF NOT EXISTS names_sessions (
    user_id  INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    day      TEXT NOT NULL,
    new_ids  TEXT NOT NULL,        -- JSON list of face ids
    reviews  TEXT NOT NULL,        -- JSON list of {id, question}
    finished INTEGER NOT NULL DEFAULT 0,
    score    REAL,
    PRIMARY KEY (user_id, day)
);
-- Every typed answer, as given.
CREATE TABLE IF NOT EXISTS names_answers (
    id       INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id  INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    day      TEXT NOT NULL,
    face_id  TEXT NOT NULL,
    question TEXT NOT NULL,        -- name | profession | detail
    phase    TEXT NOT NULL,        -- new | review
    answer   TEXT NOT NULL,
    correct  INTEGER NOT NULL,
    close    INTEGER NOT NULL      -- accepted despite a typo
);
-- The session chosen for a player on a day. Fixed once decided.
CREATE TABLE IF NOT EXISTS session_plans (
    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    day     TEXT NOT NULL,
    plan    TEXT NOT NULL,         -- JSON list of games
    PRIMARY KEY (user_id, day)
);
"""

# Columns added after a table first shipped: (table, column, definition).
MIGRATIONS = [
    ("chess_attempts", "user_id", "INTEGER REFERENCES users(id)"),
    ("sudoku_attempts", "user_id", "INTEGER REFERENCES users(id)"),
    # Profile photo: a small square PNG or JPEG. The version goes up with each
    # change, so apps know when to fetch it again; 0 means none.
    ("users", "avatar", "BLOB"),
    ("users", "avatar_version", "INTEGER NOT NULL DEFAULT 0"),
]


@contextmanager
def connect() -> Iterator[sqlite3.Connection]:
    conn = sqlite3.connect(config.DB_PATH)
    conn.row_factory = sqlite3.Row
    conn.execute("PRAGMA foreign_keys = ON")
    try:
        with conn:
            yield conn
    finally:
        conn.close()


def init() -> None:
    with connect() as conn:
        conn.executescript(SCHEMA)
        for table, column, definition in MIGRATIONS:
            existing = {row["name"] for row in conn.execute(f"PRAGMA table_info({table})")}
            if column not in existing:
                conn.execute(f"ALTER TABLE {table} ADD COLUMN {column} {definition}")
        # Results saved before a game was renamed move to its current name.
        from .brain.catalog import RENAMED

        for old, new in RENAMED.items():
            conn.execute("UPDATE game_results SET game_id = ? WHERE game_id = ?", (new, old))
