import json
from datetime import timedelta

import numpy as np
import pytest
from fastapi.testclient import TestClient

from app import config, db
from app.brain import model, service
from app.brain.router import (
    ApothecaryTrial,
    apothecary_score,
    MatrixTrial,
    TowersTrial,
    PointsRound,
    memory_matrix_score,
    towers_score,
    points_score,
)

from .helpers import signed_up


def series(n, slope, noise=40, start=900, seed=0):
    rng = np.random.default_rng(seed)
    return list(start + slope * np.arange(n) + rng.normal(0, noise, n))


def test_too_little_history_makes_no_claim():
    assert model.analyse([]).trend == "none"
    a = model.analyse([800, 1000])
    assert (a.method, a.trend, a.forecast) == ("average", "plateau", 900)


@pytest.mark.parametrize("n,method", [(8, "linear"), (14, "arima"), (40, "arima")])
def test_a_clear_trend_is_detected(n, method):
    for seed in range(6):
        up = model.analyse(series(n, 15, noise=15, seed=seed))
        down = model.analyse(series(n, -15, noise=15, seed=seed))
        assert (up.method, up.trend) == (method, "improving")
        assert (down.method, down.trend) == (method, "declining")
        assert up.forecast > up.level > down.level > down.forecast


def test_noise_alone_is_rarely_called_a_trend():
    # Each direction is allowed a 5% false-alarm rate, so about 10% in total.
    for n in (4, 6, 12, 30):
        wrong = sum(model.analyse(series(n, 0, seed=seed)).trend != "plateau" for seed in range(40))
        assert wrong <= 8, (n, wrong)


def test_recent_direction_wins_over_old_history():
    # Sixty days of improvement, then thirty of decline.
    scores = series(60, 10, noise=15) + series(30, -10, noise=15, start=1500)
    assert model.analyse(scores).trend == "declining"


def test_memory_matrix_score():
    perfect = [MatrixTrial(nodes=n, found=n, duration_ms=1) for n in range(8, 16)]
    assert memory_matrix_score(perfect) == 1150
    assert memory_matrix_score([MatrixTrial(nodes=8, found=0, duration_ms=1)] * 8) == 0


@pytest.fixture
def client(tmp_path, monkeypatch):
    monkeypatch.setattr(config, "DB_PATH", tmp_path / "test.db")
    monkeypatch.setattr(config, "ALLOW_REPLAYS", False)  # the real rule: once a day
    from app.main import app

    with TestClient(app) as c:
        yield c


def add_history(domain, game_id, scores, user_id=1):
    """One result per day, ending yesterday."""
    today = service.today()
    with db.connect() as conn:
        for i, score in enumerate(scores):
            day = (today - timedelta(days=len(scores) - i)).isoformat()
            conn.execute(
                "INSERT INTO game_results (user_id, game_id, domain, score, detail, day, played_at)"
                " VALUES (?, ?, ?, ?, '{}', ?, ?)",
                (user_id, game_id, domain, score, day, day + "T12:00:00+00:00"),
            )


