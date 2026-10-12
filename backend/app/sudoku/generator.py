"""Sudoku generator. Every puzzle has exactly one solution.

A puzzle is fully determined by (seed, difficulty), so nothing needs storing:
the puzzle id carries both.
"""

import random
from functools import lru_cache

# Clues left on the board. Fewer clues is harder.
CLUES = {"easy": 42, "medium": 34, "hard": 28}

_ROW = [i // 9 for i in range(81)]
_COL = [i % 9 for i in range(81)]
_BOX = [(i // 27) * 3 + (i % 9) // 3 for i in range(81)]
_ALL = 0b111111111


def _masks(grid: list[int]) -> tuple[list[int], list[int], list[int]]:
    rows, cols, boxes = [0] * 9, [0] * 9, [0] * 9
    for i, v in enumerate(grid):
        if v:
            bit = 1 << (v - 1)
            rows[_ROW[i]] |= bit
            cols[_COL[i]] |= bit
            boxes[_BOX[i]] |= bit
    return rows, cols, boxes


def _search(grid: list[int], limit: int, rng: random.Random | None) -> int:
    """Backtracking search, always branching on the most constrained cell.
    Counts solutions up to `limit`; leaves the first one found in `grid` when
    limit is 1."""
    rows, cols, boxes = _masks(grid)

    def step() -> int:
        best, best_free, best_count = -1, 0, 10
        for i in range(81):
            if grid[i]:
                continue
            free = _ALL & ~(rows[_ROW[i]] | cols[_COL[i]] | boxes[_BOX[i]])
            count = free.bit_count()
            if count < best_count:
                best, best_free, best_count = i, free, count
                if count <= 1:
                    break
        if best < 0:
            return 1
        if best_count == 0:
            return 0
        digits = [d for d in range(1, 10) if best_free >> (d - 1) & 1]
        if rng:
            rng.shuffle(digits)
        r, c, b = _ROW[best], _COL[best], _BOX[best]
        found = 0
        for d in digits:
            bit = 1 << (d - 1)
            grid[best] = d
            rows[r] |= bit
            cols[c] |= bit
            boxes[b] |= bit
            found += step()
            if found >= limit:
                if limit > 1:
                    grid[best] = 0
                return found
            grid[best] = 0
            rows[r] &= ~bit
            cols[c] &= ~bit
            boxes[b] &= ~bit
        return found

    return step()


def count_solutions(grid: list[int], limit: int = 2) -> int:
    return _search(grid[:], limit, None)


@lru_cache(maxsize=256)
def generate(seed: str, difficulty: str) -> tuple[str, str]:
    """Returns (puzzle, solution) as 81-character strings, row by row, with
    0 for an empty cell."""
    rng = random.Random(f"{seed}/{difficulty}")
    solution = [0] * 81
    _search(solution, 1, rng)

    puzzle = solution[:]
    clues = 81
    cells = list(range(81))
    rng.shuffle(cells)
    for i in cells:
        if clues <= CLUES[difficulty]:
            break
        kept, puzzle[i] = puzzle[i], 0
        if count_solutions(puzzle) == 1:
            clues -= 1
        else:
            puzzle[i] = kept
    return "".join(map(str, puzzle)), "".join(map(str, solution))
