# Property 8: cancelling a waiting reservation leaves usage unchanged.
from pool import Pool
p = Pool({"r": None}, {"r": 4})
a = p.reserve("r", 4, 0, 10)
w = p.reserve("r", 3, 0, 10, wait=True)
p.cancel(w)
assert p.usage("r", 5) == 4, p.usage("r", 5)
