---
name: arbiter-architect
description: Use when delegating an entire oracle-gated development round to a single architect subagent while acting as arbiter — approving scope, authorizing merges at checkpoints, and independently auditing the PR-ready result. No PR is opened without explicit user instruction. Trigger when the user asks to run a round through an architect, to arbitrate rather than orchestrate, or to scale to multiple concurrent rounds.
---

# Arbiter / Architect Rounds

A meta-topology over the `oracle-rounds` skill: one Architect subagent runs the whole
round (scope → worktrees → implementers → dual-oracle gates → merge → PR-ready report);
the arbiter (you) supervises at three mandatory checkpoints, holds merge authorization,
and audits the result independently. You are responsible for the architect's actions.
Neither of you opens the PR or touches main — the round ends with a PR-ready feature
branch, and the PR is opened only on explicit user instruction.

## When to use which topology

| Round character | Topology | Why |
|---|---|---|
| Mechanical, proven-process lanes: bug clusters, release plumbing, perf, robustness | Arbiter + architect | Process is codified; checkpoints catch slicing errors; arbiter context stays reserved for judgment |
| Design-heavy or taste-bearing: epics, product semantics (defaults, verb taxonomy, taught surfaces), evidence interpretation (audits) | Direct `oracle-rounds` | Value comes from reading raw oracle evidence and redirecting mid-flight; an architect either escalates constantly or decides alone |

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
| implementer-max | Oracle-tier — escalation only, never in the initial dispatch | Deployed on a no-progress REJECT loop after triage rules out a brief defect; faces the identical oracle gate |

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

The def binds the architect to: NO feature code (merge conflicts and small cross-branch
integration allowed, reported with diff scope and LOC); stop at PR-ready — no PR, no
main, no bead closing; immediate escalation for destructive operations, rule conflicts,
oracle deadlock (2+ no-progress rejects on the same blocker — escalation carries the
triage verdict per `oracle-rounds` step 6: thrash → brief defect, churn → dispatch
`implementer-max`; the arbiter rules on the remedy before re-dispatch), PRODUCT
decisions, and mid-round scope changes; self-contained subagent briefs. Audit against
exactly this list — it is what the architect was told.

## The three checkpoints (arbiter gates — proceeding without a reply is a violation)

**CP1 — plan approval, before any branch or dispatch.** Architect sends: slices, beads
per slice, file-ownership map, inter-slice contracts, oracle strategy. Arbiter audits:
- Disjointness is real (same file + same pipeline stage = one slice; "different lines" is
  not disjointness).
- Dependency chains folded correctly; no slice depends on another's unfinished output.
- Design directions defensible against project principles — redirect anything that
  creates silent data loss or doc-vs-binary drift.

**CP2 — merge authorization, when all oracles have returned.** Architect sends:
per-slice verdict lines quoted, fix-round history, `history://` links to the RAW oracle
transcripts (summaries are not evidence), and its integration plan. Arbiter audits:
- Every REJECT was re-approved by the rejecting oracle after its own re-probes — read
  that re-review transcript to its final `VERDICT:` line.
- Sample at least one raw transcript per slice; challenge evidence gaps (a scenario that
  baseline already passes demonstrates nothing — demand the discriminating test by name,
  proven failing against main).
- Rule on any reported deviation explicitly: accepted-with-rationale or bounced.
Authorization covers merging slices into the feature branch and integration — nothing
beyond.

**CP3 — PR-ready report.** Architect sends: feature branch + tip hash, merged-state
verification evidence, any self-authored integration diffs, cleanup done, and a draft
PR title + body. Arbiter then verifies INDEPENDENTLY — never accept the report alone:

```bash
git -C <repo> log --oneline <branch> -10   # slice merges present at the claimed tip
git -C <repo> status --short               # user's main checkout untouched
git -C <repo> worktree list                # slice worktrees removed
bd show <bead>                             # design + findings recorded; beads left open
```

The round is complete when your audit reconciles with the report point-for-point. Hand
the user the PR-ready branch and the draft PR text; the PR is opened only on their
instruction.

## Arbiter conduct

- Default to acting on evidence, not re-doing the work: your interventions belong at
  gates and escalations. If you find yourself dispatching implementers, you have silently
  reverted to direct mode — decide that explicitly instead.
- Record every deviation and its ruling in the round summary; self-reported deviations
  that survive oracle re-review are normally accepted (honesty is the load-bearing part).
- Known failure modes to watch: information loss (curated summaries hide process
  softness — hence raw transcripts at CP2), late failure detection (outcome audits catch
  botched rounds only after the fact — hence hard gates at plan, merge, and report), and
  contract drift one level down (hence deviation reporting as a standing obligation).
- The architect's report must reconcile with your own audit point-for-point before you
  declare the round complete.