def test_play_memory_matrix_and_see_it_everywhere(client):
    auth = signed_up(client)
    trials = [{"nodes": 8 + i, "found": 8 + i, "duration_ms": 4000} for i in range(7)]
    trials.append({"nodes": 15, "found": 3, "duration_ms": 2500})  # missed the last one

    url = "/games/memory-matrix/results"
    assert client.post(url, json={"trials": trials}).status_code == 401
    assert client.post(url, json={"trials": trials[:5]}, headers=auth).status_code == 422
    bad = [*trials[:7], {"nodes": 8, "found": 9, "duration_ms": 1}]
    assert client.post(url, json={"trials": bad}, headers=auth).status_code == 422

    session = client.get("/session/today", headers=auth).json()
    assert [g["game_id"] for g in session["games"][:2]] == ["memory-matrix", "odd-one-out"] or session["games"][1]["domain"] == "attention"
    assert session["games"][0] == {
        "game_id": "memory-matrix", "domain": "memory", "always": True, "why": "Always included",
        "forecast": None, "playable": True, "done": False,
    }
    assert len(session["games"]) == 4 and not session["completed"]

    score = client.post(url, json={"trials": trials}, headers=auth).json()["score"]
    assert score == round(100 * (sum(range(8, 15)) + 3) / 8, 1)

    perf = client.get("/me/performance", headers=auth).json()
    assert perf["overall"] == score and perf["history"][-1]["score"] == score
    assert perf["domains"]["memory"]["n"] == 1 and perf["domains"]["memory"]["trend"] == "plateau"
    assert perf["domains"]["planning"] == {
        "n": 0, "level": None, "forecast": None, "change_per_day": None,
        "trend": "none", "method": "none", "history": [],
    }

    session = client.get("/session/today", headers=auth).json()
    assert session["games"][0]["done"]
    # Complete once every game that can be played has been.
    assert session["completed"] == all(g["done"] for g in session["games"] if g["playable"])
    assert session["played_today"] == ["memory-matrix"]

    # Once a day: a second play today is refused and changes nothing ...
    assert client.post(url, json={"trials": trials}, headers=auth).status_code == 409
    assert client.get("/me/performance", headers=auth).json()["domains"]["memory"]["n"] == 1
    # ... but tomorrow it is open again.
    with db.connect() as conn:
        yesterday = (service.today() - timedelta(days=1)).isoformat()
        conn.execute("UPDATE game_results SET day = ?", (yesterday,))
    assert client.get("/session/today", headers=auth).json()["played_today"] == []
    assert client.post(url, json={"trials": trials}, headers=auth).status_code == 201
    assert client.get("/me/activity", headers=auth).json()["streak"] == 1
    with db.connect() as conn:
        detail = json.loads(conn.execute("SELECT detail FROM game_results").fetchone()[0])
    assert detail["perfect_trials"] == 7 and detail["max_nodes"] == 14


def test_session_goes_to_the_domains_that_need_it(client):
    auth = signed_up(client)
    add_history("memory", "memory-matrix", series(14, 0))
    add_history("reasoning", "24-game", series(14, 12, noise=10))  # improving
    add_history("planning", "apothecary", series(14, -12, noise=10))  # declining
    add_history("flexibility", "towers-of-stockholm", series(14, 0, noise=10, start=600))  # flat, low

    perf = client.get("/me/performance", headers=auth).json()["domains"]
    assert [perf[d]["trend"] for d in ("reasoning", "planning", "flexibility")] == [
        "improving", "declining", "plateau",
    ]
    assert perf["planning"]["method"] == "arima"

    # Reasoning has no playable game, so it waits; of the two that do, the
    # declining one goes first.
    games = client.get("/session/today", headers=auth).json()["games"]
    assert [g["domain"] for g in games] == ["memory", "attention", "planning", "flexibility"]
    assert [g["why"] for g in games[2:]] == ["Declining", "Holding steady"]
    assert [g["playable"] for g in games] == [True, True, True, True]

    # Decided once: new results today don't reshuffle today's session ...
    add_history("planning", "apothecary", [5000] * 3)
    assert client.get("/session/today", headers=auth).json()["games"] == games
    # ... but they do count for tomorrow.
    tomorrow = client.get("/session/tomorrow", headers=auth).json()["games"]
    assert len(tomorrow) == 4 and tomorrow[0]["domain"] == "memory"


def test_new_player_gets_a_full_session(client):
    auth = signed_up(client)
    games = client.get("/session/today", headers=auth).json()["games"]
    assert len(games) == 4 and len({g["domain"] for g in games}) == 4
    # The two free slots go to the domains that have a playable game.
    assert {g["game_id"] for g in games[2:]} == {"towers-of-stockholm", "apothecary"}
    assert [g["why"] for g in games] == ["Always included", "Always included", "No data yet", "No data yet"]


def test_a_plan_stored_before_a_rename_still_loads(client):
    auth = signed_up(client)
    plan = [{"game_id": "rule-switch-sort", "domain": "flexibility", "always": False, "why": "No data yet", "forecast": None}]
    with db.connect() as conn:
        conn.execute(
            "INSERT INTO session_plans (user_id, day, plan) VALUES (1, ?, ?)",
            (service.today().isoformat(), json.dumps(plan)),
        )
    games = client.get("/session/today", headers=auth).json()["games"]
    assert [g["game_id"] for g in games] == ["towers-of-stockholm"]


