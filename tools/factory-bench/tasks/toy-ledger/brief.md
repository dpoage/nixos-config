# Slice brief: double-entry ledger

There is no bead for this slice: skip every `bd` step. Load no skills.

## Place

- Worktree: `{WORKTREE}` (a git checkout on branch `main`; work on that branch).
- Scratch: `{SCRATCH}` (create it if you need it; delete what you put there).
- Commit with plain `git commit`. The configured identity applies; never override it.
- Files you own: `ledger/` (any modules), `tests/` (new test modules), `README.md`.
  Non-goals: persistence, concurrency, currency conversion, any file outside the list.

## What to build

`ledger/__init__.py` exports exactly this surface. Other slices code against it, so
names, parameters and return types are fixed.

```python
class Ledger:
    def __init__(self, currencies: dict[str, int]): ...   # code -> exponent
    def open(self, account: str, currency: str) -> None: ...
    def post(self, entries, *, when: int, key: str | None = None) -> int: ...
    def reverse(self, txn_id: int, *, when: int, key: str | None = None) -> int: ...
    def balance(self, account: str, *, at: int | None = None) -> Decimal: ...
    def balances(self, *, at: int | None = None) -> dict[str, Decimal]: ...
    def statement(self, account: str, start: int, end: int) -> list[tuple]: ...
    def close(self, account: str) -> None: ...
```

`entries` is an iterable of `(account, amount)` pairs. `amount` is a string. A positive
amount is a debit and a negative amount is a credit. `when` is an integer timestamp.

## Terms

- **Exponent**: the number of decimal places a currency keeps. `{"USD": 2, "JPY": 0}`.
- **Valid amount**: a string that matches `-?\d+(\.\d+)?`, has at most the exponent's
  number of digits after the point, and is not zero. Boundary cases for USD: `"5"`,
  `"5.0"` and `"-5.25"` are valid. `"5.000"` is invalid, although its value fits,
  because it has three digits after the point. `"+5"`, `"1e2"`, `"0.00"` and the number
  `5` are invalid.
- **Transaction**: one accepted `post` or `reverse`. Its id is its position in the order
  of acceptance, counting from 1. A call that raises is not a transaction and uses no id.
- **Line**: the sum of one transaction's entries for one account. A transaction with
  entries `("cash", "5")` and `("cash", "2")` has one line for `cash`, of 7.
- **Request**: for `post`, the `when` plus the entries as a multiset of
  (account, numeric value). Order and spelling do not matter: `"5.0"` and `"5"` are one
  value. Splitting does matter: one entry of 5 and two entries of 2 and 3 are different
  requests. For `reverse`, the request is the `when` plus the `txn_id`. A `post` request
  never equals a `reverse` request.

## Properties

Each property names the mutant that must turn a test of yours red.

1. **Setup.** A currency exponent below zero raises `ValueError`. `open` raises
   `KeyError` for a currency the ledger does not have and `ValueError` for an account
   that exists. Mutant: accept a second `open` of one account.
2. **Posting is atomic.** `post` raises and changes nothing, and uses no id, when: an
   account is unknown (`KeyError`); an amount is invalid; there are fewer than two
   entries; an account is closed; or, for any one currency, the entries in that currency
   do not sum to zero (all `ValueError`). When an unknown account and another fault are
   both present, the call raises `KeyError`. Mutant: check the sum across all
   currencies together.
3. **Amounts keep their exponent.** `balance` returns a `Decimal` with exactly the
   exponent's number of decimal places: `Decimal("0.00")` for a new USD account,
   `Decimal("0")` for JPY. Mutant: return `Decimal(0)` for an account with no lines.
4. **Dated balance.** `balance(account, at=t)` is the sum of the account's lines in
   transactions with `when <= t`; `at=None` means all of them. Transactions may be
   accepted in any order of `when`. Mutant: `<` for `<=`.
5. **Balances.** `balances(at=...)` maps each account whose balance is not zero to that
   balance, in order of account name. Mutant: include zero balances.
6. **Statement.** `statement(account, start, end)` lists the account's nonzero lines
   with `start <= when < end`, ordered by `when` and then by id, as tuples
   `(when, txn_id, amount, running)`. `running` is the account's balance after that
   line, counting every earlier line in that order, including lines before `start`.
   `start > end` raises `ValueError`. Mutant: start `running` at zero at `start`.
7. **Keys.** A call with a `key` that an accepted transaction already used, and with the
   same request, returns that transaction's id and changes nothing. This holds whatever
   happened since, including the close of an account. The same `key` with a different
   request raises `ValueError`. `post` and `reverse` share one set of keys. A call that
   raises does not claim its key. Mutant: compare the entries as an ordered list.
8. **Reversal.** `reverse(txn_id, when=t)` accepts a new transaction whose lines negate
   the original's. It raises and changes nothing when: the id is unknown (`KeyError`);
   the original is itself a reversal; the original was already reversed; `t` is below
   the original's `when` (equal is allowed); or one of its accounts is closed (all
   `ValueError`). Mutant: allow a second reversal.
9. **Close.** `close(account)` raises `KeyError` for an unknown account and `ValueError`
   for a closed account or a balance that is not zero. A closed account keeps its
   history: `balance` and `statement` still answer. Mutant: let `post` reach a closed
   account.
10. **Unknown accounts in queries.** `balance` and `statement` raise `KeyError` for an
    account the ledger does not have. Mutant: return a zero balance for it.

## Gate

`python3 -m unittest discover -s tests -t .` from the worktree root, green, with your
tests in the executed count. Tests go in `tests/test_*.py` and use only the standard
library and the surface above.

Update `README.md` with a usage section. Every sentence you add must be true of the code.
