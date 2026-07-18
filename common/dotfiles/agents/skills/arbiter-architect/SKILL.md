---
name: arbiter-architect
description: Use when delegating an entire oracle-gated development round to a single architect subagent while acting as arbiter — approving scope, authorizing merges at checkpoints, and independently auditing the landing. Trigger when the user asks to run a round through an architect, to arbitrate rather than orchestrate, or to scale to multiple concurrent rounds.
---

# Arbiter / Architect Rounds

A meta-topology over the `oracle-rounds` skill: one Architect subagent runs the whole
round (scope → worktrees → implementers → dual-oracle gates → merge → PR → land); the
arbiter (you) supervises at three mandatory checkpoints, holds merge authorization, and
audits the landing independently. You are responsible for the architect's actions.

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
| Arbiter | Strongest in the room (by construction — no gate above it) | The backstop; audits evidence, holds irreversible authorizations |
| Architect | Strong — its leverage is oracle-brief quality and honest synthesis | Its failures (bad slicing, soft briefs, drift) are VISIBLE at checkpoints; the gate structure is its safety net |
| Implementers | Mid-tier; detailed self-contained briefs substitute for strength | Their errors are what oracles exist to catch; too weak just churns fix rounds |

The architect def pins this ordering into its charter; keep it that way — the tempting
default (strongest model architects, cheaper models review) is exactly backwards: it
optimizes the visible failure mode and starves the invisible one.

## Spawning the architect

Spawn with `agent: "architect"` — a managed definition (`~/.omp/agent/agents/architect.md`,
model `@ARCHITECT`) that carries the charter, the escalation rules, and autoloads
`oracle-rounds` (process contract + environment appendix). If it is missing, restore it
from nixos-config; NEVER substitute a generic `task` worker.

The spawn brief adds only the round itself:

1. Bead IDs and scope; lane boundaries if other architects run concurrently.
2. Round-specific constraints and design directions.
3. The checkpoint protocol: report over hub and BLOCK for your reply at CP1/CP2/CP3.

The def binds the architect to: NO feature code (merge conflicts and small cross-branch
integration allowed, reported at the next checkpoint with diff scope and LOC); immediate
escalation for destructive operations, rule conflicts, oracle deadlock (2+ rejects on
the same blocker), PRODUCT decisions, and mid-round scope changes; self-contained
subagent briefs. Audit against exactly this list — it is what the architect was told.

## The three checkpoints (arbiter gates — proceeding without a reply is a violation)

**CP1 — plan approval, before any branch or dispatch.** Architect sends: slices, beads
per slice, file-ownership map, inter-slice contracts, oracle strategy. Arbiter audits:
- Disjointness is real (same file + same pipeline stage = one slice; "different lines" is
  not disjointness).
- Dependency chains folded correctly; no slice depends on another's unfinished output.
- Design directions defensible against project principles — redirect anything that
  creates backend divergence, silent data loss, or doc-vs-binary drift.

**CP2 — merge authorization, before the PR.** Architect sends: per-slice verdict lines
quoted, fix-round history, merged-state verification evidence, `history://` links to the
RAW oracle transcripts (summaries are not evidence), and any self-authored integration
diffs. Arbiter audits:
- Every REJECT was re-approved by the rejecting oracle after its own re-probes.
- Sample at least one raw transcript per slice; challenge evidence gaps (a scenario that
  baseline already passes demonstrates nothing — demand the discriminating test by name,
  proven failing against main).
- Rule on any reported deviation explicitly: accepted-with-rationale or bounced.
Authorization covers: open PR, watch CI, admin-squash ONLY on fully green CI.

**CP3 — landing report.** Architect sends: merge commit, main state, beads closed with
reasons, dolt pushed, cleanup done. Arbiter then verifies INDEPENDENTLY — never accept
the report alone:

```bash
git -C <repo> log --oneline -1            # merge commit on main
git -C <repo> status --short --branch      # up to date with origin, user files untouched
git -C <repo> worktree list                # only the main checkout remains
gh pr view <N> --json state,mergeCommit    # MERGED at the claimed SHA (needs PTY)
bd list --status open | grep <round beads> # zero still open
bd show <headline bead>                    # close reason cites PR + decision
```

## Arbiter conduct

- Default to acting on evidence, not re-doing the work: your interventions belong at
  gates and escalations. If you find yourself dispatching implementers, you have silently
  reverted to direct mode — decide that explicitly instead.
- Record every deviation and its ruling in the round summary; self-reported deviations
  that survive oracle re-review are normally accepted (honesty is the load-bearing part).
- Known failure modes to watch: information loss (curated summaries hide process
  softness — hence raw transcripts at CP2), late failure detection (outcome audits catch
  botched rounds only after the fact — hence hard gates before irreversible steps), and
  contract drift one level down (hence deviation reporting as a standing obligation).
- The architect's job result must reconcile with your own audit point-for-point before
  you report the round closed.
