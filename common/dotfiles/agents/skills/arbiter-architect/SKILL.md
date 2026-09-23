---
name: arbiter-architect
description: Use when a session will drive an epic of many oracle-gated development rounds. Each round goes to an architect subagent that holds all its detail (briefs, oracle transcripts, fix loops, diffs), so the session keeps only scope, rulings, and checkpoint summaries and lasts across the whole epic. The session acts as arbiter — approving scope, authorizing merges at checkpoints, and independently auditing each PR-ready result. No PR is opened without explicit user instruction. Trigger when the user asks to work through an epic, drive all of these issues, run a round through an architect, arbitrate rather than orchestrate, or run multiple concurrent rounds; also when a direct session heads into another round with its context already heavy.
---

# Arbiter / Architect Rounds

A meta-topology over the `oracle-rounds` skill: one Architect subagent runs the whole
round (module map → slices → worktrees → implementers → dual-oracle gates → merge →
composition oracle → polish → PR-ready report); the arbiter (you) supervises at three
mandatory checkpoints, holds merge authorization, and audits the result independently.
You are responsible for the architect's actions.
Neither of you opens the PR or touches main — the round ends with a PR-ready feature
branch, and the PR is opened only on explicit user instruction.

## Why the architect exists

Each round leaves hundreds of thousands of tokens of detail behind: module-map drafts,
implementer briefs, oracle transcripts and matrices, fix lists, diffs, merge conflicts.
One round fits in a session; five do not, and by round three the session has lost the
user's intent and your earlier rulings under old transcripts. The architect holds each
round's detail and drops it when the round ends; you keep only what has to last across
rounds: intent, scope, rulings, and the outcome ledger. Your context is what this
topology protects.

## When to use which topology

| Round character | Topology | Why |
|---|---|---|
| An epic of several rounds in proven-process lanes: bug clusters, release plumbing, perf, robustness | Arbiter + architect | Each round's detail stays with its architect, so the session survives the epic; checkpoints catch slicing errors; judgment stays with the arbiter |
| A single round, or design-heavy and taste-bearing work: product semantics (defaults, verb taxonomy, taught surfaces), evidence interpretation (audits) | Direct `oracle-rounds` | One round gains nothing from a second orchestration layer; taste-bearing value comes from reading raw oracle evidence and redirecting mid-flight |

Every layer is a handoff that loses context, and the arbiter's review of oracle evidence
is a third look by the same model family at the same probes. The arbiter earns its
place by ruling — scope, necessity, product questions, tiers — not by re-deriving what
the oracles executed.

**Switching mid-epic.** A session that started direct and is heading into another round
with its context already heavy hands the remaining rounds to an architect. Record the
rulings and scope that must carry over in the first spawn brief; do not start another
round directly.

Multiple architects may run concurrently only on fully disjoint lanes (different
subsystems, different beads, no shared files).

## Capability allocation across the hierarchy

Rank by **cost of silent failure** — spend model strength where failure is invisible:

| Role | Strength | Rationale |
|---|---|---|
| Oracles | Strongest available — never weaker than the architect | False APPROVE is silent; the gate IS the quality system. Long time budgets are cheap relative to a shipped defect |
| Arbiter | Strongest in the room (by construction — no gate above it) | The backstop; audits evidence, holds merge authorization and final acceptance |
| Architect | Strong — its leverage is oracle-brief quality and honest synthesis | Its failures (bad slicing, soft briefs, drift) are VISIBLE at checkpoints; the gate structure is its safety net |
| Implementers | Mid-tier; detailed self-contained briefs substitute for strength | Their errors are what oracles exist to catch; too weak just churns fix rounds |
| implementer-max | `@AUGUR`: oracle-class, different model family from `@ORACLE` — every fix round, and the escalation; never the initial dispatch | Fix rounds are where collateral edits and false claims concentrate; a fixer from the reviewer's family shares its blind spots and draws its self-preference |

