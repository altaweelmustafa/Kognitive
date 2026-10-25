from datetime import date

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field, model_validator

from ..auth.router import current_user
from ..chess import service as chess_service
from ..sudoku import router as sudoku_router
from . import service

router = APIRouter(tags=["brain"])

MEMORY_MATRIX_TRIALS = 8
MEMORY_MATRIX_CELLS = 25
TOWERS_PUZZLES = 5
POINTS_ROUNDS = 1
POINTS_START_LEVEL = 2
POINTS_PER_ROUND = 10
POINTS_MAX_LEVEL = 8
APOTHECARY_PUZZLES = 3
APOTHECARY_MIN_COLOURS = 3
APOTHECARY_MAX_COLOURS = 8
APOTHECARY_START_COLOURS = 4


class MatrixTrial(BaseModel):
    nodes: int = Field(ge=1, le=MEMORY_MATRIX_CELLS)  # how many flashed
    found: int = Field(ge=0)  # how many the player got before a miss
    duration_ms: int = Field(ge=0)

    @model_validator(mode="after")
    def _found_fits(self):
        if self.found > self.nodes:
            raise ValueError("found cannot exceed nodes")
        return self


class MatrixResult(BaseModel):
    trials: list[MatrixTrial] = Field(
        min_length=MEMORY_MATRIX_TRIALS, max_length=MEMORY_MATRIX_TRIALS
    )


class PointsRound(BaseModel):
    level: int = Field(ge=1, le=POINTS_MAX_LEVEL)
    points: int = Field(ge=POINTS_PER_ROUND, le=POINTS_PER_ROUND)
    correct: int = Field(ge=0, le=POINTS_PER_ROUND)  # points that reached their own target
    duration_ms: int = Field(ge=0)


class PointsResult(BaseModel):
    rounds: list[PointsRound] = Field(min_length=POINTS_ROUNDS, max_length=POINTS_ROUNDS)


def points_score(rounds: list[PointsRound]) -> float:
    """A round is worth 500 + 100 per level, times the share of points
    delivered: 700 for a clean round on level 2, up to 1300 on level 8."""
    total = sum((500 + 100 * r.level) * r.correct / r.points for r in rounds)
    return round(total / len(rounds), 1)


class TowersTrial(BaseModel):
    optimal: int = Field(ge=1, le=20)  # fewest moves that solve the puzzle
    moves: int = Field(ge=0, le=100)  # moves the player made
    solved: bool
    duration_ms: int = Field(ge=0)

    @model_validator(mode="after")
    def _possible(self):
        if self.solved and self.moves < self.optimal:
            raise ValueError("solved in fewer moves than the optimum")
        return self


class TowersResult(BaseModel):
    trials: list[TowersTrial] = Field(min_length=TOWERS_PUZZLES, max_length=TOWERS_PUZZLES)


def towers_score(trials: list[TowersTrial]) -> float:
    """Each solved puzzle is worth its difficulty (its optimal move count)
    times how efficiently it was solved (optimal / moves made). Averaged and
    scaled so that solving 3, 4, 5, 6 and 7-move puzzles perfectly scores 1000."""
    points = sum(t.optimal * t.optimal / t.moves for t in trials if t.solved)
    return round(200 * points / len(trials), 1)


def memory_matrix_score(trials: list[MatrixTrial]) -> float:
    """100 points per node recalled, averaged over the trials. Recalling
    8, 9, ... 15 nodes without a miss scores 1150."""
    return round(100 * sum(t.found for t in trials) / len(trials), 1)


def _record(user, game_id: str, score: float, detail: dict) -> dict:
    try:
        service.record(user["id"], game_id, score, detail)
    except service.AlreadyPlayed:
        raise HTTPException(409, "You've already played this today.") from None
    return {"score": score}


@router.post("/games/memory-matrix/results", status_code=201)
def memory_matrix_result(body: MatrixResult, user=Depends(current_user)):
    return _record(
        user,
        "memory-matrix",
        memory_matrix_score(body.trials),
        {
            "trials": [t.model_dump() for t in body.trials],
            "perfect_trials": sum(t.found == t.nodes for t in body.trials),
            "max_nodes": max((t.nodes for t in body.trials if t.found == t.nodes), default=0),
        },
    )


