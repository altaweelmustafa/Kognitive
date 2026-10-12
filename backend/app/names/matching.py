"""Judging a typed answer. Forgiving of case, punctuation and small typos."""

import re
import unicodedata

from .people import Person

QUESTIONS = ("name", "profession", "detail")

# Words that carry no information in an answer.
_FILLER = {
    "a", "an", "the", "is", "are", "was", "he", "she", "they", "them", "his", "her", "their",
    "works", "work", "as", "to", "and", "of", "in", "at", "with", "i", "think", "it", "its",
    "likes", "like", "loves", "love", "really", "very", "who", "that", "does", "do", "s",
}


def _words(text: str) -> list[str]:
    plain = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode().lower()
    return [w for w in re.split(r"[^a-z0-9]+", plain) if w]


def _distance(a: str, b: str) -> int:
    """Edit distance where a wrong, missing or extra letter costs one, and so
    does swapping two neighbouring letters (the commonest typing slip)."""
    rows = [list(range(len(b) + 1))]
    for i, ca in enumerate(a, 1):
        row = [i]
        for j, cb in enumerate(b, 1):
            best = min(rows[-1][j] + 1, row[-1] + 1, rows[-1][j - 1] + (ca != cb))
            if i > 1 and j > 1 and ca == b[j - 2] and a[i - 2] == cb:
                best = min(best, rows[-2][j - 2] + 1)
            row.append(best)
        rows.append(row)
    return rows[-1][-1]


def _typo(given: str, wanted: str) -> bool:
    """A slip of the finger: one wrong letter in a medium word, two in a long
    one. Short words must be exact."""
    allowed = 0 if len(wanted) <= 3 else 1 if len(wanted) <= 7 else 2
    return 0 < _distance(given, wanted) <= allowed


def _phrase(given: list[str], wanted: list[str]) -> str | None:
    """'exact' if every wanted word is in the answer, 'close' if they all are
    allowing typos, else None."""
    if all(w in given for w in wanted):
        return "exact"
    if all(w in given or any(_typo(g, w) for g in given) for w in wanted):
        return "close"
    return None


def judge(person: Person, question: str, answer: str) -> tuple[bool, bool]:
    """Returns (correct, close). `close` means it was accepted despite a typo."""
    given = [w for w in _words(answer) if w not in _FILLER]
    if not given:
        return False, False
    if question == "name":
        accepted = [_words(person.name)]
    elif question == "profession":
        accepted = [_words(p) for p in (person.profession, *person.profession_also)]
    else:
        # Any one of the telling words is enough.
        accepted = [_words(key) for key in person.detail_keys]

    results = [_phrase(given, wanted) for wanted in accepted]
    if "exact" in results:
        return True, False
    if "close" in results:
        return True, True
    return False, False


def expected(person: Person, question: str) -> str:
    return {"name": person.name, "profession": person.profession, "detail": person.detail}[question]