def test_towers_of_stockholm(client):
    perfect = [TowersTrial(optimal=n, moves=n, solved=True, duration_ms=1) for n in (3, 4, 5, 6, 7)]
    assert towers_score(perfect) == 1000
    assert towers_score([TowersTrial(optimal=4, moves=8, solved=False, duration_ms=1)] * 5) == 0
    # Twice the moves is worth half.
    assert towers_score([TowersTrial(optimal=4, moves=8, solved=True, duration_ms=1)] * 5) == 400

    auth = signed_up(client)
    trials = [{"optimal": 3, "moves": 3, "solved": True, "duration_ms": 9000}] * 5
    url = "/games/towers-of-stockholm/results"
    impossible = [{**trials[0], "moves": 2}, *trials[1:]]
    assert client.post(url, json={"trials": impossible}, headers=auth).status_code == 422
    assert client.post(url, json={"trials": trials[:4]}, headers=auth).status_code == 422
    assert client.post(url, json={"trials": trials}, headers=auth).json() == {"score": 600}
    assert client.post(url, json={"trials": trials}, headers=auth).status_code == 409

    perf = client.get("/me/performance", headers=auth).json()
    assert perf["domains"]["flexibility"]["level"] == 600 and perf["overall"] == 600
    assert client.get("/session/today", headers=auth).json()["played_today"] == ["towers-of-stockholm"]


def test_points_of_thought(client):
    def one(level, correct):
        return [PointsRound(level=level, points=10, correct=correct, duration_ms=1)]

    assert points_score(one(2, 10)) == 700
    assert points_score(one(8, 10)) == 1300
    assert points_score(one(2, 5)) == 350

    auth = signed_up(client)
    url = "/games/points-of-thought/results"
    assert client.get("/games/points-of-thought/level", headers=auth).json() == {"level": 2}

    def play(level, correct):
        body = {"rounds": [{"level": level, "points": 10, "correct": correct, "duration_ms": 50000}]}
        r = client.post(url, json=body, headers=auth)
        # Free the game for the next "day".
        with db.connect() as conn:
            conn.execute("UPDATE game_results SET day = '2000-01-01'")
        return r

    round_ = {"level": 2, "points": 10, "correct": 9, "duration_ms": 50000}
    assert client.post(url, json={"rounds": [{**round_, "correct": 11}]}, headers=auth).status_code == 422
    assert client.post(url, json={"rounds": [round_, round_]}, headers=auth).status_code == 422  # one round a session
    assert client.post(url, json={"rounds": [round_]}, headers=auth).json() == {"score": 630}
    assert client.post(url, json={"rounds": [round_]}, headers=auth).status_code == 409  # once a day

    # The level carries over to the next session.
    assert client.get("/games/points-of-thought/level", headers=auth).json() == {"level": 3}
    with db.connect() as conn:
        conn.execute("UPDATE game_results SET day = '2000-01-01'")
    play(3, 8)  # held its own: stays
    assert client.get("/games/points-of-thought/level", headers=auth).json() == {"level": 3}
    play(3, 4)  # struggled: down
    assert client.get("/games/points-of-thought/level", headers=auth).json() == {"level": 2}
    play(1, 0)
    assert client.get("/games/points-of-thought/level", headers=auth).json() == {"level": 1}
    play(8, 10)
    assert client.get("/games/points-of-thought/level", headers=auth).json() == {"level": 8}


def test_points_of_thought_fills_the_attention_slot(client):
    auth = signed_up(client)
    round_ = {"level": 2, "points": 10, "correct": 8, "duration_ms": 50000}
    client.post("/games/points-of-thought/results", json={"rounds": [round_]}, headers=auth)
    assert client.get("/me/performance", headers=auth).json()["domains"]["attention"]["level"] == 560
    games = client.get("/session/today", headers=auth).json()["games"]
    assert games[1]["game_id"] == "points-of-thought" and games[1]["done"]


def test_results_stored_under_an_old_game_name_are_carried_over(client):
    auth = signed_up(client)
    add_history("attention", "train-of-thought", [700, 720, 740])
    db.init()  # runs at every start
    with db.connect() as conn:
        assert {r[0] for r in conn.execute("SELECT game_id FROM game_results")} == {"points-of-thought"}
    assert client.get("/me/performance", headers=auth).json()["domains"]["attention"]["n"] == 3


