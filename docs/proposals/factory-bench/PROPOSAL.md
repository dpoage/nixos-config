# Proposal: a benchmark for changes to oracle-rounds

`tools/factory-bench` runs one slice brief under two or more process arms and scores
each result with checks the workers never see. It exists to answer one question before
a change reaches the skills: does the change shorten a round without lowering what the
review seats find?

Status: the runner, three fixture tasks, six arms and a gate replay are built. Three
real-slice tasks are curated and have not run. Bead: `nc-kif`.

## Why rounds are slow: what the fx records show

The records of rounds fx-r1 to fx-r4 (repository `the_cloud`) are the only corpus on
this machine. A snapshot is at `~/.local/share/factory-bench/corpus`. The snapshot of
fx-r4 was taken while that round was still running.

**The round is a chain of review turns.** fx-r3 ran from 11-20 18:59 to 11-21 14:17,
about 19.3 hours (`fx-r3/cp3.md:135-161`). The plan was approved after 39 minutes. The
first verdicts of S4, S5 and S6 came at 23:31, 03:13 and 08:16. Each fix round took 22
to 138 minutes.

**The broad gate leg costs most of the test time and has attributed no red to a
round.** The gate has a slice leg (the package under change) and a consumer leg (every
dependent test target). `gates.py` reports:

| Round | Gate runs | Runs with a consumer leg | Slice leg hours | Consumer leg hours | Consumer share | Consumer legs red |
|---|---|---|---|---|---|---|
| fx-r3 | 32 | 16 | 3.1 | 8.8 | 74% | 16 of 16 |
| fx-r4 | 19 | 11 | 1.9 | 6.0 | 76% | 11 of 11 |

The median consumer leg takes 32 minutes; the median slice leg takes 6. Every consumer
leg was red. The fx-r3 report says of those reds: "None is attributable to the round"
(`fx-r3/cp3.md:86`). The fx-r4 log gives host load as the cause of several: "gate load
spiked to 45 from concurrent legs" (`fx-r4/handoff.md:81`). Each red also cost
re-runs on base and tip to dispose of it.

**Prose-only rejections are 10 of 24.** A count by hand of the seat REJECT lines:
5 of 9 in fx-r3 (`cp3-verdicts-full.txt`) and 5 of 15 in fx-r4 (`handoff.md`) carry
prose blockers only. Since fx-r2 a prose-only REJECT starts no fix round, but it still
costs a ruling, a polish item and a doc-truth probe. The fx-r3 polish pass took two
doc-truth fix rounds.

**The brief causes much of the rework.** Both retros and the fx lessons name undefined
terms, list-shaped criteria and unmeasured premises (`docs/retro-2026-10-11-sar-p1-epic.md`
lesson 5; `docs/proposals/fx-r1-lessons/PROPOSAL.md` items 14 and 17).

**The cheap tiers are not running.** On 2026-11-22 `zai/glm-5.3` returned "Weekly/Monthly
Limit Exhausted", with a reset at 2026-11-27 05:43. `IMPLEMENTER` therefore runs on its
fallback, `anthropic/claude-sonnet-5-5`, and `AUGUR` runs on `anthropic/claude-opus-5-5`.
`minimax-code` returned "insufficient balance", and `SWEEP` has no fallback.

## What the benchmark tests

| Question | Arm | What the arm changes |
|---|---|---|
| Baseline | `solo` | Nothing |
| Does a per-turn advisor remove blockers before review? | `advisor-turn` | An advisor reviews every implementer turn |
| Is one review at the end enough? | `advisor-end` | The same advisor reviews when the implementer tries to finish |
| Does the advisor need a stronger model than the implementer? | `peer-advisor-turn`, `peer-advisor-end` | The advisor runs on the implementer's model: a concurrent reviewer of the same tier |
| Do several implementers on one brief beat one? | `gang3` | Three build the brief; the runner keeps the one that passes most of the union of their tests |
| Does cross-testing help the gang converge? | `gang3-cross` | Each member revises once against the peer tests that its code fails |
| Does a gang that cooperates beat a gang that competes? | `gang3-coop` | Three build the brief together in one tree: they agree a plan by message, review each other's parts and deliver one commit |
| Does a deeper tree help? | `split` | A lead splits the slice and dispatches one implementer per sub-slice |

An arm is a directory: a driver prompt, a config overlay, and files for `.omp/`. A
changed agent def or a changed skill is tested the same way, as a new arm.