@router.get("/games/points-of-thought/level")
def points_level(user=Depends(current_user)):
    """The level to play next. A session is one round, so the difficulty
    carries over from the last session: 9 or 10 points delivered moves up a
    level, fewer than 7 moves down."""
    last = service.last_detail(user["id"], "points-of-thought")
    if last is None:
        return {"level": POINTS_START_LEVEL}
    final = last["rounds"][-1]
    level = final["level"]
    if final["correct"] >= 9:
        level += 1
    elif final["correct"] < 7:
        level -= 1
    return {"level": max(1, min(POINTS_MAX_LEVEL, level))}


@router.post("/games/points-of-thought/results", status_code=201)
def points_result(body: PointsResult, user=Depends(current_user)):
    return _record(
        user,
        "points-of-thought",
        points_score(body.rounds),
        {
            "rounds": [r.model_dump() for r in body.rounds],
            "delivered": sum(r.correct for r in body.rounds),
            "top_level": max(r.level for r in body.rounds),
        },
    )


@router.post("/games/towers-of-stockholm/results", status_code=201)
def towers_result(body: TowersResult, user=Depends(current_user)):
    return _record(
        user,
        "towers-of-stockholm",
        towers_score(body.trials),
        {
            "trials": [t.model_dump() for t in body.trials],
            "perfect_puzzles": sum(t.solved and t.moves == t.optimal for t in body.trials),
            "hardest_solved": max((t.optimal for t in body.trials if t.solved), default=0),
        },
    )


class ApothecaryTrial(BaseModel):
    colours: int = Field(ge=APOTHECARY_MIN_COLOURS, le=APOTHECARY_MAX_COLOURS)
    par: int = Field(ge=1, le=300)  # pours in the reference solution
    moves: int = Field(ge=0, le=2000)  # pours the player made
    solved: bool
    duration_ms: int = Field(ge=0)


class ApothecaryResult(BaseModel):
    trials: list[ApothecaryTrial] = Field(
        min_length=APOTHECARY_PUZZLES, max_length=APOTHECARY_PUZZLES
    )


def apothecary_score(trials: list[ApothecaryTrial]) -> float:
    """Each solved puzzle is worth 200 per colour, times how close the player
    came to the reference solution (par / pours, at most 1). Averaged over the
    puzzles: clean solves of 4, 5 and 6 colours score 1000."""
    points = sum(
        200 * t.colours * min(1.0, t.par / t.moves) for t in trials if t.solved and t.moves > 0
    )
    return round(points / len(trials), 1)


def apothecary_next(trial: dict) -> int:
    """Colours for the puzzle after this one: one more after a clean solve
    (within a quarter of par), one fewer after giving up, else the same."""
    colours = trial["colours"]
    if not trial["solved"]:
        colours -= 1
    elif trial["moves"] <= trial["par"] * 1.25:
        colours += 1
    return max(APOTHECARY_MIN_COLOURS, min(APOTHECARY_MAX_COLOURS, colours))


@router.get("/games/apothecary/level")
def apothecary_level(user=Depends(current_user)):
    """How many colours the next session starts with. It carries over: the
    session picks up where the last one left off."""
    last = service.last_detail(user["id"], "apothecary")
    if last is None:
        return {"colours": APOTHECARY_START_COLOURS}
    return {"colours": apothecary_next(last["trials"][-1])}


@router.post("/games/apothecary/results", status_code=201)
def apothecary_result(body: ApothecaryResult, user=Depends(current_user)):
    return _record(
        user,
        "apothecary",
        apothecary_score(body.trials),
        {
            "trials": [t.model_dump() for t in body.trials],
            "solved": sum(t.solved for t in body.trials),
            "most_colours": max((t.colours for t in body.trials if t.solved), default=0),
        },
    )


class QuickMathResult(BaseModel):
    correct: int = Field(ge=0, le=300)
    answered: int = Field(ge=0, le=300)

    @model_validator(mode="after")
    def _fits(self):
        if self.correct > self.answered:
            raise ValueError("correct cannot exceed answered")
        return self


