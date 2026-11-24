# Slice brief: quota pool

There is no bead for this slice: skip every `bd` step. Load no skills.

## Place

- Worktree: `{WORKTREE}` (a git checkout on branch `main`; work on that branch).
- Scratch: `{SCRATCH}` (create it if you need it; delete what you put there).
- Commit with plain `git commit`. The configured identity applies; never override it.
- Files you own: `pool/__init__.py`, new modules under `pool/`, new test modules under
  `tests/`, and `README.md`.
- `pool/steps.py` and `tests/test_steps.py` belong to the timeline slice. You may import
  `pool.steps`. Never edit either file.
- Non-goals: persistence, concurrency, any file outside the list.

## What to build

`pool/__init__.py` exports exactly this surface. Other slices code against it, so
names, parameters and return types are fixed.

```python
class NoCapacity(Exception):      # not a ValueError
    node: str
    at: int

class Pool:
    def __init__(self, tree: dict[str, str | None], quotas: dict[str, int]): ...
    def reserve(self, node: str, units: int, start: int, end: int, *, priority: int = 0,
                key: str | None = None, wait: bool = False, preempt: bool = False) -> int: ...
    def cancel(self, rid: int) -> None: ...
    def set_quota(self, node: str, quota: int, *, evict: bool = False) -> None: ...
    def usage(self, node: str, at: int) -> int: ...
    def peak(self, node: str, start: int, end: int) -> int: ...
    def timeline(self, node: str) -> list[tuple[int, int]]: ...
    def status(self, rid: int) -> str: ...
    def waiting(self) -> list[int]: ...
    def events(self) -> list[tuple]: ...
```

## Terms

- **Tree**: `tree` maps each node to its parent, and the root to `None`.
  `{"root": None, "a": "root", "a1": "a"}`.
- **Chain** of a node: the node, its parent, and so on up to the root, in that order.
- **Subtree** of a node: every node whose chain contains it. A node is in its own subtree.
- **Reservation**: `units` of capacity at one node for the instants `t` with
  `start <= t < end`. Instants are integers. The interval is half-open: reservations
  for `[0, 5)` and `[5, 9)` share no instant.
- **Id**: a reservation's position in the order of creation, counting from 1. Every
  call of `reserve` that returns a new id creates a reservation, active or waiting. A
  call that raises creates nothing and uses no id.
- **Status**: one of `"active"`, `"waiting"`, `"cancelled"`, `"preempted"`, `"evicted"`.
- **Usage** of node `N` at instant `t`: the sum of the units of the active reservations
  at nodes in the subtree of `N` that cover `t`. A waiting reservation uses nothing.
- **Violation** of a request `(node, units, start, end)`: a pair `(A, t)` of a node `A`
  in the chain of `node` and an instant `t` in `[start, end)` where the usage of `A` at
  `t` plus `units` is above the quota of `A`. A request **fits** when it has no violation.
- **First violation**: the violation at the node that comes first in the chain (nearest
  to `node`); among the violations at that node, the one with the lowest instant.
- **Int**: an `int` that is not a `bool`. `True`, `1.0` and `"1"` are not ints.
- **Victim order**: priority ascending, then `start` descending, then id descending.
- **Waiting order**: priority descending, then id ascending.
- **Displace** a reservation as kind `K` (`"preempted"` or `"evicted"`): append the
  event `(K, id)`. If the reservation was created with `wait=True`, it becomes waiting
  again and the event `("waiting", id)` follows at once. Otherwise its status is `K`.
- **Settle**: go through the waiting reservations once, in waiting order. Each one that
  fits at that moment becomes active, with the event `("promoted", id)`. Settle never
  preempts.

## Properties

Each property names the mutant that must turn a test of yours red.

1. **Setup.** `Pool` raises `ValueError` when: the tree is empty; the tree does not
   have exactly one root; a parent is not a node of the tree; the parent links form a
   cycle; the keys of `quotas` are not exactly the nodes of the tree; or a quota is not
   an int of at least 0. A quota of 0 is valid. Mutant: accept a quota of `True`.
2. **Validation.** `reserve` raises `KeyError` for an unknown node. It raises
   `ValueError` when `units` is not an int of at least 1, when `start` or `end` is not
   an int, when `start >= end`, or when `priority` is not an int from 0 to 9. When the
   node is unknown and another argument is invalid, the call raises `KeyError`. Mutant:
   accept `start == end`.
