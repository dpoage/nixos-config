#!/usr/bin/env python3
"""Factory benchmark: run one slice brief under a process arm and score the result.

A task is a brief plus a base tree plus hidden checks the workers never see.
An arm is a way of producing the slice: which driver prompt runs, how many
members attempt the brief in parallel, which agent-def / WATCHDOG / config
overlay is in force, and whether members cross-test before one is selected.

  bench.py selftest [task...]                 reference passes hidden, base fails
  bench.py run --task T --arm A [--reps N] [--implementer-model M]
  bench.py report [--runs DIR]

Runs land in $FACTORY_BENCH_RUNS (default ~/.cache/factory-bench/runs).
Extra task directories: $FACTORY_BENCH_TASKS (colon-separated).
"""
import argparse
import concurrent.futures
import json
import os
import re
import shutil
import statistics
import subprocess
import sys
import time
from collections import defaultdict
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
            return json.loads(f.read_text()) | {"name": name, "dir": f.parent}
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


SEAT = {"driver_model": "anthropic/claude-haiku-4-5", "driver_tools": "task,wait", "agents": ["oracle", "sweeper"], "expect_workers": 1, "max_cost": 60, "max_time": "3h", "dir": HERE / "arms" / "solo"}


def score_seat(task: dict, wt: Path, base: str, rundir: Path, scratch: Path) -> dict:
    """Replay the blockers real seats found on this slice: an oracle probes each at the new hash."""
    s = scratch / "seat"
    s.mkdir(parents=True, exist_ok=True)
    prompt = (HERE / "prompts" / "replay-seat.md").read_text()
    prompt = prompt.replace("{BLOCKERS}", (task["dir"] / "hidden" / "blockers.md").read_text()).replace("{BASE}", base)
    d = drive(SEAT, wt, rundir, "seat", fill(prompt, wt, s), None)
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


def run_once(task: dict, arm: dict, rep: int, extra_config: Path | None, implementer: str) -> dict:
    stamp = time.strftime("%Y%m%dT%H%M%S")
    rundir = RUNS / f"{stamp}-{task['name']}-{arm['name']}-r{rep}-{os.getpid()}"
    scratch = rundir / "scratch"
    scratch.mkdir(parents=True)
    brief = (task["dir"] / "brief.md").read_text()
    driver = (HERE / "prompts" / arm["driver_prompt"]).read_text()
    n = arm.get("members", 1)
    members = [rundir / f"wt{i}" for i in range(n)]
    base = ""
    for wt in members:
        base = make_tree(task, wt)
        overlay(arm, wt)
    t0 = time.time()

    def attempt(i: int, phase: str, body: str) -> dict:
        s = scratch / f"m{i}"
        s.mkdir(exist_ok=True)
        return drive(arm, members[i], rundir, f"m{i}-{phase}", driver.replace("{BRIEF}", fill(body, members[i], s)), extra_config)

    with concurrent.futures.ThreadPoolExecutor(n) as pool:
        drives = list(pool.map(lambda i: attempt(i, "build", brief), range(n)))

    result = {"task": task["name"], "arm": arm["name"], "implementer": implementer, "driver": arm["driver_model"], "rep": rep, "members": n, "base": base}
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
    result["diff_lines"] = diff_lines(members[chosen], base)
    spend = [usage(Path(d["sessions"])) for d in drives]
    if task.get("scorer") == "seat":  # one seat per run: only the delivered member is probed
        result["hidden"] = score_seat(task, members[chosen], base, rundir, scratch)
        result["hidden_all"] = [result["hidden"]["passed"]]
    else:
        result["hidden"] = score_hidden(task, members[chosen], scratch)
        result["hidden_all"] = [score_hidden(task, wt, scratch)["passed"] for wt in members]
    result["cost"] = round(sum(s["total"] for s in spend), 4)
    want = arm.get("expect_workers")
    result["void"] = [
        f"{d['tag']}: driver exit {d['rc']}" for d in drives if d["rc"]
    ] + [
        f"{d['tag']}: driver spawned {len(d['workers'])} agents, arm expects {want}"
        for d in drives if want and len(d["workers"]) != want
    ]
    result["leaks"] = sorted({h for d in drives for h in leaks(Path(d["sessions"]), task.get("forbidden", []))})
    layers: dict[str, float] = defaultdict(float)
    models: dict[str, float] = defaultdict(float)
    for s in spend:
        for k, v in s["by_layer"].items():
            layers[k] += v
        for k, v in s["by_model"].items():
            models[k] += v["cost"]
    result["cost_by_layer"] = {k: round(v, 4) for k, v in layers.items()}
    result["cost_by_model"] = {k: round(v, 4) for k, v in models.items()}
    # A worker cut off by its provider delivered nothing the arm can be blamed for.
    result["void"] += sorted({e for d in drives for e in provider_errors(Path(d["sessions"]))})
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


