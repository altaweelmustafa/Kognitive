"""Library articles. Each one is a Markdown file in content/library/:

    ---
    title: Feed Your Brain
    category: foods            # foods | to-do | to-avoid | best-practices
    summary: One line shown on the card.
    order: 10                  # optional; lower comes first
    ---
    The article, in Markdown.

Files are read on every request, so a new file shows up without a restart.
"""

import re

from fastapi import APIRouter, HTTPException

from .. import config

router = APIRouter(prefix="/library/articles", tags=["library"])

CATEGORIES = ("foods", "to-do", "to-avoid", "best-practices")
WORDS_PER_MINUTE = 200
_SLUG = re.compile(r"^[a-z0-9][a-z0-9-]*$")


def _read(path) -> dict | None:
    text = path.read_text(encoding="utf-8")
    meta, body = {}, text
    if text.startswith("---"):
        head, sep, rest = text[3:].partition("\n---")
        if sep:
            body = rest.lstrip("\n")
            for line in head.splitlines():
                key, colon, value = line.partition(":")
                if colon:
                    meta[key.strip().lower()] = value.split(" #")[0].strip()
    if not _SLUG.match(path.stem):
        return None
    category = meta.get("category", "").lower()
    try:
        order = int(meta.get("order", ""))
    except ValueError:
        order = 1000
    return {
        "id": path.stem,
        "title": meta.get("title") or path.stem.replace("-", " ").title(),
        "category": category if category in CATEGORIES else "best-practices",
        "summary": meta.get("summary", ""),
        "minutes": max(1, round(len(body.split()) / WORDS_PER_MINUTE)),
        "order": order,
        "body": body,
    }


def _all() -> list[dict]:
    folder = config.CONTENT_DIR / "library"
    articles = [a for p in sorted(folder.glob("*.md")) if (a := _read(p))]
    return sorted(articles, key=lambda a: (a["order"], a["id"]))


@router.get("")
def articles():
    return {"articles": [{k: v for k, v in a.items() if k not in ("body", "order")} for a in _all()]}


@router.get("/{article_id}")
def article(article_id: str):
    for a in _all():
        if a["id"] == article_id:
            return {k: v for k, v in a.items() if k != "order"}
    raise HTTPException(404, "Unknown article")
