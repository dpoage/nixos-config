"""Step function over integer instants. Owned by the timeline slice."""


class Steps:
    """The sum of weighted intervals. An interval covers start <= t < end."""

    def __init__(self):
        self._deltas = {}

    def add(self, start, end, units):
        for t, d in ((start, units), (end, -units)):
            self._deltas[t] = self._deltas.get(t, 0) + d
            if not self._deltas[t]:
                del self._deltas[t]

    def remove(self, start, end, units):
        self.add(start, end, -units)

    def value(self, t):
        """The sum at instant t."""
        return sum(d for at, d in self._deltas.items() if at <= t)

    def max(self, start, end):
        """The largest value at any instant t with start <= t <= end.

        `end` is included: the dashboard draws closed ranges.
        """
        best = self.value(start)
        for at in self._deltas:
            if start < at <= end:
                best = max(best, self.value(at))
        return best

    def points(self):
        """The instants at which the value changes, ascending."""
        return sorted(self._deltas)
