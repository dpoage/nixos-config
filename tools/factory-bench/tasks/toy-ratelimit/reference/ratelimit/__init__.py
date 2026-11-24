"""Token-bucket rate limiter."""
import math
import os
import time

DEFAULT_RATE = 5.0
DEFAULT_BURST = 10


class TokenBucket:
    def __init__(self, rate, burst, clock=None):
        if isinstance(rate, bool) or not isinstance(rate, (int, float)) or math.isnan(rate) or rate < 0 or math.isinf(rate):
            raise ValueError(f"rate must be a finite number >= 0, got {rate!r}")
        if isinstance(burst, bool) or not isinstance(burst, int) or burst < 1:
            raise ValueError(f"burst must be an integer >= 1, got {burst!r}")
        self.rate = float(rate)
        self.burst = burst
        self._clock = clock or time.monotonic
        self._tokens = float(burst)
        self._last = self._clock()

    def _refill(self):
        now = self._clock()
        if now > self._last:
            self._tokens = min(float(self.burst), self._tokens + (now - self._last) * self.rate)
            self._last = now

    def _check(self, n):
        if isinstance(n, bool) or not isinstance(n, int) or n < 1 or n > self.burst:
            raise ValueError(f"n must be an integer in 1..{self.burst}, got {n!r}")

    def available(self):
        self._refill()
        return self._tokens

    def try_acquire(self, n=1):
        self._check(n)
        self._refill()
        if self._tokens >= n:
            self._tokens -= n
            return True
        return False

    def wait_time(self, n=1):
        self._check(n)
        self._refill()
        if self._tokens >= n:
            return 0.0
        if self.rate == 0:
            return math.inf
        return (n - self._tokens) / self.rate


def _read(environ, name, default, convert):
    raw = environ.get(name, "")
    if raw.strip() == "":
        return default
    try:
        return convert(raw.strip())
    except ValueError:
        raise ValueError(f"{name}: invalid value {raw!r}") from None


def from_env(environ=None, clock=None):
    environ = os.environ if environ is None else environ
    rate = _read(environ, "RL_RATE", DEFAULT_RATE, float)
    burst = _read(environ, "RL_BURST", DEFAULT_BURST, int)
    try:
        return TokenBucket(rate, burst, clock)
    except ValueError as e:
        name = "RL_BURST" if "burst" in str(e) else "RL_RATE"
        raise ValueError(f"{name}: {e}") from None
