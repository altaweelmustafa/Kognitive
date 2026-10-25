from contextlib import asynccontextmanager
from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from . import config, db
from .auth.router import router as auth_router
from .brain.router import router as brain_router
from .chess.router import router as chess_router
from .library.router import router as library_router
from .names.router import router as names_router
from .passages.router import router as passages_router
from .sudoku.router import router as sudoku_router


@asynccontextmanager
async def lifespan(_: FastAPI):
    db.init()
    yield


app = FastAPI(title="Kognitiv API", lifespan=lifespan)
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])
app.include_router(auth_router)
app.include_router(brain_router)
app.include_router(chess_router)
app.include_router(library_router)
app.include_router(names_router)
app.include_router(sudoku_router)
app.include_router(passages_router)


@app.get("/health")
def health():
    return {"ok": True}


class _Website(StaticFiles):
    """The Flutter web build. Until it has been deployed the folder doesn't
    exist, and every page is simply not found (not a server error)."""

    async def check_config(self) -> None:
        if Path(self.directory).is_dir():
            await super().check_config()


# The website, served at /. Mounted last, so the API routes above win.
# scripts/deploy_web.sh puts the build in place; no restart needed.
app.mount("/", _Website(directory=config.WEB_DIR, html=True, check_dir=False), name="web")
