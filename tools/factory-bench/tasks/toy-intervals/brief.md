# Slice brief: integer interval set

There is no bead for this slice: skip every `bd` step. Load no skills.

## Place

- Worktree: `{WORKTREE}` (a git checkout on branch `main`; work on that branch).
- Scratch: `{SCRATCH}` (create it if you need it; delete what you put there).
- Commit with plain `git commit`. The configured identity applies; never override it.
- Files you own: `intervals/__init__.py`, `tests/` (new test modules), `README.md`.
  Blast radius: the whole of those files. Non-goals: non-integer bounds, unbounded
  spans, performance work, any file outside the list.

## What to build

`intervals/__init__.py` exports exactly this surface. Other slices code against it,
so names, parameters and return types are fixed.

```python
class IntervalSet:
    def __init__(self, spans=()): ...    # iterable of (lo, hi) pairs, added in order
    def add(self, lo, hi) -> None: ...
    def remove(self, lo, hi) -> None: ...
    def spans(self) -> list[tuple[int, int]]: ...
    def __contains__(self, x) -> bool: ...
    def total(self) -> int: ...           # how many integers the set holds
    def gaps(self, lo, hi) -> list[tuple[int, int]]: ...
    def __eq__(self, other) -> bool: ...
```

## Terms

- **Span** `(lo, hi)`: the integers `x` with `lo <= x < hi`. Boundary case: `(2, 3)`
  holds exactly the integer 2, and `(2, 2)` holds nothing.
- **Normal form**: the spans are sorted by `lo`, none is empty, and between any two
  consecutive spans at least one integer is missing from the set. Boundary case:
  `(1, 2)` with `(2, 3)` is not normal, because no integer lies between them; the normal
  form is `(1, 3)`. `(1, 2)` with `(3, 4)` is normal, because 2 is missing.

## Properties

Each property names the mutant that must turn a test of yours red.

1. **Normal form always.** After any sequence of calls, `spans()` is the normal form of
   the set, as a new list of tuples that the caller may change freely. Mutant: merge
   only spans that overlap, not spans that touch.
2. **Add is union.** After `add(lo, hi)` the set holds what it held plus the span.
   Mutant: merge with the first neighbour only.
3. **Remove is difference.** After `remove(lo, hi)` the set holds what it held minus the
   span; a stored span that straddles the removed one splits in two. Mutant: `<` for
   `<=` in the overlap test, so that a span touching the removed one is trimmed.
4. **Empty and reversed spans.** For `add`, `remove` and `gaps`: `lo == hi` is valid and
   names nothing (`add` and `remove` change nothing, `gaps` returns `[]`). `lo > hi`
   raises `ValueError` and changes nothing. The constructor follows `add`. Mutant: raise
   on `lo == hi`.
5. **Membership and size.** `x in s` is true exactly for the integers the set holds.
   `total()` is their count. Mutant: `<=` for `<` at the upper bound.
6. **Gaps.** `gaps(lo, hi)` is the normal form of the integers in `(lo, hi)` that the set
   does not hold. Mutant: ignore the window and return the gaps between stored spans.
7. **Equality.** Two sets are equal exactly when they hold the same integers, whatever
   calls built them. Mutant: compare the call history.

## Gate

`python3 -m unittest discover -s tests -t .` from the worktree root, green, with your
tests in the executed count. Tests go in `tests/test_*.py` and use only the standard
library and the surface above.

Update `README.md` with a usage section. Every sentence you add must be true of the code.
