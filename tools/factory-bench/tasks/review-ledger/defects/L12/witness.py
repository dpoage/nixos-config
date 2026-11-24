# Transaction ids: reverse(id) reverses the transaction accepted at that position,
# whatever the order of `when`.
from decimal import Decimal
from ledger import Ledger
l = Ledger({"USD": 2}); l.open("a", "USD"); l.open("b", "USD")
t1 = l.post([("a", "5"), ("b", "-5")], when=10)
t2 = l.post([("a", "7"), ("b", "-7")], when=1)
t3 = l.post([("a", "3"), ("b", "-3")], when=5)
l.reverse(t1, when=20)
assert l.balance("a") == Decimal("10"), l.balance("a")
