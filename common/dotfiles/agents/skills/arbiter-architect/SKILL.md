---
name: arbiter-architect
description: Use when a session will drive an epic of many oracle-gated development rounds. Each round goes to an architect subagent that holds all its detail (briefs, oracle transcripts, fix loops, diffs), so the session keeps only scope, rulings, and checkpoint summaries and lasts across the whole epic. The session acts as arbiter — approving scope, authorizing merges at checkpoints, and independently auditing each PR-ready result. No PR is opened without explicit user instruction. Trigger when the user asks to work through an epic, drive all of these issues, run a round through an architect, arbitrate rather than orchestrate, or run multiple concurrent rounds; also when a direct session heads into another round with its context already heavy.
---

# Arbiter / Architect Rounds

An architect subagent runs each whole round under `skill://oracle-rounds`. You are the
arbiter. You approve the plan at CP1, authorize merges at CP2, and audit the PR-ready
result at CP3. You are responsible for the architect's actions. Neither of you opens the
PR or touches main. The PR is opened only on the user's explicit instruction.

The `oracle-rounds` rules (R1–R9 in its `SKILL.md`) bind the architect and you. This
file adds only what the arbiter does.

## Why the architect exists

One round leaves hundreds of thousands of tokens of detail: map drafts, briefs, oracle
transcripts, fix lists, diffs. One round fits in a session; five rounds do not. The
architect holds a round's detail and drops it when the round ends. You keep only what
must last across rounds: the user's intent, scope, rulings, and the outcome ledger.

## When to use which topology

| Round character | Topology | Reason |
|---|---|---|
| An epic of several rounds in lanes with a proven process: bug clusters, release plumbing, performance, robustness | Arbiter + architect | Each round's detail stays with its architect, so the session survives the epic |
| A single round, or work that needs design judgment and taste: product semantics, defaults, surfaces users learn, audit interpretation | Direct `oracle-rounds` | A second orchestration layer adds nothing to one round. Taste comes from reading raw oracle evidence and redirecting mid-flight |

Every layer is a handoff that loses context. Your review of oracle evidence is a third
look by the same model family at the same probes. You earn your place by ruling on
scope, necessity, product questions, and tiers, not by re-deriving what the oracles ran.

If a direct session heads into another round with its context already heavy, hand the
remaining rounds to an architect. Put the rulings and scope that carry over in the first
spawn brief.

Run several architects at once only on fully disjoint lanes: different subsystems,
different beads, no shared files.

## Spawning the architect

Spawn with `agent: "architect"`. The managed def (`~/.omp/agent/agents/architect.md`)
carries the charter, the checkpoint contents, and the escalation rules, and it autoloads
`oracle-rounds`. If the def is missing, restore it from nixos-config. NEVER substitute a
generic `task` worker.

The spawn brief adds only the round:

1. Bead IDs and scope; lane boundaries if other architects run concurrently.
2. Round-specific constraints and design directions.
3. The checkpoint protocol: report over hub and BLOCK for your reply at CP1, CP2, and
   CP3.

The def's escalation list is what you answer between checkpoints: destructive
operations, rule conflicts, a loop-cap triage (you rule the remedy before re-dispatch),
every `SCOPE:` item, product decisions, and mid-round scope changes. The def also limits
the architect to merge-conflict resolution and small integration glue. Audit against
exactly the def; it is what the architect was told.

Model strength per role is in the `oracle-rounds` procedure (Capability allocation). You
are the strongest model in the room, because no gate sits above you.

## Checkpoints

The architect def lists what the architect sends at each checkpoint. This section lists
what you audit. Proceeding past a checkpoint without your reply is a violation.

### CP1: plan approval, before any branch or dispatch

- **Premortem.** It ran at the size the round's highest tier names. Open its matrix: rows
  are executed probes with the isolation stated, not family names. Every PLAN-BLOCKING
  item has a ruling: the plan was revised, or a probe shows the item does not hold.
