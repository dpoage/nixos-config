# factory-bench

factory-bench measures changes to the `oracle-rounds` process. It runs one slice brief
under two or more process arms and scores each result with checks the workers never see.

A **task** is a brief, a base tree, and hidden checks. An **arm** is one way to produce
the slice: how many implementers attempt the brief, which agent defs and advisors are in
force, and how one result is selected.

## Run a comparison

1. Check that every task's hidden checks pass on its reference and fail on its base:

   ```sh
   tools/factory-bench/bench.py selftest
   ```

2. Run a task under an arm. Repeat the run to see the spread:

   ```sh
   tools/factory-bench/bench.py run --task toy-ledger --arm solo --reps 3
   ```

3. Compare the arms:

   ```sh
   tools/factory-bench/bench.py report
   ```

Each run costs model spend. `max_cost` in the arm's `arm.json` caps the spend of one
driver process in USD.

The implementer agent uses the model that its def names. To test a different
implementer model, add `--implementer-model <provider/model>` to `run`. To run the
driver on a different model, add `--driver-model <provider/model>`. In `split` the
driver is the lead, so this flag changes the lead's model.

## Arms

| Arm | What it changes |
|---|---|
| `solo` | Nothing. One implementer builds the brief with the installed defs. |
| `advisor-turn` | An advisor reviews every turn of the implementer and sends notes into its session. |
| `advisor-end` | The same advisor reviews once, when the implementer tries to finish. |
| `peer-advisor-turn` | `advisor-turn`, but the advisor runs on the implementer's model: a concurrent peer reviewer. Needs `--implementer-model`. |
| `peer-advisor-end` | `advisor-end`, with the advisor on the implementer's model. Needs `--implementer-model`. |
| `gang3` | Three implementers build the same brief in separate trees. The runner keeps one. |
| `gang3-cross` | `gang3`, then each member sees the peer tests that its code fails and revises once. |
| `gang3-coop` | Three implementers build the same brief together in one tree. They agree a plan by message, review each other's parts, and deliver one commit. |
| `split` | A lead splits the brief into sub-slices and dispatches one implementer per sub-slice. |

In `gang3` and `gang3-cross` the members work apart, and the runner selects one without
a judge. It runs every member's tests against every member's code. It keeps the member
whose code passes the most tests, and the smaller diff breaks a tie. `gang3-coop` has
one tree and one result, so nothing is selected.

An arm is a directory under `arms/`:

- `arm.json`: the driver prompt, the driver model and tools, `members`, `cross_revise`,
  and the caps. `agents` lists the agents that the driver may start; the default is
  `implementer` only. `expect_workers` is the number of agents that one driver must start.
  `advisor_tier: "implementer"` sets the advisor model to the implementer model of the run.
- `config.yml` (optional): an omp config overlay for the run.
- `omp/` (optional): files that the runner copies to `.omp/` in each tree, untracked.
  Agent defs in `omp/agents/` replace the installed defs of the same name. `omp/WATCHDOG.yml`
  defines advisors.

To test a change to a skill or an agent def, copy an arm, put the changed def in its
`omp/agents/`, and run both arms on the same tasks.

## Tasks

A task is a directory with a `task.json` and a `brief.md`. The runner replaces
`{WORKTREE}` and `{SCRATCH}` in the brief.

| Kind | Base tree | Hidden checks | Example |
|---|---|---|---|
| Fixture | `repo/` | `hidden/` holds `unittest` modules. `reference/` holds a solution for `selftest`. | `tasks/toy-ledger` |
| Real slice | `repo` and `base` in `task.json` name a repository and a commit. The runner copies that commit into a new one-commit repository. | `hidden/blockers.md` lists the blockers that review seats found on the first build. An `oracle` agent probes each blocker on the new build. | see below |

A real-slice task contains text from the repository that it replays, so it stays out
of this repository. Set `FACTORY_BENCH_TASKS` to the directories that hold such tasks,
separated by colons.

A real-slice task runs the toolchain of its repository. Do not run one on a host where a
round is in progress: the load fails that round's timing-sensitive tests.

`forbidden` in `task.json` lists path fragments that hold the answer. A run whose
workers touch one of them lists the hits under `leaks` in its result.

## Void runs

A driver is a small model session that starts the agents of the arm. A run is void if
any of these holds:

- A driver exits with an error.
- A driver starts a number of agents other than `expect_workers`.
- A worker touches a `forbidden` path.
- A transcript ends on a provider error, such as a rate limit or a spend limit.
- The arm sets `expect_advisor` and no advisor review ran.

`result.json` lists the reasons under `void` and `leaks`. `report` prints each void run
to stderr and does not count the run.

A provider spend limit voids every run that is in progress. Run few cells at a time.

## Results

Each run writes a directory under `~/.cache/factory-bench/runs`, or under
`$FACTORY_BENCH_RUNS`. The directory holds:

- `result.json`: the hidden score, the wall time, and the spend per model and per layer
  (driver, worker, advisor).
- `wt<N>.patch`: the diff of each member.
- `sessions-*`: every transcript of the run.

`divergence_before` in a gang result counts the peer tests that failed across all
pairs of members. Members that build one brief two ways disagree on what the brief
means, so a high count points at an ambiguous brief.

## Gate replay

`gates.py` reads the gate directories that a past round left behind. It reports the
wall time and the red runs of each gate leg:

```sh
tools/factory-bench/gates.py ~/.local/share/factory-bench/corpus
```
