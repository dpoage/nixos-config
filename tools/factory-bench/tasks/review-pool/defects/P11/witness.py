# Settle: promotion follows waiting order (priority descending, then id).
from pool import Pool
p = Pool({"r": None}, {"r": 4})
a = p.reserve("r", 4, 0, 10)
lo = p.reserve("r", 3, 0, 10, wait=True)
hi = p.reserve("r", 3, 0, 10, priority=5, wait=True)
p.cancel(a)
assert p.status(hi) == "active" and p.status(lo) == "waiting", p.events()
