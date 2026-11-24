#!/usr/bin/env python3
"""Factory benchmark: run one slice brief under a process arm and score the result.

A task is a brief plus a base tree plus hidden checks the workers never see.
An arm is a way of producing the slice: which driver prompt runs, how many
members attempt the brief in parallel, which agent-def / WATCHDOG / config
overlay is in force, and whether members cross-test before one is selected.

A review task inverts this: the slice is delivered with seeded defects, an arm
of review seats judges it, and the score is the defects their probes catch.

  bench.py selftest [task...]                 reference passes hidden, base fails;
                                              review: gate green, each witness bites
  bench.py run --task T --arm A [--reps N] [--model AGENT=MODEL ...]
  bench.py report [--runs DIR] [--compare CONFIG CONFIG]

Runs land in $FACTORY_BENCH_RUNS (default ~/.cache/factory-bench/runs).
Extra task directories: $FACTORY_BENCH_TASKS (colon-separated).
"""
import argparse
import ast
import concurrent.futures
import hashlib
import itertools
import json
import math
import os
import random
import re
import shutil
import statistics
import subprocess
import sys
import tempfile
import time
from collections import Counter, defaultdict
from pathlib import Path

HERE = Path(__file__).resolve().parent
RUNS = Path(os.environ.get("FACTORY_BENCH_RUNS", Path.home() / ".cache/factory-bench/runs"))
TASK_DIRS = [HERE / "tasks"] + [Path(p) for p in os.environ.get("FACTORY_BENCH_TASKS", "").split(":") if p]


def sh(cmd, cwd=None, timeout=None, env=None) -> tuple[int, str]:
    p = subprocess.run(
        cmd, cwd=cwd, shell=isinstance(cmd, str), text=True, timeout=timeout,
        stdout=subprocess.PIPE, stderr=subprocess.STDOUT, env=env,
    )
    return p.returncode, p.stdout


def must(cmd, cwd=None) -> str:
    rc, out = sh(cmd, cwd)
    if rc:
        sys.exit(f"command failed ({rc}): {cmd}\n{out}")
    return out


def load_task(name: str) -> dict:
    for d in TASK_DIRS:
        f = d / name / "task.json"
        if f.exists():
            task = json.loads(f.read_text()) | {"name": name, "dir": f.parent}
            if task.get("kind") == "review":
                # The fixture gives the base tree and the brief; `src` holds the delivered
                # slice and the defect specs, shared by a task and its clean control.
                task["fixture_task"] = load_task(task["fixture"])
                task["src"] = load_task(task["from"])["dir"] if "from" in task else task["dir"]
                task["hidden_total"] = len(task["defects"])
            elif task.get("kind") == "fix":
                # The fixture gives the base tree, the brief and the hidden tests.
                task["fixture_task"] = load_task(task["fixture"])
                task["hidden_total"] = task["fixture_task"]["hidden_total"]
            return task
    sys.exit(f"no task {name!r} under {[str(d) for d in TASK_DIRS]}")


def load_arm(name: str) -> dict:
    d = HERE / "arms" / name
    return json.loads((d / "arm.json").read_text()) | {"name": name, "dir": d}


def make_tree(task: dict, dest: Path) -> str:
    """Materialize the task's base tree at dest as a git checkout; return the base hash."""
    if "repo" in task:
        # A slice of a real repository, as a fresh one-commit repo: the workers see the base
        # tree and nothing else, so the historical solution is not one `git log --all` away.
        dest.mkdir(parents=True)
        must(f"git -C '{task['repo']}' archive {task['base']} | tar -x -C '{dest}'")
    else:
        shutil.copytree(task["dir"] / "repo", dest)
    must(["git", "init", "-q", "-b", "main"], dest)
    must(["git", "add", "-A"], dest)
    must(["git", "commit", "-qm", "base"], dest)
    return must(["git", "rev-parse", "HEAD"], dest).strip()


def overlay(arm: dict, wt: Path) -> None:
    """Install the arm's project-level .omp overlay (agent defs, WATCHDOG.yml) untracked."""
    src = arm["dir"] / "omp"
    if not src.is_dir():
        return
    shutil.copytree(src, wt / ".omp", dirs_exist_ok=True)
    exclude = Path(must(["git", "rev-parse", "--git-path", "info/exclude"], wt).strip())
    exclude = exclude if exclude.is_absolute() else wt / exclude
    exclude.parent.mkdir(parents=True, exist_ok=True)
    with exclude.open("a") as f:
        f.write("\n.omp/\n")


def usage(sessions: Path) -> dict:
    """Spend per model and per layer, from every transcript the run persisted."""
    by_model: dict[str, dict] = defaultdict(lambda: {"cost": 0.0, "tokens": 0, "requests": 0})
    by_layer: dict[str, float] = defaultdict(float)
    for f in sessions.rglob("*.jsonl"):
        rel = f.relative_to(sessions)
        layer = "advisor" if f.name.startswith("__advisor") else "driver" if len(rel.parts) == 1 else "worker"
        for line in f.read_text(errors="replace").splitlines():
            try:
                m = json.loads(line).get("message") or {}
            except (json.JSONDecodeError, AttributeError):
                continue
            u = m.get("usage") if isinstance(m, dict) else None
            if m.get("role") != "assistant" or not u:
                continue
            cost = (u.get("cost") or {}).get("total", 0.0)
            row = by_model[f"{m.get('provider')}/{m.get('model')}"]
            row["cost"] += cost
            row["tokens"] += u.get("totalTokens", 0)
            row["requests"] += 1
            by_layer[layer] += cost
    return {"by_model": dict(by_model), "by_layer": dict(by_layer), "total": sum(r["cost"] for r in by_model.values())}


def leaks(sessions: Path, forbidden: list[str]) -> list[str]:
    """Tool calls that touched a path the task forbids (its ground truth). Any hit voids the run."""
    hits = set()
    for f in sessions.rglob("*.jsonl"):
        for line in f.read_text(errors="replace").splitlines():
            try:
                m = json.loads(line).get("message") or {}
            except (json.JSONDecodeError, AttributeError):
                continue
            if not isinstance(m, dict) or m.get("role") != "assistant":
                continue
            for c in m.get("content") or []:
                # A `task` call carries the brief itself, which names those paths in order to forbid them.
                if isinstance(c, dict) and c.get("type") == "toolCall" and c.get("name") != "task":
                    args = json.dumps(c.get("arguments"))
                    hits.update(f"{f.name}: {p}" for p in forbidden if p in args)
    return sorted(hits)


def agent_fence(allow: list[str], rundir: Path) -> Path:
    """An overlay that leaves the driver only the agents its arm names."""
    known = {f.stem for f in (Path.home() / ".omp/agent/agents").glob("*.md")}
    known |= {"task", "scout", "sonic", "reviewer", "security-reviewer", "seance", "gigafast"}
    f = rundir / f"fence-{'-'.join(allow)}.yml"
    f.write_text("task:\n  disabledAgents:\n" + "".join(f'    - "{a}"\n' for a in sorted(known - set(allow))))
    return f


