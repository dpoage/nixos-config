# Property 7: settle runs after the new reservation becomes active.
from pool import Pool
p = Pool({"r": None}, {"r": 4})
v = p.reserve("r", 4, 0, 10)
w = p.reserve("r", 2, 0, 10, wait=True)
n = p.reserve("r", 3, 0, 10, priority=5, preempt=True)
assert p.status(n) == "active" and p.status(w) == "waiting", (p.events())
assert max(u for _, u in p.timeline("r")) <= 4, p.timeline("r")
