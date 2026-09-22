---
name: arbiter-architect
description: Use when delegating an entire oracle-gated development round to a single architect subagent while acting as arbiter — approving scope, authorizing merges at checkpoints, and independently auditing the PR-ready result. No PR is opened without explicit user instruction. Trigger when the user asks to run a round through an architect, to arbitrate rather than orchestrate, or to scale to multiple concurrent rounds.
---

# Arbiter / Architect Rounds

A meta-topology over the `oracle-rounds` skill: one Architect subagent runs the whole
round (module map → slices → worktrees → implementers → dual-oracle gates → merge →
composition oracle → polish → PR-ready report); the arbiter (you) supervises at three
mandatory checkpoints, holds merge authorization, and audits the result independently.
You are responsible for the architect's actions.
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
| implementer-max | Oracle-tier — every fix round, and the escalation; never the initial dispatch | Fix rounds are where collateral edits and false claims concentrate; faces the identical oracle gate |

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
were re-issued), `history://` links to the RAW oracle transcripts (summaries are not
evidence), and its integration plan. Arbiter audits:
- Every APPROVE has a coverage line and a probe matrix behind it (`local://oracle-*`).
  Open at least one matrix per slice: rows are executed probes with observed results,
  not family names; an APPROVE whose matrix is thin for the slice's unit shape (an
  adapter with no sibling rows, a guard with no input matrix) is bounced for re-probe.
- Every REJECT was re-approved by the rejecting oracle after its own re-probes — read
  that re-review transcript to its final `VERDICT:` line.
- Sample at least one raw transcript per slice; challenge evidence gaps (a scenario that
  baseline already passes demonstrates nothing — demand the discriminating test by name,
  proven failing against main).
- Contract revisions were ruled by the architect and re-issued to BOTH sides, not
  absorbed by one implementer; a slice whose transcript shows adapter code at a seam
  with no matching revision is bounced to the composition oracle's attention.
- Rule on any reported deviation explicitly: accepted-with-rationale or bounced.
- Every new test arrived with its mutant: three raw legs — mutant without the test,
  green; mutant with it, only that leg red; mutant reverted, all green — each invoked
  the way CI invokes the suite. A mutant claim in prose has not been shown to
  discriminate.
- Measure, do not accept. For any claim that an edit landed, run `git show
  <hash>:<path> | md5sum` yourself across the lineage before spending a re-review on it.
- Every `SCOPE:` item the oracles raised carries a recorded ruling. An unruled necessity
  finding means an implementer may have spent rounds hardening what the round should
  have cut.
- Every slice to be merged holds both seats' APPROVE on its merge hash — carried because
  the paired fix diff missed that seat's matrix files, or re-probed — and each verdict
  line names the seat's resolved model.
- Every slice that drew 2 consecutive REJECTs from one seat has a recorded triage class
  and ruling before its next fix round; a third round with none is a violation.
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
  gates and escalations. If you find yourself dispatching implementers, you have silently
  reverted to direct mode — decide that explicitly instead.
- Record every deviation and its ruling in the round summary; self-reported deviations
  that survive oracle re-review are normally accepted (honesty is the load-bearing part).
- Your rulings are claims. Declining to act ("the other gate already covers that class")
  is a testable hypothesis: probe it, or state it as unprobed. The evidence rule that
  binds implementers binds hardest at the top, where no gate sits above it.
- Known failure modes to watch: information loss (curated summaries hide process
  softness — hence raw transcripts at CP2), late failure detection (outcome audits catch
  botched rounds only after the fact — hence hard gates at plan, merge, and report), and
  contract drift one level down (hence deviation reporting as a standing obligation).
- The architect's report must reconcile with your own audit point-for-point before you
  declare the round complete.
