# Property 7: a replayed key returns its id even after an account of the request closed.
from ledger import Ledger
l = Ledger({"USD": 2}); l.open("a", "USD"); l.open("b", "USD")
t = l.post([("a", "5"), ("b", "-5")], when=1, key="k")
l.post([("a", "-5"), ("b", "5")], when=2); l.close("a")
assert l.post([("a", "5"), ("b", "-5")], when=1, key="k") == t
