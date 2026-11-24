# Slice brief: token-bucket rate limiter

There is no bead for this slice: skip every `bd` step. Load no skills.

## Place

- Worktree: `{WORKTREE}` (a git checkout on branch `main`; work on that branch).
- Scratch: `{SCRATCH}` (create it if you need it; delete what you put there).
- Commit with plain `git commit`. The configured identity applies; never override it.
- Files you own: `ratelimit/__init__.py`, `tests/` (new test modules), `README.md`.
  Blast radius: the whole of those files. Non-goals: packaging, async support,
  thread safety, any file outside the list.

## What to build

`ratelimit/__init__.py` exports exactly this surface. Other slices code against it,
so names, parameters and return types are fixed.

```python
class TokenBucket:
    rate: float   # tokens added per second, as given
    burst: int    # capacity, as given
    def __init__(self, rate, burst, clock=None): ...
    def available(self) -> float: ...        # tokens in the bucket now
    def try_acquire(self, n=1) -> bool: ...  # take n tokens, or take none
    def wait_time(self, n=1) -> float: ...   # seconds until n tokens are available

def from_env(environ=None, clock=None) -> TokenBucket: ...
```

`clock` is a zero-argument callable that returns seconds as a float. `None` means
`time.monotonic`, looked up when the bucket is constructed.

## Terms

- **Reading**: one call of `clock`. Every method takes a reading before it answers.
- **Last reading**: the largest reading the bucket has taken so far. Boundary case: the
  clock reads 100, then 90, then 101. The last reading after the second call is still
  100, so the third call sees one second elapsed, not eleven.
- **Elapsed**: the new reading minus the last reading, or zero when that is negative.

## Properties

Each property names the mutant that must turn a test of yours red.

1. **Full start, hard cap.** A new bucket holds `burst` tokens. For every sequence of
   readings, `available()` is at most `burst`, and tokens that the cap discarded never
   come back. Mutant: remove the cap.
2. **Refill.** Between two readings the bucket gains `elapsed * rate` tokens, fractions
   included, and fractions carry across calls. Mutant: truncate the gain to an integer.
3. **All or nothing.** `try_acquire(n)` returns `True` and removes `n` tokens when
   `available() >= n`, including when they are equal. Otherwise it returns `False` and
   removes nothing. Mutant: `>` for `>=`. Mutant: subtract before the comparison.
4. **Backwards clock.** A reading below the last reading adds no tokens and leaves the
   last reading where it was (see Terms). Mutant: store every reading as the last one.
5. **Request bounds.** For `try_acquire` and `wait_time`: `n` below 1 or above `burst`
   raises `ValueError` and changes nothing. Mutant: accept `n == burst + 1`.
6. **Wait time.** `wait_time(n)` is `0.0` when `available() >= n`. Otherwise it is
   `(n - available()) / rate`, and `math.inf` when `rate` is zero. It removes nothing.
   Mutant: divide when `rate` is zero.
7. **Construction.** `rate` below zero raises `ValueError`; zero is allowed. `burst`
   below 1 raises `ValueError`. Mutant: reject `rate == 0`.
8. **Environment.** `from_env` reads `RL_RATE` (a float, default `5.0`) and `RL_BURST`
   (an integer, default `10`) from `environ`, or from `os.environ` when `environ` is
   `None`. A variable that is unset or empty takes its default. A value that does not
   parse, or that property 7 rejects, raises `ValueError` whose message contains the
   variable's name. Mutant: treat the empty string as invalid.

## Gate

`python3 -m unittest discover -s tests -t .` from the worktree root, green, with your
tests in the executed count. Tests go in `tests/test_*.py`, use only the standard
library and the surface above, and inject a fake clock; never sleep.

Update `README.md` with a usage section. Every sentence you add must be true of the code.
