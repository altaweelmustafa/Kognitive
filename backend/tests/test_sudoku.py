import time

import pytest
from fastapi.testclient import TestClient

from app import config, db
from app.sudoku import generator

from .helpers import signed_up


def check_solution(solution: str):
    rows = [solution[r * 9 : r * 9 + 9] for r in range(9)]
    cols = ["".join(row[c] for row in rows) for c in range(9)]
    boxes = [
        "".join(rows[r + dr][c + dc] for dr in range(3) for dc in range(3))
        for r in (0, 3, 6)
        for c in (0, 3, 6)
    ]
    for unit in rows + cols + boxes:
        assert sorted(unit) == list("123456789")


@pytest.mark.parametrize("difficulty", ["easy", "medium", "hard"])
def test_generated_puzzles_are_valid_and_unique(difficulty):
    for seed in range(5):
        puzzle, solution = generator.generate(f"t{seed}", difficulty)
        check_solution(solution)
        assert all(p in ("0", s) for p, s in zip(puzzle, solution))
        assert generator.count_solutions([int(ch) for ch in puzzle]) == 1
        clues = 81 - puzzle.count("0")
        assert generator.CLUES[difficulty] <= clues <= generator.CLUES[difficulty] + 3


def test_harder_means_fewer_clues_and_same_seed_same_puzzle():
    easy, _ = generator.generate("x", "easy")
    hard, _ = generator.generate("x", "hard")
    assert easy.count("0") < hard.count("0")
    generator.generate.cache_clear()
    assert generator.generate("x", "easy")[0] == easy


def test_generation_is_fast():
    generator.generate.cache_clear()
    start = time.perf_counter()
    for seed in range(5):
        generator.generate(f"speed{seed}", "hard")
    assert (time.perf_counter() - start) / 5 < 1.0


@pytest.fixture
def client(tmp_path, monkeypatch):
    monkeypatch.setattr(config, "DB_PATH", tmp_path / "test.db")
    from app.main import app

    with TestClient(app) as c:
        yield c


def test_endpoints(client):
    daily = client.get("/sudoku/puzzles/daily").json()
    assert daily["id"].startswith("daily-") and daily["difficulty"] == "medium"
    assert client.get("/sudoku/puzzles/daily").json() == daily
    check_solution(daily["solution"])

    hard = client.get("/sudoku/puzzles/next", params={"difficulty": "hard"}).json()
    assert hard["id"].startswith("hard-") and hard["puzzle"] != daily["puzzle"]
    assert client.get("/sudoku/puzzles/next", params={"difficulty": "nope"}).status_code == 422

    body = {"solved": True, "mistakes": 2, "hints": 0, "duration_ms": 300000}
    auth = signed_up(client)
    assert client.post(f"/sudoku/puzzles/{hard['id']}/attempts", json=body).status_code == 401
    assert client.post(f"/sudoku/puzzles/{hard['id']}/attempts", json=body, headers=auth).status_code == 201
    assert client.post("/sudoku/puzzles/bogus/attempts", json=body, headers=auth).status_code == 404
    with db.connect() as conn:
        row = conn.execute("SELECT difficulty, mistakes FROM sudoku_attempts").fetchone()
    assert tuple(row) == ("hard", 2)


def test_save_and_resume(client):
    auth = signed_up(client)
    other = signed_up(client, "other@example.com")
    p = client.get("/sudoku/puzzles/next", params={"difficulty": "easy"}, headers=auth).json()
    assert p["save"] is None

    cells = p["solution"][:40] + p["puzzle"][40:]
    notes = [0] * 80 + [0b101]
    body = {"cells": cells, "notes": notes, "elapsed_ms": 95000, "mistakes": 2, "hints": 1}
    url = f"/sudoku/puzzles/{p['id']}"
    assert client.put(f"{url}/save", json=body).status_code == 401
    assert client.put(f"{url}/save", json=body, headers=auth).status_code == 200
    body["elapsed_ms"] = 120000
    assert client.put(f"{url}/save", json=body, headers=auth).status_code == 200  # overwrites
    assert client.put(f"{url}/save", json={**body, "cells": "12"}, headers=auth).status_code == 422

    listed = client.get("/sudoku/puzzles/saves", headers=auth).json()["saves"]
    assert len(listed) == 1 and listed[0]["puzzle_id"] == p["id"]
    assert listed[0]["elapsed_ms"] == 120000 and listed[0]["difficulty"] == "easy"
    assert client.get("/sudoku/puzzles/saves", headers=other).json()["saves"] == []

    again = client.get(url, headers=auth).json()
    assert again["puzzle"] == p["puzzle"] and again["save"] == body
    assert client.get(url, headers=other).json()["save"] is None

    done = {"solved": True, "mistakes": 2, "hints": 1, "duration_ms": 200000}
    assert client.post(f"{url}/attempts", json=done, headers=auth).status_code == 201
    assert client.get("/sudoku/puzzles/saves", headers=auth).json()["saves"] == []
