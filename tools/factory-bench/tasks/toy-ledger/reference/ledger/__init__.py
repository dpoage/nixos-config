"""Double-entry ledger."""
import re
from collections import Counter
from decimal import Decimal

_AMOUNT = re.compile(r"-?\d+(\.\d+)?\Z")


class Ledger:
    def __init__(self, currencies):
        self._exp = {}
        for code, exp in currencies.items():
            if isinstance(exp, bool) or not isinstance(exp, int) or exp < 0:
                raise ValueError(f"exponent of {code} must be an integer >= 0, got {exp!r}")
            self._exp[code] = exp
        self._currency = {}
        self._closed = set()
        self._txns = []  # index + 1 == id; each: {"when", "lines": {account: Decimal}, "reverses", "reversed_by"}
        self._keys = {}

    def open(self, account, currency):
        if account in self._currency:
            raise ValueError(f"account {account} exists")
        if currency not in self._exp:
            raise KeyError(currency)
        self._currency[account] = currency

    def _parse(self, account, text):
        if not isinstance(text, str) or not _AMOUNT.match(text):
            raise ValueError(f"amount {text!r} is not a plain decimal")
        exp = self._exp[self._currency[account]]
        digits = len(text.partition(".")[2])
        if digits > exp:
            raise ValueError(f"amount {text!r} has more than {exp} decimal places")
        value = Decimal(text)
        if value == 0:
            raise ValueError("amount is zero")
        return value

    def _zero(self, account):
        return Decimal(1).scaleb(-self._exp[self._currency[account]]) * 0

    def _check_when(self, when):
        if isinstance(when, bool) or not isinstance(when, int):
            raise TypeError(f"when must be an integer, got {when!r}")

    def _commit(self, parsed, when, key, fingerprint, reverses=None):
        txn_id = len(self._txns) + 1
        lines = {}
        for account, value in parsed:
            lines[account] = lines.get(account, self._zero(account)) + value
        self._txns.append({"when": when, "lines": lines, "reverses": reverses, "reversed_by": None})
        if key is not None:
            self._keys[key] = (fingerprint, txn_id)
        return txn_id

    def _replay(self, key, fingerprint):
        if key is None or key not in self._keys:
            return None
        stored, txn_id = self._keys[key]
        if stored != fingerprint:
            raise ValueError(f"key {key!r} was used for a different request")
        return txn_id

    def post(self, entries, *, when, key=None):
        self._check_when(when)
        entries = list(entries)
        for account, _ in entries:
            if account not in self._currency:
                raise KeyError(account)
        parsed = [(account, self._parse(account, text)) for account, text in entries]
        fingerprint = ("post", when, frozenset(Counter(parsed).items()))
        replay = self._replay(key, fingerprint)
        if replay is not None:
            return replay
        if len(parsed) < 2:
            raise ValueError("a transaction needs at least two entries")
        for account, _ in parsed:
            if account in self._closed:
                raise ValueError(f"account {account} is closed")
        sums = {}
        for account, value in parsed:
            cur = self._currency[account]
            sums[cur] = sums.get(cur, 0) + value
        for cur, total in sums.items():
            if total != 0:
                raise ValueError(f"{cur} entries sum to {total}, not zero")
        return self._commit(parsed, when, key, fingerprint)

    def _txn(self, txn_id):
        if isinstance(txn_id, bool) or not isinstance(txn_id, int) or not 1 <= txn_id <= len(self._txns):
            raise KeyError(txn_id)
        return self._txns[txn_id - 1]

    def reverse(self, txn_id, *, when, key=None):
        self._check_when(when)
        txn = self._txn(txn_id)
        fingerprint = ("reverse", when, txn_id)
        replay = self._replay(key, fingerprint)
        if replay is not None:
            return replay
        if txn["reverses"] is not None:
            raise ValueError(f"transaction {txn_id} is a reversal")
        if txn["reversed_by"] is not None:
            raise ValueError(f"transaction {txn_id} is already reversed")
        if when < txn["when"]:
            raise ValueError("a reversal cannot be dated before its original")
        for account in txn["lines"]:
            if account in self._closed:
                raise ValueError(f"account {account} is closed")
        new_id = self._commit([(a, -v) for a, v in txn["lines"].items()], when, key, fingerprint, reverses=txn_id)
        txn["reversed_by"] = new_id
        return new_id

    def balance(self, account, *, at=None):
        if account not in self._currency:
            raise KeyError(account)
        total = self._zero(account)
        for txn in self._txns:
            if (at is None or txn["when"] <= at) and account in txn["lines"]:
                total += txn["lines"][account]
        return total

    def balances(self, *, at=None):
        out = {}
        for account in sorted(self._currency):
            value = self.balance(account, at=at)
            if value != 0:
                out[account] = value
        return out

    def statement(self, account, start, end):
        if account not in self._currency:
            raise KeyError(account)
        if start > end:
            raise ValueError("start is after end")
        rows = sorted(
            (txn["when"], i + 1, txn["lines"][account])
            for i, txn in enumerate(self._txns)
            if account in txn["lines"] and txn["lines"][account] != 0
        )
        running = self._zero(account)
        out = []
        for when, txn_id, amount in rows:
            if when >= end:
                break
            running += amount
            if when >= start:
                out.append((when, txn_id, amount, running))
        return out

    def close(self, account):
        if account not in self._currency:
            raise KeyError(account)
        if account in self._closed:
            raise ValueError(f"account {account} is closed")
        if self.balance(account) != 0:
            raise ValueError(f"account {account} has a balance")
        self._closed.add(account)
