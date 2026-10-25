"""Novel passages for Between the Lines, for the website.

Browsers can't fetch from Project Gutenberg directly (it sends no CORS
headers), so the website asks here and this fetches a slice of the book. The
phone apps fetch from Gutenberg themselves.
"""

import random

import httpx
from fastapi import APIRouter, Depends, HTTPException

from ..auth.router import current_user

router = APIRouter(tags=["passages"])

# The novels the app samples from (lib/games/between_lines/lines_category.dart).
# Only these, so this is not an open proxy.
GUTENBERG_BOOKS = {
    1342, 158, 161, 105, 84, 11, 1661, 2097, 2701, 98, 1400, 730, 345, 1260, 768, 174, 2554,
    1184, 1257, 76, 74, 120, 43, 36, 35, 219, 145, 514, 64317, 25344, 2600, 1399, 55, 829,
    521, 160,
}
SLICE = 24_000  # bytes, a few pages
_HEADERS = {
    "User-Agent": "Kognitiv/0.1 (brain-training app)",
    "Accept-Encoding": "identity",  # with gzip, Gutenberg ignores byte ranges
}


def _get(url: str, start: int, end: int) -> httpx.Response:
    try:
        r = httpx.get(url, headers={**_HEADERS, "Range": f"bytes={start}-{end}"}, timeout=10)
    except httpx.HTTPError:
        raise HTTPException(502, "Project Gutenberg can't be reached.") from None
    if r.status_code not in (200, 206):
        raise HTTPException(502, "Project Gutenberg can't be reached.")
    return r


@router.get("/passages/gutenberg/{book_id}")
def gutenberg_slice(book_id: int, user=Depends(current_user)):
    """A slice of text from a random point in the middle of the book."""
    if book_id not in GUTENBERG_BOOKS:
        raise HTTPException(404, "Not one of the app's books.")
    url = f"https://www.gutenberg.org/cache/epub/{book_id}/pg{book_id}.txt"
    probe = _get(url, 0, 0)
    try:
        total = int(probe.headers.get("content-range", "").split("/")[-1])
    except ValueError:
        raise HTTPException(502, "Project Gutenberg sent an unexpected reply.") from None
    # Skip the front matter and the licence at the end.
    start = int(total * (0.12 + random.random() * 0.72))
    text = _get(url, start, start + SLICE).content[: SLICE + 1]
    return {"text": text.decode("utf-8", errors="replace")}