def provider_errors(sessions: Path) -> list[str]:
    """Transcripts that end on a provider failure (quota, rate limit, outage), not on the agent's own stop."""
    out = []
    for f in sessions.rglob("*.jsonl"):
        last = None
        for line in f.read_text(errors="replace").splitlines():
            try:
                m = json.loads(line).get("message") or {}
            except (json.JSONDecodeError, AttributeError):
                continue
            if isinstance(m, dict) and m.get("role") == "assistant":
                last = m
        if last and last.get("stopReason") == "error":
            out.append(f"{f.stem}: provider error: {str(last.get('errorMessage'))[:120]}")
    return out


def drive(arm: dict, wt: Path, rundir: Path, tag: str, prompt: str, extra_config: Path | None) -> dict:
    sessions = rundir / f"sessions-{tag}"
    cmd = [
        "omp", "-p", "--mode", "json", "--wait-async", "--auto-approve", "--no-title",
        "--session-dir", str(sessions), "--cwd", str(wt),
        "--model", arm["driver_model"], "--tools", arm["driver_tools"],
        "--max-time", arm.get("max_time", "3h"), "--max-cost", str(arm.get("max_cost", 40)),
    ]
    for cfg in (arm["dir"] / "config.yml", extra_config, agent_fence(arm.get("agents", ["implementer"]), rundir)):
        if cfg and cfg.exists():
            cmd += ["--config", str(cfg)]
    t0 = time.time()
    want = arm.get("expect_workers", 0)
    with (rundir / f"driver-{tag}.jsonl").open("w") as out:
        p = subprocess.Popen(cmd + [prompt], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, errors="replace")
        stopped = False
        results: set[str] = set()
        for line in p.stdout:
            out.write(line)
            results.update(re.findall(r'<task-result id=\\?"([^"\\]+)', line))
            # A relay driver is finished at its first turn without a tool call after every
            # agent's result arrived. The session's rules (TTSR) wake it again inside the same
            # agent run to "verify" the work, and the only tool it has for that starts another
            # agent in the tree. Stop it first. Disabling the rules instead would also strip
            # them from the workers.
            if want and len(results) >= want and line.startswith('{"type":"turn_end"') and '"type":"toolCall"' not in line:
                stopped = True
                p.terminate()
                break
        try:
            rc = p.wait(timeout=60)
        except subprocess.TimeoutExpired:
            p.kill()
            rc = p.wait()
        rc = 0 if stopped else rc
    # Agents the driver spawned: transcripts one level below its own session file.
    workers = [f.stem for f in sessions.glob("*/*.jsonl") if not f.name.startswith("__advisor")]
    return {"tag": tag, "rc": rc, "wall_s": round(time.time() - t0, 1), "sessions": str(sessions), "workers": workers}


def fill(text: str, wt: Path, scratch: Path) -> str:
    return text.replace("{WORKTREE}", str(wt)).replace("{SCRATCH}", str(scratch))


def unittest_counts(out: str) -> tuple[int, int]:
    """(passed, total) from `python -m unittest` output; an import error fails its module."""
    ran = re.search(r"^Ran (\d+) tests?", out, re.M)
    total = int(ran.group(1)) if ran else 0
    bad = sum(int(n) for n in re.findall(r"(?:failures|errors)=(\d+)", out))
    return max(total - bad, 0), total


def run_tests(tree: Path, start_dir: str, timeout: int = 600) -> tuple[int, int, str]:
    env = os.environ | {"PYTHONDONTWRITEBYTECODE": "1"}
    (tree / start_dir).mkdir(exist_ok=True)
    (tree / start_dir / "__init__.py").touch()  # discovery under -t needs a package
    try:
        _, out = sh([sys.executable, "-m", "unittest", "discover", "-s", start_dir, "-t", "."], tree, timeout, env)
    except subprocess.TimeoutExpired:
        return 0, 0, "timeout"
    return *unittest_counts(out), out


def head_tree(wt: Path, dest: Path) -> None:
    """Committed state only: uncommitted work is not a delivery."""
    dest.mkdir(parents=True)
    must(f"git -C '{wt}' archive HEAD | tar -x -C '{dest}'")


def score_hidden(task: dict, wt: Path, scratch: Path) -> dict:
    tree = scratch / "score"
    shutil.rmtree(tree, ignore_errors=True)
    head_tree(wt, tree)
    shutil.copytree(task["dir"] / "hidden", tree / "_hidden")
    passed, total, out = run_tests(tree, "_hidden")
    failed = sorted(set(re.findall(r"^(?:FAIL|ERROR): (\S+)", out, re.M)))
    # The denominator is the task's declared count: a hidden module that cannot import
    # loads as one erroring test, so its checks count as failed instead of vanishing.
    return {"passed": passed, "total": task["hidden_total"], "failed": failed}


SEAT = {"driver_model": "deepseek/deepseek-flash", "driver_tools": "task,wait", "agents": ["oracle"], "expect_workers": 1, "max_cost": 60, "max_time": "3h", "dir": HERE / "arms" / "solo"}


def score_seat(task: dict, wt: Path, base: str, rundir: Path, scratch: Path, driver_model: str) -> dict:
    """Replay the blockers real seats found on this slice: an oracle probes each at the new hash."""
    s = scratch / "seat"
    s.mkdir(parents=True, exist_ok=True)
    prompt = (HERE / "prompts" / "replay-seat.md").read_text()
    prompt = prompt.replace("{BLOCKERS}", (task["dir"] / "hidden" / "blockers.md").read_text()).replace("{BASE}", base)
    d = drive(SEAT | {"driver_model": driver_model}, wt, rundir, "seat", fill(prompt, wt, s), None)
    try:
        rows = json.loads((s / "seat.json").read_text())
    except (OSError, json.JSONDecodeError):
        rows = {}
    holds = sorted(k for k, v in rows.items() if v.get("status") == "HOLDS")
    return {
        "passed": len(holds), "total": task["hidden_total"],
        "failed": sorted(k for k, v in rows.items() if v.get("status") != "HOLDS"),
        "unreported": task["hidden_total"] - len(rows), "rows": rows,
        "score_cost": round(usage(Path(d["sessions"]))["total"], 4), "score_wall_s": d["wall_s"],
    }


def cross_matrix(task: dict, members: list[Path], scratch: Path) -> list[list[tuple[int, int, str]]]:
    """cell[i][j] = member j's own tests run against member i's code."""
    tdir = task["test_dir"]
    trees = []
    for i, wt in enumerate(members):
        t = scratch / f"cross-{i}"
        shutil.rmtree(t, ignore_errors=True)
        head_tree(wt, t)
        trees.append(t)
    matrix = []
    for i, code in enumerate(trees):
        row = []
        for j, tests in enumerate(trees):
            mix = scratch / f"mix-{i}-{j}"
            shutil.rmtree(mix, ignore_errors=True)
            shutil.copytree(code, mix)
            shutil.rmtree(mix / tdir, ignore_errors=True)
            if (tests / tdir).is_dir():
                shutil.copytree(tests / tdir, mix / tdir)
            row.append(run_tests(mix, tdir))
            shutil.rmtree(mix)
        matrix.append(row)
    return matrix


