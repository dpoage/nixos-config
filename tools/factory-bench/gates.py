#!/usr/bin/env python3
"""Gate replay: what each scripted-gate leg cost and what it caught.

Reads the gate run directories a round left behind (gate-<name>-<hash>/ with
changed.txt, format.log, atomtest.log and, for merge candidates, consumers.log).
Leg wall time comes from file mtimes: each log is closed when its leg ends, so the
gap between two consecutive logs is the later leg's duration.

usage: gates.py <corpus-dir> [--json]
"""
import json
import re
import sys
from collections import Counter
from pathlib import Path

RED = re.compile(r"^(//\S+)\s+(FAILED|TIMEOUT|NO STATUS)", re.M)


def mtime(p: Path) -> float | None:
    return p.stat().st_mtime if p.exists() else None


def reds(log: Path) -> list[str]:
    if not log.exists():
        return []
    return sorted(set(m.group(1) for m in RED.finditer(log.read_text(errors="replace"))))


def gate(d: Path) -> dict | None:
    start, fmt, atom, cons = (mtime(d / n) for n in ("changed.txt", "format.log", "atomtest.log", "consumers.log"))
    if not (start and fmt and atom) or atom < fmt:
        return None  # a gate that died before its test leg closed is not a measurement
    name, _, h = d.name.removeprefix("gate-").rpartition("-")
    return {
        "round": d.parent.name,
        "gate": name,
        "hash": h,
        "changed_files": len((d / "changed.txt").read_text().split()),
        "setup_s": fmt - start,
        "slice_leg_s": atom - fmt,
        "consumer_leg_s": (cons - atom) if cons and cons > atom else 0.0,
        "slice_reds": reds(d / "atomtest.log"),
        "consumer_reds": reds(d / "consumers.log"),
    }


def main() -> None:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    corpus = Path(args[0])
    gates = [g for d in sorted(corpus.glob("fx-r*/gate-*-*")) if d.is_dir() and (g := gate(d))]
    if "--json" in sys.argv:
        json.dump(gates, sys.stdout, indent=1)
        return
    print("| Round | Gates | With consumer leg | Slice leg h | Consumer leg h | Consumer share | Slice-leg red runs | Consumer-leg red runs |")
    print("|---|---|---|---|---|---|---|---|")
    for rnd in sorted({g["round"] for g in gates}):
        gs = [g for g in gates if g["round"] == rnd]
        s = sum(g["slice_leg_s"] for g in gs) / 3600
        c = sum(g["consumer_leg_s"] for g in gs) / 3600
        print(
            f"| {rnd} | {len(gs)} | {sum(1 for g in gs if g['consumer_leg_s'])} | {s:.1f} | {c:.1f} | "
            f"{100 * c / (s + c):.0f}% | {sum(1 for g in gs if g['slice_reds'])} | {sum(1 for g in gs if g['consumer_reds'])} |"
        )
    for leg in ("slice_reds", "consumer_reds"):
        tally = Counter(t for g in gates for t in g[leg])
        print(f"\n{leg}: red target, runs red")
        for t, n in tally.most_common():
            print(f"  {n:3d}  {t}")
    with_cons = sorted((g["consumer_leg_s"] for g in gates if g["consumer_leg_s"]))
    if with_cons:
        print(f"\nconsumer leg minutes: median {with_cons[len(with_cons) // 2] / 60:.0f}, max {with_cons[-1] / 60:.0f}")
    sl = sorted(g["slice_leg_s"] for g in gates)
    print(f"slice leg minutes: median {sl[len(sl) // 2] / 60:.0f}, max {sl[-1] / 60:.0f}")


if __name__ == "__main__":
    main()
