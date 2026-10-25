"""The games, as the backend needs to know them. Ids match the app's catalog."""

from dataclasses import dataclass

DOMAINS = ("memory", "attention", "reasoning", "planning", "flexibility")

# In every daily session; the other two slots are picked from the rest.
ALWAYS = ("memory", "attention")


@dataclass(frozen=True)
class Game:
    id: str
    domain: str
    in_sessions: bool = True
    playable: bool = False  # built in the app and scored here


GAMES = (
    Game("memory-matrix", "memory", playable=True),
    Game("suit-recall", "memory"),
    Game("whats-my-name", "memory", playable=True),
    Game("odd-one-out", "attention"),
    Game("points-of-thought", "attention", playable=True),
    Game("24-game", "reasoning"),
    Game("between-the-lines", "reasoning", playable=True),
    Game("apothecary", "planning", playable=True),
    Game("towers-of-stockholm", "flexibility", playable=True),
    Game("quiver", "flexibility", playable=True),
    Game("suit-sort", "flexibility"),
    # Played any day, never part of a session and not scored into the KPI.
    Game("sudoku", "reasoning", in_sessions=False),
    Game("chess-puzzles", "planning", in_sessions=False),
    Game("quick-math", "reasoning", in_sessions=False),
)

BY_ID = {g.id: g for g in GAMES}

# Old id → current id, for data stored before a rename.
RENAMED = {
    "rule-switch-sort": "towers-of-stockholm",
    "train-of-thought": "points-of-thought",
    "magic-sort": "apothecary",
}