def diff_lines(wt: Path, base: str) -> int:
    out = must(["git", "diff", "--shortstat", f"{base}..HEAD"], wt)
    return sum(int(n) for n in re.findall(r"(\d+) (?:insertion|deletion)", out))


def apply_defect(tree: Path, d: Path) -> None:
    """Seed one defect: its code edits, then remove the visible tests that would catch it."""
    spec = json.loads((d / "defect.json").read_text())
    for e in spec["edits"]:
        f = tree / e["file"]
        text = f.read_text()
        if text.count(e["old"]) != 1:
            sys.exit(f"defect {d.name}: anchor occurs {text.count(e['old'])} times in {e['file']}")
        f.write_text(text.replace(e["old"], e["new"]))
    for t in spec["drop_tests"]:
        path, _, qual = t.partition("::")
        cls, _, meth = qual.partition(".")
        f = tree / path
        text = f.read_text()
        node = next((
            m for c in ast.parse(text).body if isinstance(c, ast.ClassDef) and c.name == cls
            for m in c.body if isinstance(m, ast.FunctionDef) and m.name == meth
        ), None)
        if node is None:
            sys.exit(f"defect {d.name}: no test {t}")
        lines = text.splitlines(keepends=True)
        del lines[min([node.lineno] + [x.lineno for x in node.decorator_list]) - 1:node.end_lineno]
        f.write_text("".join(lines))


def review_tree(task: dict, dest: Path, defects: list[str]) -> str:
    """The fixture's base commit, then one commit: the delivered slice with `defects` seeded. Returns the base hash."""
    base = make_tree(task["fixture_task"], dest)
    must(["git", "apply", str(task["src"] / "slice.patch")], dest)
    for i in defects:
        apply_defect(dest, task["src"] / "defects" / i)
    must(["git", "add", "-A"], dest)
    must(["git", "commit", "-qm", "slice"], dest)
    return base


def run_probe(tree: Path, probe: Path, scratch: Path, worktree: Path | None = None) -> bool | None:
    """A finding's probe on a fresh copy of tree: True when the property holds (exit 0), False when
    violated, None on timeout. The probe's directory is copied to `.probe/` inside the copy."""
    work = scratch / "probe"
    shutil.rmtree(work, ignore_errors=True)
    shutil.copytree(tree, work, ignore=shutil.ignore_patterns(".git"))
    shutil.copytree(probe, work / ".probe")
    if worktree:  # a probe that names the reviewed worktree still runs on the copy
        for f in (work / ".probe").rglob("*"):
            try:
                f.write_text(f.read_text().replace(str(worktree), str(work)))
            except (UnicodeDecodeError, IsADirectoryError):
                pass
    script = work / ".probe" / "probe.sh"
    # The probe's shebang picks its interpreter; a probe without one is a bash script.
    if script.read_text(errors="replace").startswith("#!"):
        script.chmod(0o755)
        cmd = ["./.probe/probe.sh"]
    else:
        cmd = ["bash", ".probe/probe.sh"]
    try:
        rc, _ = sh(cmd, work, 120, os.environ | {"PYTHONDONTWRITEBYTECODE": "1"})
    except subprocess.TimeoutExpired:
        return None
    finally:
        shutil.rmtree(work, ignore_errors=True)
    return rc == 0


def witness_probe(d: Path, dest: Path) -> Path:
    """A defect's witness in the form of a finding, so selftest exercises the scorer's probe path."""
    dest.mkdir(parents=True)
    shutil.copy(d / "witness.py", dest / "witness.py")
    (dest / "probe.sh").write_text("PYTHONPATH=. exec python3 .probe/witness.py\n")
    return dest


def review_trees(task: dict, scratch: Path) -> dict[str, Path]:
    """clean, seeded (every defect, as the seat saw it), and one tree per defect alone."""
    trees = {}
    for name, ds in [("clean", []), ("seeded", task["defects"])] + [(i, [i]) for i in task["defects"]]:
        trees[name] = scratch / f"tree-{name}"
        shutil.rmtree(trees[name], ignore_errors=True)
        review_tree(task, trees[name], ds)
    return trees


def score_review(task: dict, wt: Path, seat: Path, scratch: Path) -> dict:
    """Judge-free: a finding catches a defect when its probe fails on that defect alone and holds
    on the clean slice. Other findings are classed: `fails-clean` (a bad probe, or a real bug the
    clean slice has too; triage by hand), `no-signal` (holds on the seeded tree: a claim its probe
    does not show), `seeded-only` (fails only with several defects together)."""
    trees = review_trees(task, scratch)
    try:
        verdict = json.loads((seat / "verdict.json").read_text())
    except (OSError, json.JSONDecodeError):
        verdict = {}
    rows = {}
    for f in sorted(p for p in (seat / "findings").glob("*") if (p / "probe.sh").is_file()):
        on = {n: run_probe(t, f, scratch, wt) for n, t in trees.items()}
        catches = [i for i in task["defects"] if on["clean"] is True and on[i] is False]
        cls = ("catches" if catches else "fails-clean" if on["clean"] is False
               else "no-signal" if on["seeded"] is not False else "seeded-only")
        rows[f.name] = {"class": cls, "catches": catches, "on": on}
    caught = sorted({i for r in rows.values() for i in r["catches"]})
    return {
        "passed": len(caught), "total": len(task["defects"]), "caught": caught,
        "missed": [i for i in task["defects"] if i not in caught],
        "verdict": str(verdict.get("verdict") or "NONE").upper(),
        "claimed": len(verdict.get("findings") or []), "probed": len(rows),
        "classes": dict(Counter(r["class"] for r in rows.values())), "rows": rows,
    }


def tree_digest(*paths: Path) -> str:
    """sha256 over every file under the paths, symlinks followed: which defs, skills or task a run saw."""
    h = hashlib.sha256()
    for root in paths:
        if not root.exists():
            continue
        files = [root] if root.is_file() else sorted(
            Path(d) / f for d, _, fs in os.walk(root, followlinks=True) if "__pycache__" not in d for f in fs
        )
        for f in files:
            h.update(f"{f.relative_to(root.parent)}\0".encode())
            h.update(f.read_bytes())
    return h.hexdigest()[:12]


def versions(task: dict, arm: dict) -> dict:
    """What a result depends on besides its arm and task names, so two results can be told apart."""
    task_dirs = [task["dir"]] + ([task["fixture_task"]["dir"]] if "fixture_task" in task else []) + ([task["src"]] if "src" in task else [])
    return {
        "omp": sh(["omp", "--version"])[1].strip(),
        "agents": tree_digest(Path.home() / ".omp/agent/agents"),
        "skills": tree_digest(Path.home() / ".agents/skills"),
        "harness": tree_digest(HERE / "bench.py", HERE / "prompts"),
        "arm": tree_digest(arm["dir"]),
        "task": tree_digest(*dict.fromkeys(task_dirs)),
    }



REVIEW_SEAT = {"driver_model": "deepseek/deepseek-flash", "driver_tools": "task,wait", "agents": ["oracle"], "expect_workers": 1, "max_cost": 60, "max_time": "2h", "dir": HERE / "arms" / "review-solo"}


