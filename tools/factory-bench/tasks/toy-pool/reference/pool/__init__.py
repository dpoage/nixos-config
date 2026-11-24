"""Quota pool over a tenant tree."""

STATUSES = ("active", "waiting", "cancelled", "preempted", "evicted")


class NoCapacity(Exception):
    def __init__(self, node, at):
        super().__init__(f"no capacity at node {node!r} at instant {at}")
        self.node = node
        self.at = at


def _int(v):
    return isinstance(v, int) and not isinstance(v, bool)


class _R:
    def __init__(self, rid, node, units, start, end, priority, wait, preempt):
        self.id, self.node, self.units, self.start, self.end = rid, node, units, start, end
        self.priority, self.wait, self.preempt = priority, wait, preempt
        self.status = "active"

    def request(self):
        return (self.node, self.units, self.start, self.end, self.priority, self.wait, self.preempt)

    def covers(self, t):
        return self.start <= t < self.end


class Pool:
    def __init__(self, tree, quotas):
        if not tree or sum(p is None for p in tree.values()) != 1:
            raise ValueError("the tree needs exactly one root")
        self._chain = {}
        for n in tree:
            chain, x = [], n
            while x is not None:
                if x in chain or x not in tree:
                    raise ValueError(f"bad parent link at {x!r}")
                chain.append(x)
                x = tree[x]
            self._chain[n] = chain
        if set(quotas) != set(tree):
            raise ValueError("quotas must name exactly the nodes of the tree")
        for q in quotas.values():
            self._check_quota(q)
        self._quota = dict(quotas)
        self._res = []
        self._keys = {}
        self._events = []

    @staticmethod
    def _check_quota(q):
        if not _int(q) or q < 0:
            raise ValueError("a quota is an int of at least 0")

    # -- capacity ---------------------------------------------------------

    def _active(self, node=None):
        return [r for r in self._res if r.status == "active" and (node is None or node in self._chain[r.node])]

    def _usage(self, node, t):
        return sum(r.units for r in self._active(node) if r.covers(t))

    def _violations(self, node, units, start, end):
        """(chain node, instant) pairs over quota, nearest node first, then earliest instant."""
        points = sorted({start} | {r.start for r in self._active() if start < r.start < end})
        return [(a, t) for a in self._chain[node] for t in points if self._usage(a, t) + units > self._quota[a]]

    def _over(self, node):
        return [t for t in sorted({r.start for r in self._active(node)}) if self._usage(node, t) > self._quota[node]]

    def _displace(self, r, kind):
        r.status = kind
        self._events.append((kind, r.id))
        if r.wait:
            r.status = "waiting"
            self._events.append(("waiting", r.id))

    def _settle(self):
        for r in self._waiting():
            if not self._violations(r.node, r.units, r.start, r.end):
                r.status = "active"
                self._events.append(("promoted", r.id))

    def _waiting(self):
        return sorted((r for r in self._res if r.status == "waiting"), key=lambda r: (-r.priority, r.id))

    # -- commands ---------------------------------------------------------

    def reserve(self, node, units, start, end, *, priority=0, key=None, wait=False, preempt=False):
        if node not in self._chain:
            raise KeyError(node)
        if not _int(units) or units < 1:
            raise ValueError("units is an int of at least 1")
        if not _int(start) or not _int(end) or start >= end:
            raise ValueError("start and end are ints with start < end")
        if not _int(priority) or not 0 <= priority <= 9:
            raise ValueError("priority is an int from 0 to 9")
        new = _R(len(self._res) + 1, node, units, start, end, priority, bool(wait), bool(preempt))
        if key is not None and key in self._keys:
            old = self._keys[key]
            if old.request() != new.request():
                raise ValueError(f"key {key!r} was used for another request")
            return old.id
        first = self._violations(node, units, start, end)
        victims = []
        if first and preempt:
            order = sorted(
                (r for r in self._active() if r.priority < priority and r.start < end and start < r.end),
                key=lambda r: (r.priority, -r.start, -r.id),
            )
            for c in order:
                viol = self._violations(node, units, start, end)
                if not viol:
                    break
                if any(a in self._chain[c.node] and c.covers(t) for a, t in viol):
                    c.status = "trial"
                    victims.append(c)
            fits = not self._violations(node, units, start, end)
            for c in victims:
                c.status = "active"
            if not fits:
                victims = []
        if first and not victims:
            if not wait:
                raise NoCapacity(*first[0])
            new.status = "waiting"
        for c in victims:
            self._displace(c, "preempted")
        self._res.append(new)
        if key is not None:
            self._keys[key] = new
        self._events.append((new.status, new.id))
        if victims:
            self._settle()
        return new.id

    def _get(self, rid):
        if not _int(rid) or not 1 <= rid <= len(self._res):
            raise KeyError(rid)
        return self._res[rid - 1]

    def cancel(self, rid):
        r = self._get(rid)
        if r.status not in ("active", "waiting"):
            raise ValueError(f"reservation {rid} is {r.status}")
        r.status = "cancelled"
        self._events.append(("cancelled", rid))
        self._settle()

    def set_quota(self, node, quota, *, evict=False):
        if node not in self._chain:
            raise KeyError(node)
        self._check_quota(quota)
        old = self._quota[node]
        if quota == old:
            return
        self._quota[node] = quota
        if self._over(node) and not evict:
            self._quota[node] = old
            raise ValueError(f"usage at {node!r} is above {quota}")
        self._events.append(("quota", node, old, quota))
        for c in sorted(self._active(node), key=lambda r: (r.priority, -r.start, -r.id)):
            over = self._over(node)
            if not over:
                break
            if any(c.covers(t) for t in over):
                self._displace(c, "evicted")
        self._settle()

    # -- queries ----------------------------------------------------------

    def usage(self, node, at):
        if node not in self._chain:
            raise KeyError(node)
        return self._usage(node, at)

    def peak(self, node, start, end):
        if node not in self._chain:
            raise KeyError(node)
        if start >= end:
            raise ValueError("start must be below end")
        points = {start} | {r.start for r in self._active(node) if start < r.start < end}
        return max(self._usage(node, t) for t in points)

    def timeline(self, node):
        if node not in self._chain:
            raise KeyError(node)
        out, last = [], 0
        for t in sorted({x for r in self._active(node) for x in (r.start, r.end)}):
            u = self._usage(node, t)
            if u != last:
                out.append((t, u))
                last = u
        return out

    def status(self, rid):
        return self._get(rid).status

    def waiting(self):
        return [r.id for r in self._waiting()]

    def events(self):
        return list(self._events)