Three properties keep the expensive tiers out of the measurement loop:

- **No judge selects.** A gang member is kept by a count of passing tests.
- **Hidden checks score.** A fixture task has hidden `unittest` modules. A real-slice
  task has the blockers that seats found on the first historical build, and one
  `oracle` agent probes them on the new build.
- **Spend is split by layer.** Each result reports driver, worker and advisor spend,
  and spend per model.

The advisor arms differ from the pre-screen agent that the sar epic dropped. The
pre-screen was one more agent turn after the implementer replied. An advisor runs
inside the implementer's session, sends notes while the work is in progress, and gives
no verdict.

The end-of-work advisor needs `syncBacklog: strict` in `WATCHDOG.yml`. Without it the
final review races the implementer's exit and delivers no note: a first run of
`advisor-end` spent nothing on the advisor and scored the same as `solo`. The runner
now voids an advisor run whose advisor layer has no spend.

A gang also measures the brief. `divergence_before` counts the peer tests that fail
across all pairs of members. Members that read one brief two ways disagree in their
tests, so the count points at an ambiguous brief before a seat sees the slice.

## Limits

- **Fixture tasks are small.** One implementer on `claude-sonnet-5-5` passed
  `toy-intervals` 30 of 30 in 165 seconds for $0.59, and `claude-haiku-4-5` passed it
  30 of 30 twice. The fixtures separate arms only with a weaker implementer model, and
  only `toy-ratelimit` (32 hidden tests) and `toy-ledger` (57) leave room below the
  ceiling.
- **Hidden tests do not carry over to a real slice.** A real brief lets the implementer
  choose names, so the score of a real-slice task is a replay of one to three known
  blockers per slice. A full fresh seat is the better score and costs a seat.
- **The corpus is one repository and four rounds.** No transcript from another system
  that uses these skills is available.
- **Nothing here measures a whole round.** Fan-out across slices, wave order and the
  composition gate need a round-level task. The gate replay and the fx timeline are the
  only evidence on those today.
- **A real-slice run needs a quiet host.** Each member builds with Bazel. On
  2026-11-22 fx-r4 was running, so `fx-r4-s0`, `fx-r4-s3` and `fx-r4-s4` have not run.
- **A provider limit voids runs.** Thirteen cells in parallel reached the account's
  monthly spend limit (HTTP 429) after a few minutes. The runner voids a run whose
  transcript ends on a provider error.

## First results

Both fixture tasks, implementer on `claude-haiku-4-5`, 2026-11-22. A score is the
number of hidden tests that pass. Each cell was planned at five runs. A cell has fewer
where runs were void.

| Arm | `toy-ratelimit` runs | Mean of 32 | `toy-ledger` runs | Mean of 57 | Lowest | Ledger cost $ | Ledger wall min |
|---|---|---|---|---|---|---|---|
| `solo` | 5 | 30.0 | 6 | 53.5 | 51 | 0.70 | 7.0 |
| `advisor-turn` (opus advisor) | 3 | 32.0 | 4 | 56.5 | 56 | 2.38 | 12.7 |
| `advisor-end` (opus advisor) | 4 | 32.0 | 3 | 55.0 | 53 | 1.59 | 11.6 |
| `peer-advisor-turn` (haiku advisor) | 5 | 32.0 | 5 | 51.4 | 41 | 1.77 | 14.1 |
| `peer-advisor-end` (haiku advisor) | 3 | 32.0 | 5 | 52.6 | 49 | 0.89 | 8.4 |
| `gang3` | 3 | 30.7 | 4 | 54.2 | 54 | 2.12 | 8.5 |
| `gang3-cross` | 2 | 31.0 | 2 | 55.0 | 55 | 3.47 | 15.3 |
| `gang3-coop` | 2 | 32.0 | 2 | 55.5 | 55 | 3.43 | 9.3 |
| `split` (opus lead) | 5 | 32.0 | 6 | 55.8 | 53 | 2.81 | 10.5 |

What the runs show:

- **`solo` fails the same two tests on `toy-ratelimit` in five of five runs.** Both
  tests require an error message to name the environment variable. This is the kind of
  blocker that a seat reports in prose.
- **Any advisor closes that gap, and the tier of the advisor does not matter there.**
  All fifteen advisor runs on `toy-ratelimit` passed 32 of 32. The haiku advisor at the
  end of the work did so for $0.46 a run against $0.59 for `solo`.
