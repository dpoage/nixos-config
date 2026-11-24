# factory-bench

factory-bench measures changes to the `oracle-rounds` process: the agent defs, the skills,
the models in each role, and the shape of each step. It runs one task under two or more
arms and scores each result with checks the workers never see.

A **task** is a starting tree, a brief, and hidden checks. An **arm** is one way to do
the task: which agents run, how many, on which driver prompt, and with which config.
Three kinds of task exist, one for each step of a round:

| Kind | The step | The arm produces | The score |
|---|---|---|---|
| Build | An implementer builds a slice | A commit | Hidden tests that pass, or blockers that a seat replays |
| Review | A review seat judges a delivered slice | A verdict and one probe per finding | Seeded defects that the probes catch |
| Fix | A fixer answers a REJECT | A fix commit, and with re-review a final verdict | Hidden tests closed and broken; loop spend per APPROVE |

## Run a comparison

1. Check every task: a build fixture's hidden tests pass on its reference and fail on
   its base; a review task's gate is green and each defect's witness bites; a fix task's
   start build fails and every finding of its verdict fails on it.

   ```sh
   tools/factory-bench/bench.py selftest
   ```

2. Run a task under an arm. Repeat the run to see the spread:

   ```sh
   tools/factory-bench/bench.py run --task review-pool --arm review-solo --reps 3 \
     --model oracle=deepseek/deepseek-flash
   ```

3. Compare the arms:

   ```sh
   tools/factory-bench/bench.py report
   tools/factory-bench/bench.py report --compare 'review-solo[oracle=deepseek-flash]' 'review-coop3[oracle=deepseek-flash]'
   ```

Each run costs model spend. `max_cost` in the arm's `arm.json` caps the spend of one
driver process in USD. A provider limit voids every run in progress, so run few cells
at a time.

An agent uses the model that its def names. To route an agent to another model for a
run, add `--model <agent>=<provider/model>` to `run`, once per agent. To run the driver
on another model, add `--driver-model <provider/model>`. In `split` the driver is the
lead, so `--driver-model` changes the lead's model. Every arm's driver runs on
`deepseek/deepseek-flash`; a driver only relays the brief.

## Arms

Build arms:

| Arm | What it changes |
|---|---|
| `solo` | Nothing. One implementer builds the brief with the installed defs. |
| `advisor-turn` | An advisor reviews every turn of the implementer and sends notes into its session. |
| `advisor-end` | The same advisor reviews once, when the implementer tries to finish. |
| `peer-advisor-turn` | `advisor-turn`, but the advisor runs on the implementer's model: a concurrent peer reviewer. Needs `--model implementer=...`. |
| `peer-advisor-end` | `advisor-end`, with the advisor on the implementer's model. Needs `--model implementer=...`. |
| `gang3` | Three implementers build the same brief in separate trees. The runner keeps one. |
| `gang3-cross` | `gang3`, then each member sees the peer tests that its code fails and revises once. |
| `gang3-coop` | Three implementers build the same brief together in one tree. They agree a plan by message, review each other's parts, and deliver one commit. |
| `split` | A lead splits the brief into sub-slices and dispatches one implementer per sub-slice. |

In `gang3` and `gang3-cross` the members work apart, and the runner selects one without
a judge. It runs every member's tests against every member's code. It keeps the member
whose code passes the most tests, and the smaller diff breaks a tie. `gang3-coop` has
one tree and one result, so nothing is selected.

Review arms:

| Arm | What it changes |
|---|---|
| `review-solo` | One `oracle` reviews the slice. |
| `review-coop3` | Three `oracle` agents fill one seat: they split the brief, check each other's probes, and deliver one verdict. |

A review arm is one seat. The report pairs the runs of any two review configurations on
a task as a dual review and shows what their union catches. So one set of single-seat
runs answers which pair of seats to run, for example an Opus seat beside a cooperating
deepseek-flash seat.

Fix arms:

| Arm | What it changes |
|---|---|
| `fix-solo` | One `implementer-max` fix round against the verdict. No re-review. |
| `fix-loop` | Fix rounds by `implementer-max`, each re-reviewed by one `oracle` seat, until APPROVE or two rounds: the seat's second consecutive REJECT forces triage. |
| `fix-coop3-loop` | `fix-loop`, with three `implementer-max` agents cooperating on each fix round. |

