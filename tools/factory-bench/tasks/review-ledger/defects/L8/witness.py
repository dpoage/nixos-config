# Property 6: a statement lists nonzero lines only.
from ledger import Ledger
l = Ledger({"USD": 2}); l.open("a", "USD"); l.open("b", "USD"); l.open("c", "USD")
l.post([("a", "5"), ("a", "-5"), ("b", "3"), ("c", "-3")], when=1)
assert l.statement("a", 0, 10) == [], l.statement("a", 0, 10)
