# Property 3/6: statement amounts keep the currency exponent.
from ledger import Ledger
l = Ledger({"USD": 2}); l.open("a", "USD"); l.open("b", "USD")
l.post([("a", "5"), ("b", "-5")], when=1)
row = l.statement("a", 0, 10)[0]
assert str(row[2]) == "5.00", row
