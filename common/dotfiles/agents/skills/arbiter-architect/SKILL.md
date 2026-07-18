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

## The architect's charter (include ALL of it in the spawn brief)

1. The full `oracle-rounds` process contract, verbatim expectations: disjoint slices with
   file-ownership maps, self-contained implementer briefs, two differently-tasked grounded
   oracles per slice, REJECT → consolidated fix list → re-review by the rejecting oracle,
   merged-state re-verification (build/vet/race/bench/smoke), landing checklist.
2. The environment appendix from `oracle-rounds` (git identity, gh PTY, podman, HF cache,
   hermetic tests, bench conventions) — architects must not rediscover these by failure.
3. Constraints on the architect itself:
   - Writes NO feature code. May resolve merge conflicts and small cross-branch
     integration (mirrored wiring, callsite updates) — any such authorship is reported at
     the next checkpoint with diff scope and LOC.
   - Escalates immediately (not at the next checkpoint): destructive operations outside
     the workflow, rule conflicts, oracle deadlock (2+ rejects on the same blocker), any
     PRODUCT decision (semantics, defaults, user-taught surfaces — vs implementation detail),
     any mid-round scope change.
   - Subagent briefs are self-contained; its subagents see nothing else.

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