def cmd_selftest(names: list[str]) -> None:
    # Only tasks scored by hidden tests carry a reference; a seat-scored task has none.
    names = names or sorted(p.parent.name for d in TASK_DIRS for p in d.glob("*/reference"))
    ok = True
    for name in names:
        task = load_task(name)
        work = Path(must(["mktemp", "-d"]).strip())
        base = work / "wt"
        make_tree(task, base)
        b = score_hidden(task, base, work / "s0")
        shutil.copytree(task["dir"] / "reference", base, dirs_exist_ok=True)
        must(["git", "add", "-A"], base)
        must(["git", "commit", "-qm", "reference"], base)
        r = score_hidden(task, base, work / "s1")
        good = r["passed"] == r["total"] and b["passed"] < b["total"]
        ok &= good
        print(f"{'ok ' if good else 'BAD'} {name}: base {b['passed']}/{b['total']}, reference {r['passed']}/{r['total']} {r['failed']}")
        shutil.rmtree(base, ignore_errors=True)
        shutil.rmtree(work, ignore_errors=True)
    sys.exit(0 if ok else 1)


def cmd_report(runs: Path) -> None:
    rows = defaultdict(list)
    for f in sorted(runs.glob("*/result.json")):
        r = json.loads(f.read_text())
        if r.get("void") or r.get("leaks"):
            print(f"void, not counted: {f.parent.name}: {(r.get('void') or []) + (r.get('leaks') or [])}", file=sys.stderr)
            continue
        rows[(r["task"], r.get("implementer", "def"), r["arm"])].append(r)
    print("| Task | Implementer | Arm | Runs | Hidden pass | Min | Full passes | Worst member | Wall min | Cost $ | Driver $ | Worker $ | Advisor $ | Divergence |")
    print("|---|---|---|---|---|---|---|---|---|---|---|---|---|---|")
    mean = statistics.mean
    for (task, impl, arm), rs in sorted(rows.items()):
        layer = lambda k: mean(r["cost_by_layer"].get(k, 0.0) for r in rs)
        div = [r["divergence_before"] for r in rs if "divergence_before" in r]
        print(
            f"| {task} | {impl.split('/')[-1]} | {arm} | {len(rs)} | {mean(r['hidden']['passed'] for r in rs):.1f}/{rs[0]['hidden']['total']} "
            f"| {min(r['hidden']['passed'] for r in rs)} | {sum(r['hidden']['passed'] == r['hidden']['total'] for r in rs)}/{len(rs)} "
            f"| {mean(min(r['hidden_all']) for r in rs):.1f} | {mean(r['wall_s'] for r in rs) / 60:.1f} "
            f"| {mean(r['cost'] for r in rs):.2f} | {layer('driver'):.2f} | {layer('worker'):.2f} | {layer('advisor'):.2f} "
            f"| {f'{mean(div):.1f}' if div else '-'} |"
        )


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    st = sub.add_parser("selftest")
    st.add_argument("tasks", nargs="*")
    run = sub.add_parser("run")
    run.add_argument("--task", required=True)
    run.add_argument("--arm", required=True)
    run.add_argument("--reps", type=int, default=1)
    run.add_argument("--implementer-model", help="route the implementer agent to this model for the run")
    run.add_argument("--driver-model", help="run the arm's driver (in `split`, the lead) on this model")
    rep = sub.add_parser("report")
    rep.add_argument("--runs", type=Path, default=RUNS)
    a = ap.parse_args()
    if a.cmd == "selftest":
        cmd_selftest(a.tasks)
    elif a.cmd == "report":
        cmd_report(a.runs)
    else:
        extra = None
        if a.implementer_model:
            RUNS.mkdir(parents=True, exist_ok=True)
            extra = RUNS / f"implementer-{re.sub(r'[^A-Za-z0-9.-]', '_', a.implementer_model)}.yml"
            extra.write_text(f'task:\n  agentModelOverrides:\n    implementer: "{a.implementer_model}"\n')
        task, arm = load_task(a.task), load_arm(a.arm)
        if a.driver_model:
            arm["driver_model"] = a.driver_model
        if arm.get("advisor_tier") == "implementer":
            # A peer advisor runs on the model the implementer runs on, whatever that is this run.
            if not extra:
                sys.exit(f"arm {arm['name']} needs --implementer-model: its advisor runs on the same model")
            peer = extra.with_name(extra.stem + "-peer-advisor.yml")
            peer.write_text(extra.read_text() + f'modelRoles:\n  advisor: "{a.implementer_model}"\n')
            extra = peer
        for i in range(a.reps):
            r = run_once(task, arm, i, extra, a.implementer_model or "def")
            print(json.dumps({k: r[k] for k in ("task", "arm", "rep", "hidden", "hidden_all", "wall_s", "cost", "cost_by_layer", "cost_by_model", "void", "leaks")}))


if __name__ == "__main__":
    main()
