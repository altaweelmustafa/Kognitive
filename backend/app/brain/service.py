"""Scores, performance and the daily session plan."""

import json
import random
from datetime import UTC, date, datetime, timedelta

from .. import config, db
from . import catalog, model

SESSION_SIZE = 4


def today() -> date:
    return datetime.now(UTC).date()


class AlreadyPlayed(Exception):
    pass


def played_today(user_id: int) -> set[str]:
    with db.connect() as conn:
        return {
            row["game_id"]
            for row in conn.execute(
                "SELECT DISTINCT game_id FROM game_results WHERE user_id = ? AND day = ?",
                (user_id, today().isoformat()),
            )
        }


def record(user_id: int, game_id: str, score: float, detail: dict) -> None:
    """A session game counts once per day, unless replays are switched on."""
    game = catalog.BY_ID[game_id]
    if not config.ALLOW_REPLAYS and game_id in played_today(user_id):
        raise AlreadyPlayed(game_id)
    with db.connect() as conn:
        conn.execute(
            "INSERT INTO game_results (user_id, game_id, domain, score, detail, day, played_at)"
            " VALUES (?, ?, ?, ?, ?, ?, ?)",
            (
                user_id,
                game_id,
                game.domain,
                score,
                json.dumps(detail),
                today().isoformat(),
                datetime.now(UTC).isoformat(),
            ),
        )


def last_detail(user_id: int, game_id: str) -> dict | None:
    """The stored detail of the player's most recent play of a game."""
    with db.connect() as conn:
        row = conn.execute(
            "SELECT detail FROM game_results WHERE user_id = ? AND game_id = ? ORDER BY id DESC LIMIT 1",
            (user_id, game_id),
        ).fetchone()
    return json.loads(row["detail"]) if row else None


def daily_scores(user_id: int, before: date | None = None) -> dict[str, list[tuple[str, float]]]:
    """Per domain: (day, average score that day), oldest first."""
    query = "SELECT domain, day, AVG(score) AS score FROM game_results WHERE user_id = ?"
    args: list = [user_id]
    if before:
        query += " AND day < ?"
        args.append(before.isoformat())
    series: dict[str, list[tuple[str, float]]] = {d: [] for d in catalog.DOMAINS}
    with db.connect() as conn:
        for row in conn.execute(query + " GROUP BY domain, day ORDER BY day", args):
            series[row["domain"]].append((row["day"], row["score"]))
    return series


def performance(user_id: int, before: date | None = None) -> dict:
    series = daily_scores(user_id, before)
    domains = {}
    for domain, points in series.items():
        analysis = model.analyse([score for _, score in points])
        domains[domain] = {
            **analysis.as_dict(),
            "history": [{"day": day, "score": round(score, 1)} for day, score in points[-14:]],
        }

    # Overall: the average across domains, day by day and now.
    by_day: dict[str, list[float]] = {}
    for points in series.values():
        for day, score in points:
            by_day.setdefault(day, []).append(score)
    levels = [d["level"] for d in domains.values() if d["level"] is not None]
    return {
        "puzzles": puzzle_stats(user_id),
        "overall": round(sum(levels) / len(levels), 1) if levels else None,
        "history": [
            {"day": day, "score": round(sum(v) / len(v), 1)} for day, v in sorted(by_day.items())[-7:]
        ],
        "domains": domains,
    }


# ── chess and sudoku ───────────────────────────────────────
# Outside the session and the KPI, so they get their own numbers. Daily
# puzzles are left out: only practice puzzles count here.

CHESS_START_ELO = 1500  # where Lichess starts a new puzzle solver
CHESS_K_EARLY, CHESS_K = 40, 20
CHESS_EARLY_PUZZLES = 20


def chess_elo(attempts: list[tuple[int, bool]]) -> int | None:
    """Elo estimate from (puzzle rating, solved cleanly) pairs, oldest first.
    A puzzle is won when solved with no wrong move and no hint, lost
    otherwise; the rating moves the way it would after a game against a
    player of the puzzle's rating."""
    if not attempts:
        return None
    elo = float(CHESS_START_ELO)
    for i, (rating, clean) in enumerate(attempts):
        expected = 1 / (1 + 10 ** ((rating - elo) / 400))
        k = CHESS_K_EARLY if i < CHESS_EARLY_PUZZLES else CHESS_K
        elo += k * ((1.0 if clean else 0.0) - expected)
    return round(elo)


def record_quick_math(user_id: int, correct: int, answered: int) -> dict:
    with db.connect() as conn:
        best_before = conn.execute(
            "SELECT MAX(correct) FROM quick_math_attempts WHERE user_id = ?", (user_id,)
        ).fetchone()[0]
        conn.execute(
            "INSERT INTO quick_math_attempts (user_id, correct, answered) VALUES (?, ?, ?)",
            (user_id, correct, answered),
        )
    return {"best": max(correct, best_before or 0), "new_best": best_before is None or correct > best_before}


