from datetime import timedelta

import pytest
from fastapi.testclient import TestClient

from app import config, db
from app.names import matching, router as names, srs
from app.names.people import BY_ID, PEOPLE

from .helpers import signed_up

URL = "/games/whats-my-name"


def test_thirty_people_all_different():
    assert len(PEOPLE) == 30
    assert len({p.name for p in PEOPLE}) == 30 and len({p.id for p in PEOPLE}) == 30
    for p in PEOPLE:
        # Each person's own details must be accepted as answers.
        assert matching.judge(p, "name", p.name) == (True, False)
        assert matching.judge(p, "profession", p.profession) == (True, False)
        assert matching.judge(p, "detail", p.detail) == (True, False), p.detail


def test_typed_answers_are_judged_kindly_but_not_blindly():
    omar, leila, victor = BY_ID["008"], BY_ID["064"], BY_ID["172"]
    judge = matching.judge
    assert judge(omar, "name", "  OMAR. ") == (True, False)
    assert judge(leila, "name", "Leyla") == (True, True)  # one letter off
    assert judge(omar, "name", "Oman") == (True, True)
    assert judge(omar, "name", "Karim") == (False, False)
    assert judge(BY_ID["045"], "name", "Lea") == (False, False)  # short names must be exact
    assert judge(omar, "name", "") == (False, False)

    assert judge(omar, "profession", "He is an architect") == (True, False)
    assert judge(omar, "profession", "arcitect") == (True, True)
    assert judge(leila, "profession", "physician") == (True, False)  # another word for it
    assert judge(victor, "profession", "drives a bus") == (True, True)  # near enough to "bus driver"
    assert judge(victor, "profession", "taxi") == (False, False)
    assert judge(victor, "profession", "bus driver") == (True, False)
    assert judge(leila, "profession", "nurse") == (False, False)

    assert judge(omar, "detail", "something about vinyl") == (True, False)
    assert judge(omar, "detail", "he collects recrods") == (True, True)
    assert judge(leila, "detail", "she paints") == (True, False)
    assert judge(leila, "detail", "plays chess") == (False, False)
    assert judge(omar, "detail", "he likes the") == (False, False)  # nothing but filler


def test_sm2_schedule():
    card = srs.Card()
    intervals = []
    for _ in range(5):
        card = srs.review(card, srs.EXACT)
        intervals.append(card.interval)
    assert intervals == [1, 6, 16, 45, 131]  # each longer than the last
    assert card.ease > srs.START_EASE

    lapsed = srs.review(card, srs.WRONG)
    assert (lapsed.repetitions, lapsed.interval) == (0, 1)  # back tomorrow
    assert lapsed.ease < card.ease
    # A typo still counts, but doesn't raise the ease.
    assert srs.review(srs.Card(), srs.TYPO).ease == srs.START_EASE
    assert srs.review(srs.Card(ease=1.3), srs.WRONG).ease == srs.MIN_EASE


@pytest.fixture
def client(tmp_path, monkeypatch):
    monkeypatch.setattr(config, "DB_PATH", tmp_path / "test.db")
    monkeypatch.setattr(config, "ALLOW_REPLAYS", False)
    from app.main import app

    with TestClient(app) as c:
        yield c


class Clock:
    """Moves the game's idea of today."""

    def __init__(self, monkeypatch):
        self.day = names._today()
        monkeypatch.setattr(names, "_today", lambda: self.day)

    def advance(self, days=1):
        self.day += timedelta(days=days)


def say(client, auth, person_id, question, text):
    r = client.post(f"{URL}/answer", json={"id": person_id, "question": question, "answer": text}, headers=auth)
    assert r.status_code == 200, r.text
    return r.json()