def test_today_status_for_the_home_screen(client, monkeypatch):
    from app.chess import lichess

    from .test_chess import DAILY

    monkeypatch.setattr(lichess, "_get", lambda path: DAILY)
    auth = signed_up(client)
    other = signed_up(client, "other@example.com")
    assert client.get("/me/today", headers=auth).json() == {"daily_solved": [], "sudoku_in_progress": []}

    done = {"solved": True, "mistakes": 0, "hints": 0, "duration_ms": 1000}
    # A practice Sudoku doesn't count as the daily; an unfinished one is listed.
    practice = client.get("/sudoku/puzzles/next", headers=auth).json()
    client.post(f"/sudoku/puzzles/{practice['id']}/attempts", json=done, headers=auth)
    daily = client.get("/sudoku/puzzles/daily", headers=auth).json()
    save = {"cells": daily["solution"][:30] + daily["puzzle"][30:], "notes": [0] * 81,
            "elapsed_ms": 61000, "mistakes": 0, "hints": 0}
    client.put(f"/sudoku/puzzles/{daily['id']}/save", json=save, headers=auth)
    status = client.get("/me/today", headers=auth).json()
    assert status["daily_solved"] == []
    assert [s["puzzle_id"] for s in status["sudoku_in_progress"]] == [daily["id"]]
    assert status["sudoku_in_progress"][0]["daily"] is True

    # Solving both dailies.
    client.post(f"/sudoku/puzzles/{daily['id']}/attempts", json=done, headers=auth)
    chess_id = client.get("/chess/puzzles/daily").json()["id"]
    client.post(f"/chess/puzzles/{chess_id}/attempts", json=done, headers=auth)
    assert client.get("/me/today", headers=auth).json() == {
        "daily_solved": ["chess-puzzles", "sudoku"],
        "sudoku_in_progress": [],
    }
    assert client.get("/me/today", headers=other).json()["daily_solved"] == []


def test_chess_elo_estimate():
    assert service.chess_elo([]) is None
    # Beating a puzzle at your own rating is worth half of K.
    assert service.chess_elo([(1500, True)]) == 1520
    assert service.chess_elo([(1500, False)]) == 1480
    # Clean solves of hard puzzles lift it; needing hints on easy ones sinks it.
    assert service.chess_elo([(1900, True)] * 15) > 1800
    assert service.chess_elo([(1100, False)] * 15) < 1200
    # It settles near the level where about half are solved cleanly.
    mixed = [(1700, i % 2 == 0) for i in range(60)]
    assert 1650 < service.chess_elo(mixed) < 1750


def test_puzzle_stats_leave_out_the_dailies(client, monkeypatch):
    from app.chess import lichess

    from .test_chess import DAILY, NEXT

    monkeypatch.setattr(lichess, "_get", lambda path: DAILY if path.endswith("daily") else NEXT)
    auth = signed_up(client)
    empty = {
        "quick_math": {"games": 0, "best": None, "accuracy": None},
        "chess": {"elo": None, "solved": 0},
        "sudoku": {"easy": 0, "medium": 0, "hard": 0},
    }
    assert client.get("/me/performance", headers=auth).json()["puzzles"] == empty

    done = {"solved": True, "mistakes": 0, "hints": 0, "duration_ms": 1000}
    daily_chess = client.get("/chess/puzzles/daily").json()["id"]
    client.post(f"/chess/puzzles/{daily_chess}/attempts", json=done, headers=auth)
    daily_sudoku = client.get("/sudoku/puzzles/daily").json()["id"]
    client.post(f"/sudoku/puzzles/{daily_sudoku}/attempts", json=done, headers=auth)
    assert client.get("/me/performance", headers=auth).json()["puzzles"] == empty

    practice = client.get("/chess/puzzles/next").json()  # rated 1331
    client.post(f"/chess/puzzles/{practice['id']}/attempts", json=done, headers=auth)
    for difficulty, count in (("easy", 2), ("hard", 1)):
        for _ in range(count):
            p = client.get("/sudoku/puzzles/next", params={"difficulty": difficulty}).json()
            client.post(f"/sudoku/puzzles/{p['id']}/attempts", json=done, headers=auth)
    stats = client.get("/me/performance", headers=auth).json()["puzzles"]
    assert stats["sudoku"] == {"easy": 2, "medium": 0, "hard": 1}
    assert stats["chess"] == {"elo": service.chess_elo([(1331, True)]), "solved": 1}
    assert 1500 < stats["chess"]["elo"] < 1520


