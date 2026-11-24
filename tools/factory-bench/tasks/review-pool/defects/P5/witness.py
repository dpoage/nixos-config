# Property 10: a call that returns a waiting id claims its key.
from pool import Pool
p = Pool({"r": None}, {"r": 4})
p.reserve("r", 4, 0, 10)
w = p.reserve("r", 3, 0, 10, wait=True, key="k")
assert p.reserve("r", 3, 0, 10, wait=True, key="k") == w and p.waiting() == [w], p.waiting()