def test_a_week_of_sessions(client, monkeypatch):
    clock = Clock(monkeypatch)
    auth = signed_up(client)
    assert client.get(f"{URL}/session").status_code == 401

    # Day 1: five new people, nothing to review.
    s = client.get(f"{URL}/session", headers=auth).json()
    first_five = [p["id"] for p in s["new"]]
    assert first_five == [p.id for p in PEOPLE[:5]] and s["reviews"] == []
    assert s["new"][0] == {"id": "008", "name": "Omar", "profession": "architect", "detail": "collects vinyl records"}
    assert s["pool"] == {"people": 5, "due_tomorrow": 5, "still_to_meet": 25}
    assert client.get(f"{URL}/session", headers=auth).json()["new"] == s["new"]  # fixed for the day

    # Everything right about four of them; the fifth's name forgotten.
    for pid in first_five[:4]:
        p = BY_ID[pid]
        assert say(client, auth, pid, "name", p.name)["correct"]
        assert say(client, auth, pid, "profession", p.profession)["correct"]
        assert say(client, auth, pid, "detail", p.detail)["correct"]
    forgotten = BY_ID[first_five[4]]
    wrong = say(client, auth, forgotten.id, "name", "no idea")
    assert wrong == {"correct": False, "close": False, "expected": forgotten.name}
    say(client, auth, forgotten.id, "profession", forgotten.profession)
    say(client, auth, forgotten.id, "detail", forgotten.detail)

    # Only the first try counts, and only today's questions can be answered.
    again = {"id": forgotten.id, "question": "name", "answer": forgotten.name}
    assert client.post(f"{URL}/answer", json=again, headers=auth).status_code == 409
    stranger = {"id": PEOPLE[20].id, "question": "name", "answer": "x"}
    assert client.post(f"{URL}/answer", json=stranger, headers=auth).status_code == 404

    done = client.post(f"{URL}/finish", headers=auth).json()
    assert (done["correct"], done["asked"], done["score"]) == (14, 15, 933.3)
    assert client.get("/me/performance", headers=auth).json()["domains"]["memory"]["level"] == 933.3
    s = client.get(f"{URL}/session", headers=auth).json()
    assert s["finished"] and s["score"] == 933.3 and len(s["answered"]) == 15

    # Day 2: five more people, and yesterday's five come back, one question each.
    clock.advance()
    s = client.get(f"{URL}/session", headers=auth).json()
    assert [p["id"] for p in s["new"]] == [p.id for p in PEOPLE[5:10]]
    assert sorted(r["id"] for r in s["reviews"]) == sorted(first_five)
    assert not s["finished"] and s["answered"] == []
    for r in s["reviews"]:
        # The answers to reviews are not sent to the app.
        assert set(r) == {"id", "question"}
        person = BY_ID[r["id"]]
        text = "blank" if person is forgotten else matching.expected(person, r["question"])
        say(client, auth, r["id"], r["question"], text)
    client.post(f"{URL}/finish", headers=auth)

    with db.connect() as conn:
        cards = {r["face_id"]: r for r in conn.execute("SELECT * FROM names_cards")}
    # Remembered twice running: six days until the next look.
    assert cards[first_five[0]]["interval"] == 6
    # Missed again: back tomorrow, and counted as a lapse.
    assert cards[forgotten.id]["interval"] == 1 and cards[forgotten.id]["lapses"] == 1

    # Day 3: today's new five, yesterday's new five (never tested, still due),
    # and the one that was missed. The four known ones are not due.
    clock.advance()
    s = client.get(f"{URL}/session", headers=auth).json()
    due = sorted(r["id"] for r in s["reviews"])
    assert due == sorted([forgotten.id, *[p.id for p in PEOPLE[5:10]]])

    # Day 8: the four known ones are back.
    clock.advance(5)
    due = {r["id"] for r in client.get(f"{URL}/session", headers=auth).json()["reviews"]}
    assert set(first_five[:4]) <= due


def test_runs_out_of_new_people_and_caps_reviews(client, monkeypatch):
    clock = Clock(monkeypatch)
    auth = signed_up(client)
    for _ in range(6):  # thirty people, five a day
        assert len(client.get(f"{URL}/session", headers=auth).json()["new"]) == 5
        clock.advance()
    s = client.get(f"{URL}/session", headers=auth).json()
    assert s["new"] == [] and s["pool"]["still_to_meet"] == 0
    assert len(s["reviews"]) == names.MAX_REVIEWS  # thirty are due; twenty are asked


def test_reset_is_only_for_testing(client, monkeypatch):
    auth = signed_up(client)
    client.get(f"{URL}/session", headers=auth)
    assert client.post(f"{URL}/reset", headers=auth).status_code == 403
    assert client.post(f"{URL}/finish", headers=auth).status_code == 400  # nothing answered

    monkeypatch.setattr(config, "ALLOW_REPLAYS", True)
    assert client.get(f"{URL}/session", headers=auth).json()["can_reset"] is True
    assert client.post(f"{URL}/reset", headers=auth).status_code == 200
    s = client.get(f"{URL}/session", headers=auth).json()
    assert s["pool"]["people"] == 5 and s["answered"] == []  # a fresh day one
