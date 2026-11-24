# Property 7: preemption leaves a candidate that covers no violation.
from pool import Pool
p = Pool({"r": None, "a": "r", "b": "r"}, {"r": 10, "a": 10, "b": 4})
y = p.reserve("b", 4, 0, 10)
x = p.reserve("a", 3, 0, 10)  # first in victim order (higher id), outside the violated subtree
z = p.reserve("b", 2, 0, 10, priority=5, preempt=True)
assert p.status(x) == "active", (p.status(x), p.events())