@router.post("/games/quick-math/results", status_code=201)
def quick_math_result(body: QuickMathResult, user=Depends(current_user)):
    """Quick Math is outside the session: any number of runs a day."""
    return service.record_quick_math(user["id"], body.correct, body.answered)


QUIVER_SECONDS = 45
QUIVER_MAX_POINTS = 125  # base 25 at the top multiplier, ×5
QUIVER_STRONG_RUN = 36  # right answers in 45 seconds that make a 1000
LINES_QUESTIONS = 10
LINES_BONUS = 50  # most speed bonus one answer can earn
LINES_CATEGORIES = ("cybersecurity", "networking", "programming", "medicine", "novels")


class QuiverResult(BaseModel):
    score: int = Field(ge=0)  # the points shown in the game
    correct: int = Field(ge=0, le=QUIVER_SECONDS * 6)  # no one swipes faster than 6 a second
    answered: int = Field(ge=0, le=QUIVER_SECONDS * 6)

    @model_validator(mode="after")
    def _fits(self):
        if self.correct > self.answered:
            raise ValueError("correct cannot exceed answered")
        if self.score > self.correct * QUIVER_MAX_POINTS:
            raise ValueError("score is more than the answers could earn")
        return self


def quiver_score(correct: int, answered: int) -> float:
    """Speed times accuracy: 1000 for 36 right answers in the 45 seconds
    with none wrong. Guessing doesn't pay, since accuracy scales it down."""
    if answered == 0:
        return 0.0
    return round(1000 * correct / QUIVER_STRONG_RUN * correct / answered, 1)


@router.post("/games/quiver/results", status_code=201)
def quiver_result(body: QuiverResult, user=Depends(current_user)):
    return _record(
        user,
        "quiver",
        quiver_score(body.correct, body.answered),
        body.model_dump(),
    )


class LinesResult(BaseModel):
    category: str
    score: int = Field(ge=0)  # the points shown in the game, bonuses included
    correct: int = Field(ge=0, le=LINES_QUESTIONS)
    answered: int = Field(ge=1, le=LINES_QUESTIONS)

    @model_validator(mode="after")
    def _fits(self):
        if self.category not in LINES_CATEGORIES:
            raise ValueError("unknown category")
        if self.correct > self.answered:
            raise ValueError("correct cannot exceed answered")
        if not 100 * self.correct <= self.score <= (100 + LINES_BONUS) * self.correct:
            raise ValueError("score doesn't match the right answers")
        return self


def lines_score(correct: int, answered: int, score: int) -> float:
    """1000 for every gap filled right, plus up to 200 for speed: the share
    of the speed bonus earned. A short round (offline) counts the same."""
    bonus = score - 100 * correct
    return round(1000 * correct / answered + 200 * bonus / (LINES_BONUS * answered), 1)


@router.post("/games/between-the-lines/results", status_code=201)
def lines_result(body: LinesResult, user=Depends(current_user)):
    return _record(
        user,
        "between-the-lines",
        lines_score(body.correct, body.answered, body.score),
        body.model_dump(),
    )


@router.get("/me/performance")
def performance(user=Depends(current_user)):
    return service.performance(user["id"])


@router.get("/me/day/{day}")
def day_summary(day: date, user=Depends(current_user)):
    """What the player did on one day, for a tap on the calendar."""
    return service.day_summary(user["id"], day)


@router.get("/me/today")
def today_status(user=Depends(current_user)):
    """What the Home screen shows about the games outside the session:
    which daily puzzles are solved, and Sudoku games left unfinished."""
    solved = []
    if chess_service.daily_solved(user["id"]):
        solved.append("chess-puzzles")
    if sudoku_router.daily_solved(user["id"]):
        solved.append("sudoku")
    return {"daily_solved": solved, "sudoku_in_progress": sudoku_router.list_saves(user["id"])}


@router.get("/session/today")
def session_today(user=Depends(current_user)):
    return service.session(user["id"])


@router.get("/session/tomorrow")
def session_tomorrow(user=Depends(current_user)):
    return {"games": service.tomorrow_preview(user["id"])}