The architect def pins this ordering into its charter; keep it that way — the tempting
default (strongest model architects, cheaper models review) is exactly backwards: it
optimizes the visible failure mode and starves the invisible one.

## Spawning the architect

Spawn with `agent: "architect"` — a managed definition (`~/.omp/agent/agents/architect.md`,
model `@ARCHITECT`) that carries the charter, the escalation rules, and autoloads
`oracle-rounds` (the process contract). If it is missing, restore it from nixos-config;
NEVER substitute a generic `task` worker.

The spawn brief adds only the round itself:

1. Bead IDs and scope; lane boundaries if other architects run concurrently.
2. Round-specific constraints and design directions.
3. The checkpoint protocol: report over hub and BLOCK for your reply at CP1/CP2/CP3.

The def binds the architect to the full `oracle-rounds` contract (autoloaded) plus:
the three checkpoints; immediate escalation for destructive operations, rule
conflicts, oracle deadlock (with its step 7 triage verdict — the arbiter rules on the
remedy before re-dispatch), PRODUCT decisions, and mid-round scope changes; NO feature
code beyond merge conflicts and small integration glue, reported with scope + LOC and
gated by the composition oracle. Audit against exactly this — it is what the architect
was told.

## The three checkpoints (arbiter gates — proceeding without a reply is a violation)

**CP1 — plan approval, before any branch or dispatch.** Architect sends: the module
map (what exists after the round, what each module hides, which beads land where),
slices, beads per slice, file-ownership map, waves, inter-slice contracts with the
rejected alternative for each, oracle strategy, and the premortem report with a ruling
per PLAN-BLOCKING item — or the triggers it checked and why none holds. Arbiter audits:
- The premortem ran if any `skill://premortem` trigger holds. Open its matrix: rows are
  executed probes with isolation stated, not family names. Every PLAN-BLOCKING item
  carries a ruling — plan revised, or a probe showing it does not hold. An unruled item
  or a thin matrix bounces CP1.
- Every slice carries a tier (`oracle-rounds` Oracle tasking) whose trigger matches its
  file-ownership map by path and state. A slice touching persistent state, auth, money,
  activation, or an irreversible step filed below Heavy bounces CP1.
- The slicing is the module map, not the bead list: one slice per module (or coherent
  set with one owner); slice count ≤ modules the map says should exist. A round sliced
  one-per-bead with no map is bounced — that is architecture by ticket.
- Disjointness is real (same file + same pipeline stage = one slice; "different lines" is
  not disjointness) — and a disjointness failure was fixed by changing the map, not by
  splitting a file between slices.
- Shared substrate is wave 0, not a prose contract. Every remaining seam has ONE owning
  slice and an `interface-contract` record naming the alternative it rejected.
- Dependency chains folded correctly; no slice depends on another's unfinished output
  within a wave.
- Design directions defensible against project principles — redirect anything that
  creates silent data loss or doc-vs-binary drift.
- Necessity was ruled before quality: for every mechanism the plan adds, the architect
  can say what breaks if it does not exist. A plan that hardens a path with no shipped
  consumer, or that accommodates B when changing A was never priced, is bounced.
- Scope is the bead list. Work discovered during scoping becomes a new bead, never a
  bigger slice; the architect states the round's bead set and what it excludes.
- Acceptance criteria are properties with their mutants, not checklists of sites (the
  `oracle-rounds` brief contract). Apply the falsifier to each: if an implementer closed
  exactly the cited lines and nothing else, could the property still be violated? Then
  it is list-shaped, and you are approving the fix rounds that follow.

