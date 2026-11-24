# Property 9: an accepted quota change settles, also without eviction.
from pool import Pool
p = Pool({"r": None}, {"r": 4})
p.reserve("r", 4, 0, 10)
w = p.reserve("r", 3, 0, 10, wait=True)
p.set_quota("r", 7)
assert p.status(w) == "active", p.events()
