"""Sets of integers stored as half-open spans."""


def _check(lo, hi):
    for v in (lo, hi):
        if isinstance(v, bool) or not isinstance(v, int):
            raise TypeError(f"bounds must be integers, got {v!r}")
    if lo > hi:
        raise ValueError(f"span start {lo} is above its end {hi}")


class IntervalSet:
    def __init__(self, spans=()):
        self._spans = []
        for lo, hi in spans:
            self.add(lo, hi)

    def add(self, lo, hi):
        _check(lo, hi)
        if lo == hi:
            return
        kept = []
        for a, b in self._spans:
            if b < lo or a > hi:
                kept.append((a, b))
            else:
                lo, hi = min(lo, a), max(hi, b)
        kept.append((lo, hi))
        kept.sort()
        self._spans = kept

    def remove(self, lo, hi):
        _check(lo, hi)
        if lo == hi:
            return
        kept = []
        for a, b in self._spans:
            if b <= lo or a >= hi:
                kept.append((a, b))
                continue
            if a < lo:
                kept.append((a, lo))
            if b > hi:
                kept.append((hi, b))
        self._spans = kept

    def spans(self):
        return list(self._spans)

    def __contains__(self, x):
        if isinstance(x, bool) or not isinstance(x, int):
            return False
        return any(a <= x < b for a, b in self._spans)

    def total(self):
        return sum(b - a for a, b in self._spans)

    def gaps(self, lo, hi):
        _check(lo, hi)
        out, cur = [], lo
        for a, b in self._spans:
            if b <= cur:
                continue
            if a >= hi:
                break
            if a > cur:
                out.append((cur, a))
            cur = max(cur, b)
        if cur < hi:
            out.append((cur, hi))
        return out

    def __eq__(self, other):
        if not isinstance(other, IntervalSet):
            return NotImplemented
        return self._spans == other._spans

    __hash__ = None
