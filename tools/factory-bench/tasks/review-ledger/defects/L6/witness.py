# Property 7/8: a replayed reverse key returns the reversal's id.
from ledger import Ledger
l = Ledger({"USD": 2}); l.open("a", "USD"); l.open("b", "USD")
t = l.post([("a", "5"), ("b", "-5")], when=1)
r = l.reverse(t, when=2, key="k")
assert l.reverse(t, when=2, key="k") == r
