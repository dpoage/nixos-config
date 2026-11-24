# Property 7: a replay ignores the spelling of an amount.
from ledger import Ledger
l = Ledger({"USD": 2}); l.open("a", "USD"); l.open("b", "USD")
t = l.post([("a", "5"), ("b", "-5")], when=1, key="k")
assert l.post([("a", "5.0"), ("b", "-5.00")], when=1, key="k") == t