def fix_tree(task: dict, dest: Path) -> str:
    """The fixture's base commit, then one commit: the REJECTed build. Returns the base hash."""
    base = make_tree(task["fixture_task"], dest)
    must(["git", "apply", str(task["dir"] / "start.patch")], dest)
    must(["git", "add", "-A"], dest)
    must(["git", "commit", "-qm", "slice"], dest)
    return base


def read_verdict(seat: Path) -> str:
    try:
        return str(json.loads((seat / "verdict.json").read_text()).get("verdict") or "NONE").upper()
    except (OSError, json.JSONDecodeError, AttributeError):
        return "NONE"


def verdict_probes(verdict: Path) -> list[Path]:
    return sorted(p for p in (verdict / "findings").glob("*") if (p / "probe.sh").is_file())


def score_fix(task: dict, wt: Path, scratch: Path) -> dict:
    """Hidden tests before and after the fix round, and the original verdict's probes after it."""
    start = scratch / "start"
    shutil.rmtree(start, ignore_errors=True)
    fix_tree(task, start)
    before = score_hidden(task["fixture_task"], start, scratch / "s-start")
    after = score_hidden(task["fixture_task"], wt, scratch / "s-end")
    final = scratch / "final"
    shutil.rmtree(final, ignore_errors=True)
    head_tree(wt, final)
    probes = verdict_probes(task["dir"] / "verdict")
    return after | {
        "start_passed": before["passed"], "start_failed": before["failed"],
        "closed": sorted(set(before["failed"]) - set(after["failed"])),
        "regressions": sorted(set(after["failed"]) - set(before["failed"])),
        "findings": len(probes), "findings_closed": sum(run_probe(final, p, scratch, wt) is True for p in probes),
    }


def selftest_fix(task: dict) -> bool:
    """The start build fails hidden tests, and every finding of its verdict fails on it."""
    work = Path(tempfile.mkdtemp())
    start = work / "start"
    fix_tree(task, start)
    h = score_hidden(task["fixture_task"], start, work / "s")
    probes = verdict_probes(task["dir"] / "verdict")
    bad = [p.name for p in probes if run_probe(start, p, work) is not False]
    good = h["passed"] < h["total"] and probes and not bad and read_verdict(task["dir"] / "verdict") == "REJECT"
    print(f"{'ok ' if good else 'BAD'} {task['name']}: start {h['passed']}/{h['total']}, {len(probes)} findings, not failing on start: {bad}")
    shutil.rmtree(work, ignore_errors=True)
    return bool(good)


def cmd_mkfix(fixture: str, patch: Path, name: str, extra: Path | None, driver_model: str) -> None:
    """A fix task from a real build that fails hidden tests: one review seat on it writes the verdict."""
    dest = TASK_DIRS[0] / name
    if dest.exists():
        sys.exit(f"{dest} exists")
    fx = load_task(fixture)
    work = Path(tempfile.mkdtemp())
    wt, seat = work / "wt", work / "seat"
    seat.mkdir()
    base = make_tree(fx, wt)
    must(["git", "apply", str(patch)], wt)
    must(["git", "add", "-A"], wt)
    must(["git", "commit", "-qm", "slice"], wt)
    h = score_hidden(fx, wt, work / "s")
    if h["passed"] == h["total"]:
        sys.exit(f"{patch} passes every hidden test: a fix task needs a build that fails some")
    body = (HERE / "prompts" / "review-seat.md").read_text().replace("{BASE}", base).replace("{BRIEF}", (fx["dir"] / "brief.md").read_text())
    driver = (HERE / "prompts" / "solo.md").read_text().replace("{AGENT}", "oracle")
    d = drive(REVIEW_SEAT | {"driver_model": driver_model}, wt, work, "mkfix", driver.replace("{BRIEF}", fill(body, wt, seat)), extra)
    cost = usage(Path(d["sessions"]))["total"]
    v = read_verdict(seat)
    if v != "REJECT" or not verdict_probes(seat):
        sys.exit(f"the seat gave {v} with {len(verdict_probes(seat))} probes on a build failing {h['failed']} (${cost:.2f}); no task written. Sessions: {work}")
    dest.mkdir(parents=True)
    (dest / "start.patch").write_text(patch.read_text())
    (dest / "verdict").mkdir()
    shutil.copy(seat / "verdict.json", dest / "verdict" / "verdict.json")
    shutil.copytree(seat / "findings", dest / "verdict" / "findings")
    (dest / "task.json").write_text(json.dumps({
        "summary": f"Fix round on a real {fixture} build that fails {h['total'] - h['passed']} of {h['total']} hidden tests, against the verdict of one review seat on it.",
        "kind": "fix", "fixture": fixture, "source": str(patch),
        "forbidden": ["tools/factory-bench"],
    }, indent=1) + "\n")
    print(f"wrote {dest}: start {h['passed']}/{h['total']}, verdict {v} with {len(verdict_probes(seat))} probes, seat ${cost:.2f}")
    shutil.rmtree(work, ignore_errors=True)