- **On the harder task a same-tier advisor does not help.** Both haiku-advisor arms
  score at or below `solo` on `toy-ledger`, and one run fell to 41. Only the opus
  advisor on every turn lifts the score, at 3.4 times the cost of `solo`.
- **A gang that competes does not beat one implementer.** `gang3` costs three times
  `solo` and scores within its range on both tasks.
- **A gang that cooperates has too few runs to judge.** Its four runs score at or above
  every `gang3` run, at about five times the cost of `solo` on `toy-ledger`. In one
  observed run the three members exchanged 35 messages, and one member broke the rule
  that a single member commits.
- **`split` scores well, and the cause is not separated.** Its lead runs on opus and
  rewrites the brief into sub-briefs. The gain may come from that reading and not from
  the depth of the tree.

Limits of these results:

- Counts are two to six runs per cell. Differences of one or two tests on `toy-ledger`
  are inside the spread of `solo`.
- 97 of 168 runs were void. The causes were the account's spend limit, reached three
  times, and a driver that started a second agent after its reply. The driver fault is
  fixed. No run with the fix has completed.
- The arms were measured with one implementer model on two small tasks. No real slice
  has run.

## Saturation and next steps (2026-11-24)

**The fixtures are saturated.** `deepseek/deepseek-flash` scores 57 of 57 on `toy-ledger`
in every arm (1 to 2 runs per arm, $0.07 to $0.16 a run). It scores 116 of 116 on
`toy-pool` in 3 of 3 `solo` runs, at $0.06 a run. When every arm sits at the ceiling,
the runs say nothing about the process. Harder fixtures would not fix this: the fx
records place the cost of a round in briefs, premises, prose-only REJECTs and fix
loops, not in coding ability.

**An AUGUR substitution needs a fix-round task.** `AUGUR` is the model of
`implementer-max`, the agent that runs fix rounds after an oracle REJECT. It is not a
review seat. Replacing it with a cheaper fixer, such as a `gang3` on deepseek-flash,
moves cost into the oracle re-reviews and gates of every extra iteration. The comparison
is therefore the cost of the whole loop to APPROVE or the loop cap: fixer, re-review
and gate spend together. The `gang3` selector, which counts the members' own tests, cannot
see the oracle's blockers. For a fix round the selector is the replay-seat probe of the
original blockers.

### Next steps, in priority order

1. **Commit and stabilise.** Commit `tools/factory-bench` and this proposal. Record in
   `result.json` the omp version, the model IDs and a hash of each skill and agent def.
   Run the bench on a separate spend quota: 97 of 168 runs were void, and fx-r4 shares
   the account.
2. **Fix-round task kind (the AUGUR eval).** Mine each REJECT in fx-r2 to fx-r4 as a task:
   the branch at the REJECT hash, the verdict history and the brief. Arms: opus,
   glm-5.3, deepseek-flash `solo`, deepseek-flash `gang3`, and a cascade that escalates
   to a stronger fixer on a second REJECT. Score with the replay seat on the original
   blockers, plus one fresh seat for blockers the fix introduced (diff-hunk
   intersection, as in the loop cap). Report cost per APPROVE.
3. **Seeded-defect review tasks** for ORACLE, SWEEP and reviewer seats. Inject mutants,
   deleted guards and false doc claims into real fx diffs, drawn from the bug families
   that seats found. Score recall and false-alarm rate. The difficulty is set by the
   mutant, so this does not saturate, and it tests the seat whose failure is silent.
4. **Real-slice runs.** Run `fx-r4-s0`, `fx-r4-s3` and `fx-r4-s4` on a quiet host.
5. **Skill-level evals for the other skills.** Three layers, cheapest first: trigger
   (the skill description loads the skill for matching prompts and not for others),
   compliance (the transcript follows its rules), outcome (score with and without the
   skill).
6. **Round-level arms.** Deferred until steps 2 to 4 pick candidates.

### Reporting rules

- Report pass^k (every one of k runs passes) and cost per full pass next to the mean,
  and the cheapest arm that is not worse than another on both score and cost.
- Run paired comparisons: the same tasks and reps in every arm. Bootstrap the paired
  difference, and write down the decision rule before spending. With five runs, a pass
  rate is uncertain by about ±40 points.
- When the cheapest arm passes pass^5, the task moves to a regression set. Keep a
  held-out set that no skill edit was tuned against.
- Check the bench against the outcome ledger. An arm that wins here and does not lower
  `escaped-from:` defects shows that the proxy is wrong.