**CP2 — merge authorization, when all slice oracles have returned.** Architect sends:
per-slice verdict lines quoted with each oracle's `Coverage:` line, fix-round history,
every seam-contract revision made mid-round (who escalated, what changed, which slices
were re-issued), `history://` links to the RAW oracle transcripts, and its integration
plan. CP2 is a ledger check, not a re-review: the oracles executed the probes, and your
re-reading them adds a correlated look, not evidence. Arbiter audits:
- Every slice to be merged holds an APPROVE from each seat its tier names, bound to its
  merge hash (carried because the paired fix diff missed that seat's matrix files, or
  re-probed), each with a `Coverage:` line, a matrix file, and the seat's resolved
  model.
- Every REJECT ends in an APPROVE from the same seat: its re-review transcript's final
  line is `VERDICT: APPROVE`.
- Every `SCOPE:` item carries a recorded ruling; every slice with 2 consecutive REJECTs
  from one seat has a recorded triage class and ruling before its next fix round.
- Every contract revision was re-issued to BOTH sides.
- Every reported deviation has your explicit ruling: accepted-with-rationale or bounced.
- One sample per round, slice chosen at random: open its matrices and its raw
  transcript. Rows must be executed probes with observed results, not family names; the
  motivating scenario must fail on base; each new test's legs are raw transcripts. A
  failed sample bounces that slice for re-probe and opens a second sample.
Authorization covers merging slices into the feature branch, integration glue, and the
composition oracle + any integration fix round it triggers — nothing beyond.

**CP3 — PR-ready report.** Architect sends: feature branch + tip hash, merged-state
verification evidence, any self-authored integration diffs, the composition oracle's
verdict line quoted with its `history://` link and any integration fix rounds it
triggered, where the landed branch deviates from the CP1 module map, the polish
evidence (pre-polish hash, `comment-compactor` gate result per file, docs `doc-writer`
revised and the commands re-run), gate result on the polished tip, cleanup done, and a
draft PR title + body. Arbiter then verifies INDEPENDENTLY — never accept the report
alone:

```bash
git -C <repo> log --oneline <branch> -10   # slice merges present at the claimed tip
git -C <repo> diff -U0 <pre-polish>..<tip>  # every hunk is comment/prose only; no code
git -C <repo> status --short               # user's main checkout untouched
git -C <repo> worktree list                # slice worktrees removed
bd show <bead>                             # design + findings recorded; beads left open
```

A code hunk in the polish diff bounces CP3: the architect reverts it and, if the change
was needed, routes it through the slice's rejecting oracle as a fix round. A missing
composition verdict bounces CP3 outright — "each slice was reviewed" is not evidence
about the composition, and the architect's own glue has been reviewed by nobody.

The round is complete when your audit reconciles with the report point-for-point. Hand
the user the PR-ready branch and the draft PR text; the PR is opened only on their
instruction.

## Arbiter conduct

- Default to acting on evidence, not re-doing the work: your interventions belong at
  rulings, gates, and escalations. If you find yourself dispatching implementers or
  re-running probes an oracle already ran, you have silently reverted to direct mode —
  decide that explicitly instead.
- Context discipline: while the architect runs, do not read worktrees, diffs, or
  transcripts. Wait on the hub; answer escalations with rulings. Per round you read the
  three checkpoint summaries, one CP2 sample, and the CP3 command block. When a ruling
  needs more, ask the architect over the hub rather than pulling raw material in.
- Record every deviation and its ruling in the round summary; self-reported deviations
  that survive oracle re-review are normally accepted (honesty is the load-bearing part).
- Your rulings are claims. Declining to act ("the other gate already covers that class")
  is a testable hypothesis: probe it, or state it as unprobed. The evidence rule that
  binds implementers binds hardest at the top, where no gate sits above it.
- Known failure modes to watch: information loss (curated summaries hide process
  softness — hence the CP2 random sample of raw transcripts), late failure detection
  (hence hard gates at plan, merge, and report, and the `oracle-rounds` outcome ledger),
  and contract drift one level down (hence deviation reporting as a standing
  obligation).
- The architect's report must reconcile with your own audit point-for-point before you
  declare the round complete.