def run_once(task: dict, arm: dict, rep: int, extra_config: Path | None, models: dict[str, str]) -> dict:
    stamp = time.strftime("%Y%m%dT%H%M%S")
    rundir = RUNS / f"{stamp}-{task['name']}-{arm['name']}-r{rep}-{os.getpid()}"
    scratch = rundir / "scratch"
    scratch.mkdir(parents=True)
    review, fix = task.get("kind") == "review", task.get("kind") == "fix"
    driver = (HERE / "prompts" / arm["driver_prompt"]).read_text().replace("{AGENT}", arm.get("worker", "implementer"))
    n = arm.get("members", 1)
    members = [rundir / f"wt{i}" for i in range(n)]
    base = ""
    for wt in members:
        base = review_tree(task, wt, task["defects"]) if review else fix_tree(task, wt) if fix else make_tree(task, wt)
        overlay(arm, wt)
    head = must(["git", "rev-parse", "HEAD"], members[0]).strip()
    if review or fix:
        fixture_brief = (task["fixture_task"]["dir"] / "brief.md").read_text()
        seat = (HERE / "prompts" / "review-seat.md").read_text().replace("{BASE}", base)
        brief = seat.replace("{BRIEF}", fixture_brief)
    else:
        brief = (task["dir"] / "brief.md").read_text()
    t0 = time.time()

    def attempt(i: int, phase: str, body: str) -> dict:
        s = scratch / f"m{i}"
        s.mkdir(exist_ok=True)
        return drive(arm, members[i], rundir, f"m{i}-{phase}", driver.replace("{BRIEF}", fill(body, members[i], s)), extra_config)

    reviews: list[dict] = []
    if fix:
        # A fix round, then (with `rereview`) a seat on the result; a REJECT with probes feeds the
        # next round, up to `loop_cap` rounds. The seat replaces the oracle re-review of a real round.
        verdict = scratch / "verdict-0"
        shutil.copytree(task["dir"] / "verdict", verdict)
        fix_body = (HERE / "prompts" / "fix-round.md").read_text().replace("{BASE}", base).replace("{BRIEF}", fixture_brief)
        reseat = (HERE / "prompts" / "rereview-seat.md").read_text().replace("{BASE}", base).replace("{START}", head).replace("{BRIEF}", fixture_brief)
        seat_driver = (HERE / "prompts" / "solo.md").read_text().replace("{AGENT}", "oracle")
        drives, final, iterations = [], "NONE", 0
        for iterations in range(1, arm.get("loop_cap", 1) + 1):
            drives.append(attempt(0, f"fix{iterations}", fix_body.replace("{VERDICT}", str(verdict))))
            if not arm.get("rereview"):
                break
            s = scratch / f"review{iterations}"
            s.mkdir()
            body = fill(reseat.replace("{VERDICT}", str(verdict)), members[0], s)
            reviews.append(drive(REVIEW_SEAT | {"driver_model": arm["driver_model"]}, members[0], rundir, f"review{iterations}", seat_driver.replace("{BRIEF}", body), extra_config))
            final = read_verdict(s)
            if final != "REJECT" or not verdict_probes(s):
                break
            verdict = s
    else:
        with concurrent.futures.ThreadPoolExecutor(n) as pool:
            drives = list(pool.map(lambda i: attempt(i, "build", brief), range(n)))

    result = {
        "task": task["name"], "arm": arm["name"], "models": models, "driver": arm["driver_model"], "rep": rep,
        "members": n, "base": base, "versions": versions(task, arm),
    }
    chosen = 0
    if n > 1:
        matrix = cross_matrix(task, members, scratch)
        result["divergence_before"] = sum(t - p for row in matrix for p, t, _ in row)
        if arm.get("cross_revise"):
            revise = (HERE / "prompts" / "revise.md").read_text()
            todo = []
            for i, row in enumerate(matrix):
                fails = "\n\n".join(
                    f"### member {j}'s tests against your code: {p}/{t} pass\n```\n{out[-6000:]}\n```"
                    for j, (p, t, out) in enumerate(row) if j != i and p < t
                )
                if fails:
                    todo.append((i, brief + "\n\n" + revise.replace("{FAILURES}", fails)))
            with concurrent.futures.ThreadPoolExecutor(max(len(todo), 1)) as pool:
                drives += list(pool.map(lambda a: attempt(a[0], "revise", a[1]), todo))
            matrix = cross_matrix(task, members, scratch)
            result["divergence_after"] = sum(t - p for row in matrix for p, t, _ in row)
        # Select without a judge: most of the union of everyone's tests passing, then the smaller diff.
        rank = [(sum(p for p, _, _ in row), -diff_lines(wt, base)) for row, wt in zip(matrix, members)]
        chosen = max(range(n), key=lambda i: rank[i])
        result["union_pass"] = [r[0] for r in rank]
    result["wall_s"] = round(time.time() - t0, 1)
    result["chosen"] = chosen
    result["drives"] = drives
    result["reviews"] = reviews
    result["diff_lines"] = diff_lines(members[chosen], head if fix else base)
    spend = [usage(Path(d["sessions"])) for d in drives]
    review_spend = [usage(Path(d["sessions"])) for d in reviews]
    if review:
        result["hidden"] = score_review(task, members[0], scratch / "m0", scratch)
        result["hidden_all"] = [result["hidden"]["passed"]]
        for part in ("verdict.json", "findings"):  # kept in the run dir: the scratch is deleted below
            src = scratch / "m0" / part
            if src.is_dir():
                shutil.copytree(src, rundir / "seat" / part)
            elif src.is_file():
                (rundir / "seat").mkdir(exist_ok=True)
                shutil.copy(src, rundir / "seat" / part)
    elif fix:
        result["hidden"] = score_fix(task, members[0], scratch) | {"iterations": iterations, "final_verdict": final}
        result["hidden_all"] = [result["hidden"]["passed"]]
        for d in reviews:  # kept in the run dir: the scratch is deleted below
            src = scratch / d["tag"]
            if (src / "verdict.json").is_file():
                shutil.copytree(src, rundir / d["tag"], ignore=lambda _, names: [x for x in names if x not in ("verdict.json", "findings")] if _ == str(src) else [])
    elif task.get("scorer") == "seat":  # one seat per run: only the delivered member is probed
        result["hidden"] = score_seat(task, members[chosen], base, rundir, scratch, arm["driver_model"])
        result["hidden_all"] = [result["hidden"]["passed"]]
    else:
        result["hidden"] = score_hidden(task, members[chosen], scratch)
        result["hidden_all"] = [score_hidden(task, wt, scratch)["passed"] for wt in members]
    result["cost"] = round(sum(s["total"] for s in spend + review_spend), 4)
    want = arm.get("expect_workers")
    result["void"] = [
        f"{d['tag']}: driver exit {d['rc']}" for d in drives + reviews if d["rc"]
    ] + [
        f"{d['tag']}: driver spawned {len(d['workers'])} agents, arm expects {want}"
        for d in drives if want and len(d["workers"]) != want
    ] + [
        f"{d['tag']}: review driver spawned {len(d['workers'])} agents, expects 1" for d in reviews if len(d["workers"]) != 1
    ]
    if review and (
        must(["git", "rev-parse", "HEAD"], members[0]).strip() != head
        or must(["git", "status", "--porcelain", "--untracked-files=no"], members[0]).strip()
    ):
        # An oracle that edits what it reviews broke its read-only rule: not the seat under test.
        result["void"].append("review seat changed the reviewed worktree")
    result["leaks"] = sorted({h for d in drives + reviews for h in leaks(Path(d["sessions"]), task.get("forbidden", []))})
    layers: dict[str, float] = defaultdict(float)
    by_model: dict[str, float] = defaultdict(float)
    for s in spend:
        for k, v in s["by_layer"].items():
            layers[k] += v
    for s in review_spend:
        layers["review"] += s["total"]
    for s in spend + review_spend:
        for k, v in s["by_model"].items():
            by_model[k] += v["cost"]
    result["cost_by_layer"] = {k: round(v, 4) for k, v in layers.items()}
    result["cost_by_model"] = {k: round(v, 4) for k, v in by_model.items()}
    # A worker cut off by its provider delivered nothing the arm can be blamed for.
    result["void"] += sorted({e for d in drives + reviews for e in provider_errors(Path(d["sessions"]))})
    if arm.get("expect_advisor") and not layers.get("advisor"):
        # An advisor that never produced a review did not take part: the run measured `solo`.
        result["void"].append("advisor arm, but no advisor review ran")
    for wt in members:
        (rundir / f"{wt.name}.patch").write_text(must(["git", "diff", f"{base}..HEAD"], wt))
        if "cleanup" in task:  # state the task's toolchain keeps outside the tree
            sh(task["cleanup"], wt, env=os.environ | {"WT": str(wt)})
        shutil.rmtree(wt, ignore_errors=True)
    shutil.rmtree(scratch, ignore_errors=True)
    (rundir / "result.json").write_text(json.dumps(result, indent=1))
    return result