def puzzle_stats(user_id: int) -> dict:
    with db.connect() as conn:
        chess = conn.execute(
            "SELECT p.rating, a.mistakes, a.hints FROM chess_attempts a"
            " JOIN chess_puzzles p ON p.id = a.puzzle_id"
            " WHERE a.user_id = ? AND a.solved = 1"
            " AND a.puzzle_id NOT IN (SELECT puzzle_id FROM chess_daily)"
            " ORDER BY a.id",
            (user_id,),
        ).fetchall()
        sudoku = dict(
            conn.execute(
                "SELECT difficulty, COUNT(DISTINCT puzzle_id) FROM sudoku_attempts"
                " WHERE user_id = ? AND solved = 1 AND puzzle_id NOT LIKE 'daily-%'"
                " GROUP BY difficulty",
                (user_id,),
            ).fetchall()
        )
        math = conn.execute(
            "SELECT COUNT(*) AS games, MAX(correct) AS best, SUM(correct) AS correct,"
            " SUM(answered) AS answered FROM quick_math_attempts WHERE user_id = ?",
            (user_id,),
        ).fetchone()
    rated = [(r["rating"], r["mistakes"] == 0 and r["hints"] == 0) for r in chess if r["rating"]]
    return {
        "quick_math": {
            "games": math["games"],
            "best": math["best"],  # most correct answers in one run
            "accuracy": round(100 * math["correct"] / math["answered"]) if math["answered"] else None,
        },
        "chess": {"elo": chess_elo(rated), "solved": len(chess)},
        "sudoku": {d: sudoku.get(d, 0) for d in ("easy", "medium", "hard")},
    }


# ── session plan ───────────────────────────────────────────

# Which domains need the work most: lower sorts first.
_NEED = {"none": 0, "declining": 1, "plateau": 2, "improving": 3}
_WHY = {
    "none": "No data yet",
    "declining": "Declining",
    "plateau": "Holding steady",
    "improving": "Improving",
}


def _pick_game(domain: str, last_played: dict[str, str]) -> catalog.Game:
    """A session game from the domain: a playable one if there is any, and the
    one played least recently."""
    games = [g for g in catalog.GAMES if g.domain == domain and g.in_sessions]
    playable = [g for g in games if g.playable]
    games = playable or games
    # Ties (nothing played yet) go to the first in the catalog.
    return min(games, key=lambda g: last_played.get(g.id, ""))


def _build_plan(user_id: int, day: date) -> list[dict]:
    """Memory and Attention always; the other two slots go to the domains
    that need it most, judged on everything played before `day`."""
    perf = performance(user_id, before=day)["domains"]
    rng = random.Random(f"{user_id}/{day.isoformat()}")
    with db.connect() as conn:
        last_played = {
            row["game_id"]: row["last"]
            for row in conn.execute(
                "SELECT game_id, MAX(day) AS last FROM game_results WHERE user_id = ? GROUP BY game_id",
                (user_id,),
            )
        }

    others = [d for d in catalog.DOMAINS if d not in catalog.ALWAYS]
    rng.shuffle(others)
    # Domains with a game that can actually be played come first, so a slot
    # isn't spent on something the player can't do. Then need; among equals,
    # the lower forecast.
    playable = {g.domain for g in catalog.GAMES if g.playable and g.in_sessions}
    others.sort(key=lambda d: (d not in playable, _NEED[perf[d]["trend"]], perf[d]["forecast"] or 0))
    picked = others[: SESSION_SIZE - len(catalog.ALWAYS)]

    plan = []
    for domain in (*catalog.ALWAYS, *picked):
        game = _pick_game(domain, last_played)
        always = domain in catalog.ALWAYS
        plan.append(
            {
                "game_id": game.id,
                "domain": domain,
                "always": always,
                "why": "Always included" if always else _WHY[perf[domain]["trend"]],
                "forecast": perf[domain]["forecast"],
            }
        )
    return plan


def session(user_id: int) -> dict:
    """Today's session. Decided once per day, then kept."""
    day = today()
    with db.connect() as conn:
        row = conn.execute(
            "SELECT plan FROM session_plans WHERE user_id = ? AND day = ?", (user_id, day.isoformat())
        ).fetchone()
    if row:
        plan = json.loads(row["plan"])
        for game in plan:  # plans stored before a game was renamed
            game["game_id"] = catalog.RENAMED.get(game["game_id"], game["game_id"])
    else:
        plan = _build_plan(user_id, day)
        with db.connect() as conn:
            conn.execute(
                "INSERT OR REPLACE INTO session_plans (user_id, day, plan) VALUES (?, ?, ?)",
                (user_id, day.isoformat(), json.dumps(plan)),
            )

    done = played_today(user_id)
    games = [
        {**g, "playable": catalog.BY_ID[g["game_id"]].playable, "done": g["game_id"] in done}
        for g in plan
    ]
    playable = [g for g in games if g["playable"]]
    return {
        "day": day.isoformat(),
        "games": games,
        # Session games already played today: they can't be played again until tomorrow.
        "played_today": sorted(done),
        "replays_allowed": config.ALLOW_REPLAYS,
        "completed": bool(playable) and all(g["done"] for g in playable),
    }


def tomorrow_preview(user_id: int) -> list[dict]:
    """What tomorrow's session would be, given everything played so far."""
    return _build_plan(user_id, today() + timedelta(days=1))