def test_quick_math(client):
    auth = signed_up(client)
    url = "/games/quick-math/results"
    assert client.post(url, json={"correct": 5, "answered": 4}, headers=auth).status_code == 422
    assert client.post(url, json={"correct": 12, "answered": 15}).status_code == 401
    assert client.post(url, json={"correct": 12, "answered": 15}, headers=auth).json() == {"best": 12, "new_best": True}
    # As many runs a day as the player likes.
    assert client.post(url, json={"correct": 9, "answered": 9}, headers=auth).json() == {"best": 12, "new_best": False}
    assert client.post(url, json={"correct": 20, "answered": 26}, headers=auth).json() == {"best": 20, "new_best": True}

    stats = client.get("/me/performance", headers=auth).json()["puzzles"]["quick_math"]
    assert stats == {"games": 3, "best": 20, "accuracy": 82}  # 41 of 50
    assert client.get("/me/activity", headers=auth).json()["streak"] == 1
    # It never takes a session slot or feeds the KPI.
    assert client.get("/me/performance", headers=auth).json()["overall"] is None
    assert "quick-math" not in [g["game_id"] for g in client.get("/session/today", headers=auth).json()["games"]]


def test_apothecary(client):
    def trial(colours, moves, par=20, solved=True):
        return ApothecaryTrial(colours=colours, par=par, moves=moves, solved=solved, duration_ms=1)

    assert apothecary_score([trial(4, 20), trial(5, 20), trial(6, 20)]) == 1000
    assert apothecary_score([trial(4, 15)] * 3) == 800  # beating par earns no more than par
    assert apothecary_score([trial(4, 40)] * 3) == 400  # twice the pours, half the points
    assert apothecary_score([trial(4, 9, solved=False)] * 3) == 0

    auth = signed_up(client)
    assert client.get("/games/apothecary/level", headers=auth).json() == {"colours": 4}
    body = {
        "trials": [
            {"colours": 4, "par": 14, "moves": 14, "solved": True, "duration_ms": 60000},
            {"colours": 5, "par": 20, "moves": 30, "solved": True, "duration_ms": 90000},
            {"colours": 5, "par": 18, "moves": 22, "solved": True, "duration_ms": 80000},
        ]
    }
    url = "/games/apothecary/results"
    assert client.post(url, json={"trials": body["trials"][:2]}, headers=auth).status_code == 422
    score = client.post(url, json=body, headers=auth).json()["score"]
    assert score == round((800 + 1000 * 20 / 30 + 1000 * 18 / 22) / 3, 1)
    assert client.post(url, json=body, headers=auth).status_code == 409
    assert client.get("/me/performance", headers=auth).json()["domains"]["planning"]["level"] == score
    # The last puzzle was solved within a quarter of par: one more colour next time.
    assert client.get("/games/apothecary/level", headers=auth).json() == {"colours": 6}


def test_replays_can_be_switched_on_for_testing(client, monkeypatch):
    monkeypatch.setattr(config, "ALLOW_REPLAYS", True)
    auth = signed_up(client)
    url = "/games/points-of-thought/results"

    def play(correct):
        body = {"rounds": [{"level": 2, "points": 10, "correct": correct, "duration_ms": 50000}]}
        return client.post(url, json=body, headers=auth)

    assert play(10).json() == {"score": 700}
    assert play(6).json() == {"score": 420}  # no 409: played again the same day
    session = client.get("/session/today", headers=auth).json()
    assert session["replays_allowed"] is True and session["played_today"] == ["points-of-thought"]
    # The day counts once, as the average of its plays.
    attention = client.get("/me/performance", headers=auth).json()["domains"]["attention"]
    assert attention["n"] == 1 and attention["level"] == 560


def test_memory_slot_alternates_between_its_two_games(client):
    auth = signed_up(client)
    # Memory Matrix was played yesterday and What's My Name? never: it goes next.
    add_history("memory", "memory-matrix", [900])
    assert client.get("/session/today", headers=auth).json()["games"][0]["game_id"] == "whats-my-name"