The re-review seat runs on the `oracle` model, so `--model oracle=...` routes it too.

An arm is a directory under `arms/`:

- `arm.json`: the driver prompt, the driver model and tools, `members`, `cross_revise`,
  and the caps.
  - `kind` is `build` (the default), `review` or `fix`. The runner refuses an arm whose
    kind differs from the task's.
  - `worker` is the agent the driver prompt starts; the default is `implementer`.
  - `agents` lists the agents that the driver may start; the default is `implementer`
    only. The fence holds for every agent in the run, so an `oracle` in a review arm
    cannot start `sweeper` agents.
  - `expect_workers` is the number of agents that one driver must start.
  - `advisor_tier: "implementer"` sets the advisor model to the implementer model of
    the run.
  - `rereview` and `loop_cap` (fix arms) add the re-review seat and cap the fix rounds.
- `config.yml` (optional): an omp config overlay for the run. To measure what a skill
  adds, run two arms that differ only in a `config.yml` with
  `skills: {ignoredSkills: [<skill>]}`.
- `omp/` (optional): files that the runner copies to `.omp/` in each tree, untracked.
  Agent defs in `omp/agents/` replace the installed defs of the same name. `omp/WATCHDOG.yml`
  defines advisors.

To test a change to a skill or an agent def, copy an arm, put the changed def in its
`omp/agents/`, and run both arms on the same tasks.

## Tasks

A task is a directory with a `task.json`. The runner replaces `{WORKTREE}` and
`{SCRATCH}` in every brief.

| Kind | Starting tree | Hidden checks | Example |
|---|---|---|---|
| Build fixture | `repo/`, with the brief in `brief.md` | `hidden/` holds `unittest` modules. `reference/` holds a solution for `selftest`. | `tasks/toy-ledger` |
| Build, real slice | `repo` and `base` in `task.json` name a repository and a commit. The runner copies that commit into a new one-commit repository. | `hidden/blockers.md` lists the blockers that review seats found on the first build. An `oracle` agent probes each blocker on the new build. | see below |
| Review | The fixture's base, then one commit: `slice.patch` with the `defects` of `task.json` seeded | `defects/<id>/`: `defect.json` (code edits, and the visible tests to remove) and `witness.py` | `tasks/review-pool` |
| Fix | The fixture's base, then one commit: `start.patch`, a real build that fails hidden tests | The fixture's hidden tests. `verdict/` holds the REJECT the fixer answers. | written by `mkfix` |

### Review tasks

`review-ledger` and `review-pool` start from a real deepseek-flash build that passed
every hidden test. Each seeds six defects. A defect's edits remove the visible tests
that would catch it, so the slice's gate stays green, as a seat sees it in a real round.
`review-ledger-clean` and `review-pool-clean` deliver the same slice with no defect. On a
clean task an APPROVE is correct, and the report counts false REJECTs.

The seat writes `verdict.json` and one `findings/<id>/probe.sh` per finding. The score
needs no judge. The runner rebuilds three kinds of tree: the clean slice, the seeded
slice, and the slice with each defect alone. It then runs every probe on each tree. A
probe exits 0 when the property holds. A finding catches a defect when its probe holds
on the clean slice and fails with that defect alone. The report puts each other finding
in one class:

- `fails-clean`: the probe fails on the clean slice too. Either the probe is wrong or
  the clean slice has a real bug. Read these by hand.
- `no-signal`: the probe holds on the seeded slice. Its claim is not shown.
- `seeded-only`: the probe fails only with several defects together.

`selftest` checks each defect's witness: it holds on the clean slice and fails with the
defect alone and on the seeded slice. A witness that holds on the seeded slice means
another defect masks it.

To add a defect, put the edits in `defects/<id>/defect.json`, write a `witness.py` that
asserts the property, list the id in `task.json`, and run `selftest`.

### Fix tasks