3. **Capacity.** A request that fits creates an active reservation and appends the
   event `("active", id)`. Usage may equal a quota. Every node of the chain limits the
   request: two children may each be under their own quota and together above the
   parent's. Mutant: test only the quota of the reservation's own node.
4. **No capacity.** A request that does not fit, with `wait=False`, and that preemption
   (property 7) does not place, raises `NoCapacity` and changes nothing. The exception's
   `node` and `at` are the first violation, read before anything was displaced, and
   `str()` of the exception contains the node name and the instant. Mutant: report the
   violation at the root first.
5. **Queries.** `usage(node, at)` is the usage defined above. `peak(node, start, end)`
   is the highest usage of the node at an instant in `[start, end)`; it raises
   `ValueError` when `start >= end`. `timeline(node)` lists `(t, usage)` for every
   instant `t` at which the usage of the node differs from its usage at `t - 1`, in
   ascending order of `t`; with no active reservation in the subtree it is `[]`. All
   three raise `KeyError` for an unknown node. Mutant: let `peak` count a reservation
   that starts at `end`.
6. **Waiting.** A request that does not fit, with `wait=True`, and that preemption does
   not place, creates a waiting reservation, appends `("waiting", id)` and returns the
   id. `waiting()` lists the ids of the waiting reservations in waiting order. Mutant:
   list them in order of id.
7. **Preemption.** A request that does not fit, with `preempt=True`, may displace
   active reservations. The candidates are the active reservations with a priority
   strictly below the request's that share at least one instant with `[start, end)`.
   Take the candidates one at a time in victim order. Before each, compute the
   violations of the request against the reservations that are still active; stop when
   there are none. Displace the candidate if, for some violation `(A, t)`, it is in the
   subtree of `A` and covers `t`; otherwise leave it. If the request fits after the
   pass, the displaced candidates are displaced as `"preempted"`, in the order taken;
   then the new reservation becomes active with `("active", id)`; then settle runs. If
   the request still does not fit, nothing is displaced and no event is appended; the
   call then waits (`wait=True`) or raises `NoCapacity`. Mutant: let a request displace
   a reservation of equal priority.
8. **Cancel.** `cancel(rid)` raises `KeyError` for an unknown id and `ValueError` for a
   reservation that is neither active nor waiting. Otherwise the status becomes
   `"cancelled"`, the event `("cancelled", rid)` is appended, and settle runs. Mutant:
   skip settle.
9. **Quota.** `set_quota(node, quota)` raises `KeyError` for an unknown node and
   `ValueError` for a quota that is not an int of at least 0. A quota equal to the
   current one changes nothing and appends no event. When the usage of the node is
   above the new quota at some instant: with `evict=False` the call raises `ValueError`
   and changes nothing; with `evict=True` it evicts. Eviction takes the active
   reservations in the subtree of the node one at a time in victim order. Before each,
   it finds the instants at which the usage of the node is above the new quota, and
   stops when there are none. It displaces the candidate as `"evicted"` if the candidate
   covers one of those instants; otherwise it leaves it. Every accepted change appends
   `("quota", node, old, new)` before any eviction event, and settle runs last. Mutant:
   evict in order of id.
10. **Keys.** The request of a `reserve` call is the tuple of `node`, `units`, `start`,
    `end`, `priority`, `wait` and `preempt`. A call with a `key` that an earlier call
    claimed, and with the same request, returns that call's id, changes nothing and
    appends no event, whatever the status of that reservation is now. The same `key`
    with a different request raises `ValueError`. A call claims its key when it returns
    a new id, active or waiting. A call that raises claims nothing. Arguments are
    validated (property 2) before the key is looked up. Mutant: leave `wait` out of the
    request.
11. **Status and events.** `status(rid)` returns the status and raises `KeyError` for
    an unknown id. `events()` returns a new list of every event appended so far, in
    order. A call that raises appends no event. Mutant: return the internal list.
12. **The helper stays as it is.** `pool/steps.py` and `tests/test_steps.py` are byte
    for byte the files of the base commit. Mutant: none; the reviewer diffs the files.

## Gate

`python3 -m unittest discover -s tests -t .` from the worktree root, green, with your
tests in the executed count. Tests go in `tests/test_*.py` and use only the standard
library and the surface above.

Update `README.md` with a usage section. Every sentence you add must be true of the code.