def selftest_hidden(task: dict) -> bool:
    work = Path(tempfile.mkdtemp())
    base = work / "wt"
    make_tree(task, base)
    b = score_hidden(task, base, work / "s0")
    shutil.copytree(task["dir"] / "reference", base, dirs_exist_ok=True)
    must(["git", "add", "-A"], base)
    must(["git", "commit", "-qm", "reference"], base)
    r = score_hidden(task, base, work / "s1")
    good = r["passed"] == r["total"] and b["passed"] < b["total"]
    print(f"{'ok ' if good else 'BAD'} {task['name']}: base {b['passed']}/{b['total']}, reference {r['passed']}/{r['total']} {r['failed']}")
    shutil.rmtree(work, ignore_errors=True)
    return good


def selftest_review(task: dict) -> bool:
    """The delivered gate is green with every defect seeded, and each defect's witness holds on the
    clean slice and fails on that defect alone and on the seeded tree (no defect masks another)."""
    work = Path(tempfile.mkdtemp())
    trees = review_trees(task, work)
    tdir = task["fixture_task"].get("test_dir", "tests")
    good = True
    for name in ("clean", "seeded"):
        p, n, out = run_tests(trees[name], tdir)
        if not n or p != n:
            good = False
            print(f"BAD {task['name']}: visible gate red on the {name} tree ({p}/{n})\n{out[-2000:]}")
    for i in task["defects"]:
        probe = witness_probe(task["src"] / "defects" / i, work / f"witness-{i}")
        on = {n: run_probe(trees[n], probe, work) for n in ("clean", "seeded", i)}
        if on != {"clean": True, "seeded": False, i: False}:
            good = False
            print(f"BAD {task['name']}: witness {i}: holds on {on} (want clean only)")
    print(f"{'ok ' if good else 'BAD'} {task['name']}: {len(task['defects'])} defects, gate green, witnesses bite")
    shutil.rmtree(work, ignore_errors=True)
    return good


def cmd_selftest(names: list[str]) -> None:
    # A seat-scored real slice has no reference and no witness, so it has nothing to self-test.
    names = names or sorted(
        p.parent.name for d in TASK_DIRS for p in d.glob("*/task.json")
        if (p.parent / "reference").is_dir() or json.loads(p.read_text()).get("kind") in ("review", "fix")
    )
    ok = True
    for name in names:
        task = load_task(name)
        kind = task.get("kind")
        ok &= selftest_review(task) if kind == "review" else selftest_fix(task) if kind == "fix" else selftest_hidden(task)
    sys.exit(0 if ok else 1)


def config_label(r: dict) -> str:
    """An arm plus the agent models it ran with: the unit that report rows and comparisons name."""
    models = r.get("models")
    if models is None:  # results written before --model: a single implementer override
        models = {} if r.get("implementer", "def") == "def" else {"implementer": r["implementer"]}
    m = ",".join(f"{a}={v.split('/')[-1]}" for a, v in sorted(models.items()))
    return f"{r['arm']}[{m}]" if m else r["arm"]


def load_runs(runs: Path) -> dict[tuple[str, str], list[dict]]:
    rows = defaultdict(list)
    for f in sorted(runs.glob("*/result.json")):
        r = json.loads(f.read_text())
        if r.get("void") or r.get("leaks"):
            print(f"void, not counted: {f.parent.name}: {(r.get('void') or []) + (r.get('leaks') or [])}", file=sys.stderr)
            continue
        rows[(r["task"], config_label(r))].append(r)
    return rows


def frac(r: dict) -> float:
    h = r["hidden"]
    return h["passed"] / h["total"] if h["total"] else 1.0


def pass_hat_k(n: int, c: int, k: int) -> float | None:
    """Unbiased estimate that k fresh runs all pass fully, from c full passes in n runs."""
    return math.comb(c, k) / math.comb(n, k) if n >= k else None


def bootstrap(a: list[list[float]], b: list[list[float]], reps: int = 10000, seed: int = 0) -> tuple[float, float, float]:
    """Mean over tasks of mean(a) - mean(b), with a 95% interval; runs resampled within each task."""
    rng = random.Random(seed)
    point = statistics.mean(statistics.mean(x) - statistics.mean(y) for x, y in zip(a, b))
    draws = sorted(
        statistics.mean(statistics.mean(rng.choices(x, k=len(x))) - statistics.mean(rng.choices(y, k=len(y))) for x, y in zip(a, b))
        for _ in range(reps)
    )
    return point, draws[int(0.025 * reps)], draws[int(0.975 * reps) - 1]


