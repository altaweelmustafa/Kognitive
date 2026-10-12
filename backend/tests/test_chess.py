import pytest
from fastapi.testclient import TestClient

from app import config, db
from app.chess import lichess, service

from .helpers import signed_up

# Real payloads from lichess.org/api/puzzle/daily and /next.
DAILY = {
    "game": {"pgn": "e4 e5 Nf3 d5 exd5 e4 Ng1 Nf6 d3 Bb4+ Bd2 Bc5 Nc3 exd3 Bxd3 Nxd5 Qe2+ Be6 Bc4 Nxc3 Bxc3 O-O"},
    "puzzle": {
        "id": "s2zVy",
        "rating": 2066,
        "solution": ["e2e5", "c5f2", "e1f2", "d8h4", "g2g3"],
        "themes": ["opening", "long", "advantage"],
        "fen": "rn1q1rk1/ppp2ppp/4b3/2b5/2B5/2B5/PPP1QPPP/R3K1NR w KQ - 1 1",
        "lastMove": "e8g8",
    },
}
NEXT = {
    "game": {"pgn": "e4 c5 c3 e6 d4 d5 exd5 exd5 Nf3 cxd4 Nxd4 Bc5 Be2 Nc6 Be3 Nf6"},
    "puzzle": {"id": "lmTZh", "rating": 1331, "solution": ["d4c6", "b7c6", "e3c5"], "themes": ["short"]},
}
# Back-rank mate in one, with a second mate that isn't the listed solution.
MATE = lichess.Puzzle(
    id="mate1", fen="6k1/5ppp/8/8/8/8/8/R3R1K1 w - - 0 1", last_move=None,
    solution=["a1a8"], rating=600, themes=["mateIn1"],
)


@pytest.fixture
def client(tmp_path, monkeypatch):
    monkeypatch.setattr(config, "DB_PATH", tmp_path / "test.db")
    monkeypatch.setattr(lichess, "_get", lambda path: DAILY if path.endswith("daily") else NEXT)
    from app.main import app

    with TestClient(app) as c:
        yield c


def test_parse_replays_pgn_to_start_position():
    p = lichess.parse(DAILY)
    assert p.fen.split()[:2] == DAILY["puzzle"]["fen"].split()[:2]
    assert p.last_move == "e8g8"
    assert lichess.parse(NEXT).last_move == "g8f6"


def test_daily_hides_solution_and_is_cached(client, monkeypatch):
    body = client.get("/chess/puzzles/daily").json()
    assert body["id"] == "s2zVy" and body["player_color"] == "white"
    assert "solution" not in body and "e2e5" in body["state"]["legal_moves"]
    assert body["state"]["total_steps"] == 3

    def offline(path):
        raise lichess.LichessError("offline")

    monkeypatch.setattr(lichess, "_get", offline)
    assert client.get("/chess/puzzles/daily").json()["id"] == "s2zVy"
    assert client.get("/chess/puzzles/next").status_code == 503


def test_full_solve(client):
    client.get("/chess/puzzles/daily")
    url = "/chess/puzzles/s2zVy/moves"

    wrong = client.post(url, json={"step": 0, "move": "e2e4"}).json()
    assert wrong["correct"] is False and wrong["state"]["step"] == 0

    assert client.post(url, json={"step": 0, "move": "e2e2"}).status_code == 422
    assert client.get("/chess/puzzles/s2zVy/hint").json() == {"from": "e2", "to": "e5"}

    r = client.post(url, json={"step": 0, "move": "e2e5"}).json()
    assert r["correct"] and r["after_move"]["last_move"] == "e2e5"
    assert r["state"]["last_move"] == "c5f2" and r["state"]["step"] == 1 and r["state"]["check"]

    r = client.post(url, json={"step": 1, "move": "e1f2"}).json()
    assert r["state"]["last_move"] == "d8h4" and not r["state"]["solved"]

    r = client.post(url, json={"step": 2, "move": "g2g3"}).json()
    assert r["correct"] and r["state"]["solved"] and r["state"]["legal_moves"] == []
    assert client.post(url, json={"step": 3, "move": "a2a3"}).status_code == 422

    attempt = {"solved": True, "mistakes": 1, "hints": 1, "duration_ms": 42000}
    assert client.post("/chess/puzzles/s2zVy/attempts", json=attempt).status_code == 401
    auth = signed_up(client)
    assert client.post("/chess/puzzles/s2zVy/attempts", json=attempt, headers=auth).status_code == 201
    with db.connect() as conn:
        assert conn.execute("SELECT mistakes FROM chess_attempts").fetchone()[0] == 1


def test_next_puzzle(client):
    body = client.get("/chess/puzzles/next").json()
    assert body["id"] == "lmTZh" and body["player_color"] == "white"
    r = client.post("/chess/puzzles/lmTZh/moves", json={"step": 0, "move": "d4c6"}).json()
    assert r["state"]["last_move"] == "b7c6"


def test_any_checkmate_is_accepted(client):
    service._save(MATE)
    r = client.post("/chess/puzzles/mate1/moves", json={"step": 0, "move": "e1e8"}).json()
    assert r["correct"] and r["state"]["solved"]


def test_unknown_puzzle(client):
    assert client.post("/chess/puzzles/nope/moves", json={"step": 0, "move": "e2e4"}).status_code == 404
