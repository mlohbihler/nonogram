"""Exhaustive line solver for coloured nonograms, independent of the Ruby solver.

Usage (from the project root):
    python3 line_solver/solve.py puzzles/paris.80x80.json [--drop-scan]

Each row/column is solved with a DP over every placement of its clues, keeping only the values
that some placement allows. This is repeated until nothing changes, then any remaining cells are
resolved by backtracking. Every line deduction is sound, so a contradiction during propagation
proves the clues are inconsistent. --drop-scan then lists lines whose removal makes the rest
consistent, which are the typo candidates.
"""
import json
import re
import sys
from functools import lru_cache

BLANK = " "


def parse(clue_string):
    return [(int(count), colour) for count, colour in re.findall(r"(\d+)(\w)", clue_string)]


def solve_line(clues, cells):
    """cells: list of sets of allowed values. Returns the narrowed sets, or None if impossible."""
    n, k = len(cells), len(clues)

    @lru_cache(maxsize=None)
    def place(i, j):
        # The state after placing clue j starting at i, or None if it doesn't fit.
        if j == k:
            return None
        count, colour = clues[j]
        if i + count > n or any(colour not in cells[x] for x in range(i, i + count)):
            return None
        nxt = i + count
        # Consecutive clues of the same colour need a blank between them.
        if j + 1 < k and clues[j + 1][1] == colour:
            if nxt >= n or BLANK not in cells[nxt]:
                return None
            nxt += 1
        return (nxt, j + 1)

    @lru_cache(maxsize=None)
    def feasible(i, j):
        if i == n:
            return j == k
        if BLANK in cells[i] and feasible(i + 1, j):
            return True
        p = place(i, j)
        return p is not None and feasible(*p)

    if not feasible(0, 0):
        return None

    # Walk every state reachable from the start that can still finish, recording the values used.
    possible = [set() for _ in range(n)]
    seen, stack = {(0, 0)}, [(0, 0)]
    while stack:
        i, j = stack.pop()
        if i == n:
            continue
        if BLANK in cells[i] and feasible(i + 1, j):
            possible[i].add(BLANK)
            if (i + 1, j) not in seen:
                seen.add((i + 1, j))
                stack.append((i + 1, j))
        p = place(i, j)
        if p is not None and feasible(*p):
            count, colour = clues[j]
            for x in range(i, i + count):
                possible[x].add(colour)
            if p[0] > i + count:
                possible[i + count].add(BLANK)
            if p not in seen:
                seen.add(p)
                stack.append(p)
    return [cells[x] & possible[x] for x in range(n)]


def propagate(grid, rows, cols, skip=None):
    """Narrows grid in place. Returns the first contradictory line as (kind, index), or None."""
    row_count, col_count = len(rows), len(cols)
    dirty = [("r", r) for r in range(row_count)] + [("c", c) for c in range(col_count)]
    queued = set(dirty)
    while dirty:
        kind, idx = dirty.pop()
        queued.discard((kind, idx))
        if (kind, idx) == skip:
            continue
        if kind == "r":
            line = [grid[idx][c] for c in range(col_count)]
        else:
            line = [grid[r][idx] for r in range(row_count)]
        new = solve_line(rows[idx] if kind == "r" else cols[idx], line)
        if new is None:
            return (kind, idx)
        for x, values in enumerate(new):
            if values != line[x]:
                r, c = (idx, x) if kind == "r" else (x, idx)
                grid[r][c] = values
                other = ("c", c) if kind == "r" else ("r", r)
                if other not in queued:
                    queued.add(other)
                    dirty.append(other)
    return None


def search(grid, rows, cols, limit=2, budget=None):
    """Returns up to `limit` solutions (grids of single values)."""
    if budget is None:
        budget = [20000]
    if propagate(grid, rows, cols) is not None:
        return []
    undecided = [
        (len(grid[r][c]), r, c)
        for r in range(len(rows))
        for c in range(len(cols))
        if len(grid[r][c]) > 1
    ]
    if not undecided:
        return [[[next(iter(values)) for values in row] for row in grid]]
    budget[0] -= 1
    if budget[0] < 0:
        raise RuntimeError("search budget exhausted")

    _, r, c = min(undecided)
    solutions = []
    for value in sorted(grid[r][c]):
        guess = [[set(values) for values in row] for row in grid]
        guess[r][c] = {value}
        solutions += search(guess, rows, cols, limit - len(solutions), budget)
        if len(solutions) >= limit:
            break
    return solutions


def line_name(kind, idx):
    return f"{'row' if kind == 'r' else 'col'} {idx + 1}"


def main():
    data = json.load(open(sys.argv[1]))
    cols = [parse(cs) for cs in data[0]]
    rows = [parse(cs) for cs in data[1]]
    values = set(data[2]) | {BLANK}
    print(f"{len(rows)} rows x {len(cols)} cols, colours {sorted(values - {BLANK})}")

    def fresh():
        return [[set(values) for _ in cols] for _ in rows]

    grid = fresh()
    bad = propagate(grid, rows, cols)
    if bad is not None:
        print(f"Line propagation: CONTRADICTION (first detected on {line_name(*bad)})")
        if "--drop-scan" in sys.argv:
            print("Lines whose removal makes the rest consistent (typo candidates):")
            for kind, clue_sets in (("r", rows), ("c", cols)):
                for idx, clues in enumerate(clue_sets):
                    if propagate(fresh(), rows, cols, skip=(kind, idx)) is None:
                        print(f"  {line_name(kind, idx)}: {','.join(f'{n}{c}' for n, c in clues)}")
        sys.exit(1)

    known = sum(len(v) == 1 for row in grid for v in row)
    print(f"Line propagation: consistent, {known}/{len(rows) * len(cols)} cells determined")
    solutions = search(grid, rows, cols)
    if not solutions:
        print("Search: NO solution exists")
        sys.exit(1)
    print("Search: unique solution" if len(solutions) == 1 else "Search: multiple solutions")
    for row in solutions[0]:
        print("".join("." if v == BLANK else v for v in row))


if __name__ == "__main__":
    sys.setrecursionlimit(10000)
    main()