def cmd_report(runs: Path, compare: list[str] | None, k: int) -> None:
    rows = load_runs(runs)
    mean = statistics.mean
    kinds = {task: load_task(task).get("kind", "build") for task, _ in rows}
    # The cheapest configurations that no other configuration beats on both score and cost.
    stats = {key: (mean(frac(r) for r in rs), mean(r["cost"] for r in rs)) for key, rs in rows.items()}
    frontier = {
        key for key, (s, c) in stats.items()
        if not any(t == key[0] and o != key and (s2 >= s and c2 <= c) and (s2 > s or c2 < c) for (t, o), (s2, c2) in stats.items())
    }
    print(f"| Task | Config | Runs | Score | Min | Full passes | pass^{k} | Worst member | Wall min | Cost $ | $ per full pass | Driver $ | Worker $ | Advisor $ | Divergence | Frontier |")
    print("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
    for (task, label), rs in sorted(rows.items()):
        layer = lambda name: mean(r["cost_by_layer"].get(name, 0.0) for r in rs)
        div = [r["divergence_before"] for r in rs if "divergence_before" in r]
        full = sum(r["hidden"]["passed"] == r["hidden"]["total"] for r in rs)
        pk = pass_hat_k(len(rs), full, k)
        print(
            f"| {task} | {label} | {len(rs)} | {mean(r['hidden']['passed'] for r in rs):.1f}/{rs[0]['hidden']['total']} "
            f"| {min(r['hidden']['passed'] for r in rs)} | {full}/{len(rs)} | {'-' if pk is None else f'{pk:.2f}'} "
            f"| {mean(min(r['hidden_all']) for r in rs):.1f} | {mean(r['wall_s'] for r in rs) / 60:.1f} "
            f"| {mean(r['cost'] for r in rs):.2f} | {f'{sum(r['cost'] for r in rs) / full:.2f}' if full else '-'} "
            f"| {layer('driver'):.2f} | {layer('worker'):.2f} | {layer('advisor'):.2f} "
            f"| {f'{mean(div):.1f}' if div else '-'} | {'yes' if (task, label) in frontier else ''} |"
        )
    saturated = sorted({task for (task, label), rs in rows.items() if len(rs) >= 5 and all(frac(r) == 1 for r in rs) and kinds[task] != "review"})
    if saturated:
        print(f"\nSaturated (one configuration passed fully in 5 or more of 5 or more runs; move to the regression set): {', '.join(saturated)}")
    review_report(rows, kinds)
    fix_report(rows, kinds)
    if compare:
        a, b = compare
        tasks = sorted(t for t, label in rows if label == a and (t, b) in rows)
        if not tasks:
            sys.exit(f"no task has runs of both {a!r} and {b!r}")
        print(f"\n## {a} minus {b}, score as a fraction of the task total, 95% bootstrap interval\n")
        print("| Task | Runs | Difference | Low | High |")
        print("|---|---|---|---|---|")
        for t in tasks:
            d, lo, hi = bootstrap([[frac(r) for r in rows[(t, a)]]], [[frac(r) for r in rows[(t, b)]]])
            print(f"| {t} | {len(rows[(t, a)])} vs {len(rows[(t, b)])} | {d:+.3f} | {lo:+.3f} | {hi:+.3f} |")
        if len(tasks) > 1:
            d, lo, hi = bootstrap([[frac(r) for r in rows[(t, a)]] for t in tasks], [[frac(r) for r in rows[(t, b)]] for t in tasks])
            print(f"| all {len(tasks)} tasks, equal weight | - | {d:+.3f} | {lo:+.3f} | {hi:+.3f} |")


def review_report(rows: dict, kinds: dict) -> None:
    """Seat quality on review tasks, then every two seats as a dual review: what their union catches."""
    rv = {key: rs for key, rs in rows.items() if kinds[key[0]] == "review"}
    if not rv:
        return
    mean = statistics.mean
    print("\n## Review seats\n")
    print("| Task | Config | Runs | Recall | REJECT | APPROVE | No verdict | Findings | Catches | Seeded-only | No-signal | Fails-clean | Cost $ |")
    print("|---|---|---|---|---|---|---|---|---|---|---|---|---|")
    for (task, label), rs in sorted(rv.items()):
        v = Counter(r["hidden"]["verdict"] for r in rs)
        cls = lambda c: mean(r["hidden"]["classes"].get(c, 0) for r in rs)
        total = rs[0]["hidden"]["total"]
        print(
            f"| {task} | {label} | {len(rs)} | {f'{mean(frac(r) for r in rs):.2f}' if total else '-'} "
            f"| {v['REJECT']} | {v['APPROVE']} | {len(rs) - v['REJECT'] - v['APPROVE']} "
            f"| {mean(r['hidden']['probed'] for r in rs):.1f} | {cls('catches'):.1f} | {cls('seeded-only'):.1f} "
            f"| {cls('no-signal'):.1f} | {cls('fails-clean'):.1f} | {mean(r['cost'] for r in rs):.2f} |"
        )
    print("\nOn a task with defects an APPROVE is a false APPROVE. On a clean control a REJECT is false unless a fails-clean probe shows a real bug.")
    print("\n## Dual review: two independent seats on one task\n")
    print("| Task | Seat A | Seat B | Pairs | Union recall | Both APPROVE | Cost $ |")
    print("|---|---|---|---|---|---|---|")
    for task in sorted({t for t, _ in rv if load_task(t)["defects"]}):
        labels = sorted(label for t, label in rv if t == task)
        for x, y in itertools.combinations_with_replacement(labels, 2):
            pairs = (itertools.combinations(rv[(task, x)], 2) if x == y
                     else itertools.product(rv[(task, x)], rv[(task, y)]))
            pairs = list(pairs)
            if not pairs:
                continue
            total = pairs[0][0]["hidden"]["total"]
            union = mean(len(set(p["hidden"]["caught"]) | set(q["hidden"]["caught"])) / total for p, q in pairs)
            both = sum(p["hidden"]["verdict"] == q["hidden"]["verdict"] == "APPROVE" for p, q in pairs)
            print(f"| {task} | {x} | {y} | {len(pairs)} | {union:.2f} | {both}/{len(pairs)} | {mean(p['cost'] + q['cost'] for p, q in pairs):.2f} |")


def fix_report(rows: dict, kinds: dict) -> None:
    """Fix rounds: what the fixer closed and broke, and what the loop to APPROVE cost."""
    fx = {key: rs for key, rs in rows.items() if kinds[key[0]] == "fix"}
    if not fx:
        return
    mean = statistics.mean
    print("\n## Fix rounds\n")
    print("| Task | Config | Runs | Hidden after | Closed | Regressions | Findings closed | Iterations | APPROVEd | False APPROVE | Fixer $ | Review $ | Loop $ | $ per APPROVE |")
    print("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
    for (task, label), rs in sorted(fx.items()):
        h = [r["hidden"] for r in rs]
        approved = [r for r in rs if r["hidden"]["final_verdict"] == "APPROVE"]
        false_ok = sum(r["hidden"]["passed"] < r["hidden"]["total"] for r in approved)
        fixer = mean(r["cost"] - r["cost_by_layer"].get("review", 0.0) for r in rs)
        review = mean(r["cost_by_layer"].get("review", 0.0) for r in rs)
        print(
            f"| {task} | {label} | {len(rs)} | {mean(x['passed'] for x in h):.1f}/{h[0]['total']} "
            f"| {mean(len(x['closed']) for x in h):.1f}/{len(h[0]['start_failed'])} | {mean(len(x['regressions']) for x in h):.1f} "
            f"| {mean(x['findings_closed'] for x in h):.1f}/{h[0]['findings']} | {mean(x['iterations'] for x in h):.1f} "
            f"| {len(approved)}/{len(rs)} | {false_ok} | {fixer:.2f} | {review:.2f} | {mean(r['cost'] for r in rs):.2f} "
            f"| {f'{sum(r['cost'] for r in rs) / len(approved):.2f}' if approved else '-'} |"
        )
    print("\nA false APPROVE is a loop that ended on APPROVE with hidden tests still failing.")


TRIGGERS = HERE / "skills" / "triggers.json"


def skills_read(sessions: Path) -> list[str]:
    """Skills a session opened with `read skill://<name>...`, in order, from its transcripts."""
    out = []
    for f in sorted(sessions.rglob("*.jsonl")):
        for line in f.read_text(errors="replace").splitlines():
            try:
                m = json.loads(line).get("message") or {}
            except (json.JSONDecodeError, AttributeError):
                continue
            for c in (m.get("content") or []) if isinstance(m, dict) and m.get("role") == "assistant" else []:
                if isinstance(c, dict) and c.get("type") == "toolCall" and c.get("name") == "read":
                    hit = re.match(r"skill://([^/:]+)", str((c.get("arguments") or {}).get("path", "")))
                    if hit and hit.group(1) not in out:
                        out.append(hit.group(1))
    return out


def trigger_case(skill: str, expect: str, prompt: str, model: str, outdir: Path, idx: int) -> dict:
    """One user prompt in a fresh session with the installed skills: which skills the model opens.
    The session stops at its first turn that opens a skill, or after its third turn."""
    work = Path(tempfile.mkdtemp())
    must(["git", "init", "-q"], work)
    sessions = outdir / f"sessions-{skill}-{expect}-{idx}"
    cmd = [
        "omp", "-p", "--mode", "json", "--auto-approve", "--no-title", "--session-dir", str(sessions),
        "--cwd", str(work), "--model", model, "--tools", "read", "--max-time", "3m", "--max-cost", "0.5", prompt,
    ]
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, errors="replace")
    turns = 0
    for line in p.stdout:
        if line.startswith('{"type":"turn_end"'):
            turns += 1
            if turns >= 3 or '"path":"skill://' in line:
                p.terminate()
                break
    try:
        p.wait(timeout=30)
    except subprocess.TimeoutExpired:
        p.kill()
    shutil.rmtree(work, ignore_errors=True)
    return {"skill": skill, "expect": expect, "prompt": prompt, "loaded": skills_read(sessions),
            "void": provider_errors(sessions), "cost": round(usage(sessions)["total"], 4)}


def cmd_trigger(skills: list[str], model: str, reps: int, jobs: int) -> None:
    """Does each skill's description get it loaded for the asks it covers, and only for those?"""
    cases = json.loads(TRIGGERS.read_text())
    unknown = sorted(set(skills) - set(cases))
    if unknown:
        sys.exit(f"no trigger cases for {unknown} in {TRIGGERS}")
    outdir = RUNS / f"trigger-{time.strftime('%Y%m%dT%H%M%S')}-{re.sub(r'[^A-Za-z0-9.-]', '_', model)}"
    outdir.mkdir(parents=True)
    todo = [
        (s, expect, prompt, i * 100 + j)
        for s in (skills or sorted(cases)) for expect in ("should", "should_not")
        for j, prompt in enumerate(cases[s][expect]) for i in range(reps)
    ]
    with concurrent.futures.ThreadPoolExecutor(jobs) as pool:
        rows = list(pool.map(lambda c: trigger_case(c[0], c[1], c[2], model, outdir, c[3]), todo))
    (outdir / "results.json").write_text(json.dumps({"model": model, "skills_digest": tree_digest(Path.home() / ".agents/skills"), "rows": rows}, indent=1))
    void = [r for r in rows if r["void"]]
    for r in void:
        print(f"void, not counted: {r['skill']} {r['expect']}: {r['void'][0]}", file=sys.stderr)
    rows = [r for r in rows if not r["void"]]
    print(f"| Skill | Loaded when it should | Loaded when it should not | Other skills opened on its asks |")
    print("|---|---|---|---|")
    for s in sorted({r["skill"] for r in rows}):
        hit = [r for r in rows if r["skill"] == s and r["expect"] == "should"]
        miss = [r for r in rows if r["skill"] == s and r["expect"] == "should_not"]
        others = Counter(x for r in hit for x in r["loaded"] if x != s)
        print(f"| {s} | {sum(s in r['loaded'] for r in hit)}/{len(hit)} | {sum(s in r['loaded'] for r in miss)}/{len(miss)} "
              f"| {', '.join(f'{k} {v}' for k, v in others.most_common()) or '-'} |")
    # A should_not ask of one skill is usually a should ask of a neighbour; count every load on it too.
    stray = Counter(x for r in rows if r["expect"] == "should_not" for x in r["loaded"])
    print(f"\nSkills opened on should-not asks: {', '.join(f'{k} {v}' for k, v in stray.most_common()) or 'none'}")
    print(f"Cost ${sum(r['cost'] for r in rows):.2f}, {len(void)} void. Results: {outdir / 'results.json'}")


def model_config(models: dict[str, str], advisor: str | None = None) -> Path | None:
    """An omp config overlay that routes agents (and the advisor role) to models; None when nothing is routed."""
    cfg = ""
    if models:
        cfg = "task:\n  agentModelOverrides:\n" + "".join(f'    {k}: "{v}"\n' for k, v in sorted(models.items()))
    if advisor:
        cfg += f'modelRoles:\n  advisor: "{advisor}"\n'
    if not cfg:
        return None
    RUNS.mkdir(parents=True, exist_ok=True)
    extra = RUNS / f"models-{hashlib.sha256(cfg.encode()).hexdigest()[:12]}.yml"
    extra.write_text(cfg)
    return extra


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    st = sub.add_parser("selftest")
    st.add_argument("tasks", nargs="*")
    run = sub.add_parser("run")
    run.add_argument("--task", required=True)
    run.add_argument("--arm", required=True)
    run.add_argument("--reps", type=int, default=1)
    run.add_argument("--model", action="append", default=[], metavar="AGENT=MODEL",
                     help="route an agent (implementer, oracle, implementer-max, ...) to a model for the run; repeatable")
    run.add_argument("--driver-model", help="run the arm's driver (in `split`, the lead) on this model")
    rep = sub.add_parser("report")
    rep.add_argument("--runs", type=Path, default=RUNS)
    rep.add_argument("--compare", nargs=2, metavar="CONFIG", help="bootstrap the score difference of two configs, as the Config column names them")
    rep.add_argument("--k", type=int, default=3, help="k of the pass^k column")
    mk = sub.add_parser("mkfix", help="write a fix task from a build that fails hidden tests; costs one review seat")
    mk.add_argument("--fixture", required=True)
    mk.add_argument("--patch", type=Path, required=True, help="the build, as a diff against the fixture's repo (a run's wt<N>.patch)")
    mk.add_argument("--name", required=True)
    mk.add_argument("--model", action="append", default=[], metavar="AGENT=MODEL", help="route the seat (oracle) to a model")
    mk.add_argument("--driver-model", default=REVIEW_SEAT["driver_model"], help="run the seat's driver on this model")
    tr = sub.add_parser("trigger", help="skill trigger accuracy: does each skill load for its asks and only for those")
    tr.add_argument("skills", nargs="*", help="skills to test (default: every skill in skills/triggers.json)")
    tr.add_argument("--model", required=True, help="the main-session model whose skill choice is tested")
    tr.add_argument("--reps", type=int, default=1)
    tr.add_argument("--jobs", type=int, default=6)
    a = ap.parse_args()
    if a.cmd == "selftest":
        cmd_selftest(a.tasks)
    elif a.cmd == "report":
        cmd_report(a.runs, a.compare, a.k)
    elif a.cmd == "mkfix":
        cmd_mkfix(a.fixture, a.patch.resolve(), a.name, model_config(dict(m.split("=", 1) for m in a.model)), a.driver_model)
    elif a.cmd == "trigger":
        cmd_trigger(a.skills, a.model, a.reps, a.jobs)
    else:
        models = dict(m.split("=", 1) for m in a.model)
        task, arm = load_task(a.task), load_arm(a.arm)
        if task.get("kind", "build") != arm.get("kind", "build"):
            sys.exit(f"arm {arm['name']} is for {arm.get('kind', 'build')} tasks; task {task['name']} is a {task.get('kind', 'build')} task")
        if arm.get("members", 1) != 1 and task.get("kind") in ("review", "fix"):
            sys.exit(f"arm {arm['name']} has several members; a {task['kind']} task scores one tree")
        if a.driver_model:
            arm["driver_model"] = a.driver_model
        advisor = None
        if arm.get("advisor_tier") == "implementer":
            # A peer advisor runs on the model the implementer runs on, whatever that is this run.
            if "implementer" not in models:
                sys.exit(f"arm {arm['name']} needs --model implementer=...: its advisor runs on the same model")
            advisor = models["implementer"]
        extra = model_config(models, advisor)
        for i in range(a.reps):
            r = run_once(task, arm, i, extra, models)
            print(json.dumps({k: r[k] for k in ("task", "arm", "rep", "hidden", "hidden_all", "wall_s", "cost", "cost_by_layer", "cost_by_model", "void", "leaks")}))


if __name__ == "__main__":
    main()