`mkfix` writes a fix task from a build that fails hidden tests, such as a run's
`wt0.patch`. `builds/` keeps three such builds of `toy-ledger`. One review seat runs on the build, and its REJECT becomes the task's
verdict. If the seat APPROVEs, `mkfix` writes no task: the seat missed the failures.

```sh
tools/factory-bench/bench.py mkfix --fixture toy-ledger --name fix-ledger-a \
  --patch tools/factory-bench/builds/toy-ledger-41.patch --model oracle=<provider/model>
```

The fix score compares the fixture's hidden tests on the start build and on the fixed
build: `closed` failed before and pass now, and `regressions` passed before and fail
now. With re-review, a loop that ends on APPROVE while hidden tests still fail is a false
APPROVE.

### Real slices

A real-slice task contains text from the repository that it replays, so it stays out
of this repository. Set `FACTORY_BENCH_TASKS` to the directories that hold such tasks,
separated by colons.

A real-slice task runs the toolchain of its repository. Do not run one on a host where a
round is in progress: the load fails that round's timing-sensitive tests.

`forbidden` in `task.json` lists path fragments that hold the answer. A run whose
workers touch one of them lists the hits under `leaks` in its result. Review and fix
tasks forbid `tools/factory-bench`, which holds their defects and witnesses.

## Skill triggers

`trigger` tests whether a skill's description gets the skill loaded for the asks it
covers, and only for those. `skills/triggers.json` holds, for each skill, asks that
should load it and asks that should not. Most should-not asks belong to a neighbouring
skill.

```sh
tools/factory-bench/bench.py trigger --model deepseek/deepseek-flash
tools/factory-bench/bench.py trigger github-voice doc-writer --model <provider/model> --reps 3
```

Each ask runs in a fresh session in an empty git repository, with the installed skills
and only the `read` tool. A session stops at its first turn that opens a skill, or after
its third turn. The table shows, per skill, the loads on its asks, the loads on its
should-not asks, and the other skills that its asks opened.

## Void runs

A driver is a small model session that starts the agents of the arm. A run is void if
any of these holds:

- A driver exits with an error.
- A driver starts a number of agents other than `expect_workers`.
- A worker touches a `forbidden` path.
- A transcript ends on a provider error, such as a rate limit or a spend limit.
- The arm sets `expect_advisor` and no advisor review ran.
- A review seat changed the reviewed worktree.

`result.json` lists the reasons under `void` and `leaks`. `report` prints each void run
to stderr and does not count the run.

## Results

Each run writes a directory under `~/.cache/factory-bench/runs`, or under
`$FACTORY_BENCH_RUNS`. The directory holds:

- `result.json`: the score, the wall time, and the spend per model and per layer
  (driver, worker, advisor, review). `versions` records the omp version and a digest of
  the installed agent defs, the installed skills, the harness, the arm and the task.
  Two results with different digests measured different things.
- `wt<N>.patch`: the diff of each member.
- `seat/` (review) and `review<N>/` (fix with re-review): each verdict and its probes.
- `sessions-*`: every transcript of the run.

`divergence_before` in a gang result counts the peer tests that failed across all
pairs of members. Members that build one brief two ways disagree on what the brief
means, so a high count points at an ambiguous brief.

`report` prints:

- One row per task and configuration, where a configuration is an arm and the models of
  its run. The row shows `pass^k`: the estimated chance that k new runs all pass fully,
  from the runs so far. It also shows the spend per full pass. `Frontier` marks the
  configurations that no other configuration on the task beats on both score and cost.
- The tasks that one configuration passed fully in at least 5 of at least 5 runs. Such
  a task no longer separates arms; move it to the regression set.
- For review tasks, seat quality and every pair of seats as a dual review.
- For fix tasks, what each fixer closed and broke, the re-review spend, and the spend
  per APPROVE.
- With `--compare A B`, the score difference of two configurations per task and over
  all tasks, with a 95% bootstrap interval. The interval resamples the runs of each
  configuration. With few runs and no spread it shrinks to a point, which shows that
  the runs agree, not that the difference is certain.

## Gate replay

`gates.py` reads the gate directories that a past round left behind. It reports the
wall time and the red runs of each gate leg:

```sh
tools/factory-bench/gates.py ~/.local/share/factory-bench/corpus
```
