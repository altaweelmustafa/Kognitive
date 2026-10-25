import httpx
import pytest
from fastapi.testclient import TestClient

from app import config
from app.passages import router as passages

from .helpers import signed_up


@pytest.fixture
def client(tmp_path, monkeypatch):
    monkeypatch.setattr(config, "DB_PATH", tmp_path / "test.db")
    from app.main import app

    with TestClient(app) as c:
        yield c


class FakeGutenberg:
    """Answers byte-range requests for a 100 kB book of the letter a."""

    def __init__(self):
        self.ranges = []

    def get(self, url, headers, timeout):
        start, end = map(int, headers["Range"].removeprefix("bytes=").split("-"))
        self.ranges.append((start, end))
        return httpx.Response(
            206,
            headers={"content-range": f"bytes {start}-{end}/100000"},
            content=b"a" * (end - start + 1),
        )


def test_gutenberg_slice(client, monkeypatch):
    fake = FakeGutenberg()
    monkeypatch.setattr(passages.httpx, "get", fake.get)
    auth = signed_up(client)
    url = "/passages/gutenberg/1342"

    assert client.get(url).status_code == 401
    # Only the app's own books: this is not an open proxy.
    assert client.get("/passages/gutenberg/999999", headers=auth).status_code == 404

    text = client.get(url, headers=auth).json()["text"]
    assert len(text) == passages.SLICE + 1
    probe, (start, end) = fake.ranges
    assert probe == (0, 0)
    # From the middle of the book: past the front matter, before the licence.
    assert 12_000 <= start <= 84_000 and end == start + passages.SLICE


def test_gutenberg_unreachable(client, monkeypatch):
    def down(*_, **__):
        raise httpx.ConnectError("down")

    monkeypatch.setattr(passages.httpx, "get", down)
    auth = signed_up(client)
    assert client.get("/passages/gutenberg/1342", headers=auth).status_code == 502


def test_website_is_served_beside_the_api(client, tmp_path):
    from app.main import app

    site = tmp_path / "web"
    mount = next(r for r in app.routes if getattr(r, "name", None) == "web")
    mount.app.directory = str(site)
    mount.app.all_directories = [str(site)]
    mount.app.config_checked = False

    # Not deployed yet: not found, not a crash.
    assert client.get("/").status_code == 404

    site.mkdir()
    (site / "index.html").write_text("<title>Kognitiv</title>")
    mount.app.config_checked = False

    assert "Kognitiv" in client.get("/").text
    # The API still wins over the website.
    assert client.get("/health").json() == {"ok": True}
