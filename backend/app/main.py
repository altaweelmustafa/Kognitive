from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from . import db
from .auth.router import router as auth_router
from .brain.router import router as brain_router
from .chess.router import router as chess_router
from .library.router import router as library_router
from .names.router import router as names_router
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


@app.get("/health")
def health():
    return {"ok": True}