- **Tiers.** Each slice's tier matches its file-ownership map by path and state. Bounce a
  slice that touches persistent state, auth, money, activation, or an irreversible step
  and is filed below Heavy. Bounce a Docs slice that owns any non-prose file.
- **Slicing (R3).** Slices follow the module map, not the bead list. Disjointness holds
  by file and pipeline stage, and a disjointness failure was fixed in the map. Shared
  substrate is wave 0. Every seam has one owning slice and a contract record. No slice
  depends on another slice's unfinished output within a wave. For each slice, name the
  change kind of each property and check the procedure's step 3 split and caps.
- **Necessity (R2).** For every mechanism the plan adds, the architect can say what
  breaks without it. Bounce a plan that hardens a path with no shipped consumer, or
  that accommodates B when nobody priced a change to A. Discovered work is a new bead,
  never a bigger slice.
- **Criteria (R4).** Apply the falsifier to each criterion. A criterion shaped like a list
  of sites approves the fix rounds that follow it.
- **Design directions.** Redirect any direction that creates silent data loss or drift
  between docs and the binary.

### CP2: merge authorization, when every slice oracle has returned

CP2 is a ledger check, not a re-review. Re-reading oracle transcripts adds a correlated
look, not evidence.

- Every slice to merge holds an APPROVE from each seat its tier names, bound to its merge
  hash, with a `Coverage:` line, a matrix file, and the seat's resolved model.
- Every REJECT ends in an APPROVE from the same seat.
- Every `SCOPE:` item has a recorded ruling. Every slice with two consecutive REJECTs
  from one seat has a recorded triage class and ruling.
- Every contract revision was re-issued to both sides.
- Every reported deviation has your explicit ruling: accepted with a rationale, or
  bounced.
- **Sample one slice per round, chosen at random.** Open its matrices and its raw
  transcript. Rows are executed probes with observed results. The motivating scenario
  fails on base. Each new test's legs are raw transcripts. A failed sample bounces that
  slice for a re-probe and opens a second sample.

Authorization covers merging slices into the feature branch, integration glue, and the
composition oracle with any integration fix round it triggers. It covers nothing else.

### CP3: PR-ready report

Verify independently. Never accept the report alone:

```bash
git -C <repo> log --oneline <branch> -10   # slice merges present at the claimed tip
git -C <repo> diff -U0 <pre-polish>..<tip>  # every hunk is comment or prose only
git -C <repo> status --short               # user's main checkout untouched
git -C <repo> worktree list                # slice worktrees removed
bd show <bead>                             # design and findings recorded; beads open
```

- A code hunk in the polish diff bounces CP3. The architect reverts it and, if the change
  is needed, routes it through the slice's rejecting oracle as a fix round.
- A missing composition verdict bounces CP3. "Each slice was reviewed" is not evidence
  about the composition, and nobody has reviewed the architect's glue.

The round is complete when your audit reconciles with the report point for point. Hand
the user the PR-ready branch and the draft PR text.

## Arbiter conduct

- Act at rulings, gates, and escalations. If you dispatch implementers or re-run probes
  an oracle already ran, you have reverted to direct mode. Decide that explicitly.
- While the architect runs, do not read worktrees, diffs, or transcripts. Per round, read
  the three checkpoint summaries, one CP2 sample, and the CP3 command output. If a ruling
  needs more, ask the architect over the hub.
- Record every deviation and its ruling in the round summary. Normally accept a
  self-reported deviation that survives oracle re-review.
- Keep the epic's handoff file (`skill://handoff`). List each running architect and the
  path of its round's handoff file under Agents. After an interruption, run the resume
  protocol before you message any architect.
- Your rulings are claims (R5). "The other gate already covers that class" is a
  hypothesis: probe it, or state it as unprobed.
- Watch three failure modes. Curated summaries hide process softness; the CP2 sample
  counters that. Failures surface late; the checkpoints and the outcome ledger counter
  that. Contracts drift one level down; standing deviation reports counter that.
