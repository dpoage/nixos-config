---
name: oracle-rounds
description: Use when driving a multi-issue development round with parallel subagents — worktree-per-slice implementation gated by dual adversarial oracle reviews, merged into a feature branch, composition-reviewed, then polished (comment-compactor, doc-writer) so it lands fully PR-ready. The PR itself is opened only on explicit user instruction. Trigger when the user asks to "drive issues to ground" or run "the same process" of implementer + two-oracle review rounds.
---

# Oracle-Gated Rounds

One round = a set of beads driven to dual-APPROVE through parallel worktree slices,
merged into a feature branch, composition-reviewed, polished, and left PR-ready. The
orchestrator (you) never writes feature code: you design the module map, scope,
dispatch, arbitrate verdicts, integrate, polish, and report. You NEVER open the PR or
touch main — the PR is opened only on explicit user instruction.

## Round lifecycle

1. **Scope.** `bd ready` from the main checkout. Fold dependency chains into their
   blocker's slice (a blocked bug rides with the bead that unblocks it). Read every
   candidate with `bd show` before slicing.
2. **Design the module map** (`skill://module-design`). Record what modules exist after
   the round, what each hides, its interface, and which beads land in which module.
   Where the round adds or moves a boundary: the five-part form as `--design` on the
   bead owning that boundary. Where it adds none: one paragraph ("no new boundaries;
   beads X,Y land in M") on the round's parent bead. Step 3 slices by this record;
   step 9 judges the merged branch against it.
3. **Slice by module ownership.** Slice boundaries ship as module boundaries (Conway):
   one slice = one module from the map (or a coherent set with one owner), never one
   slice per bead; slice count ≤ modules in the map; beads inside a slice are done
   serially by one implementer. Then write the file-ownership map and check
   disjointness — the test is files-and-pipeline-stage, not intent: two slices editing
   the same function's stage ("different lines") are ONE slice, and ordering between
   two features in one code path belongs to one owner, never merge-time resolution. A
   disjointness failure means the map is wrong; fix the map, don't split files.
   - **Shared substrate is wave 0.** A helper, type, or interface more than one slice
     needs is its own slice: implement, gate, merge, then fan out the feature wave.
   - **Seams that can't be a wave** (both sides genuinely concurrent) get a
     `skill://interface-contract` record before dispatch — including the rejected
     alternative — and one owning slice; consumers may not widen it.
4. **Branch + worktrees.** Feature branch off main; one branch + worktree per slice
   under `../<repo>-wt/`. Never touch the user's main checkout except `bd` commands run
   with cwd there. Mark beads in_progress.
5. **Dispatch implementers, one parallel batch per wave** (`agent: "implementer"`).
   Wave 0 runs alone to merge; later waves branch from the feature branch containing
   it. Briefs are self-contained (subagents see no history): bead IDs + `bd show`
   first, file ownership + explicit non-goals, the module-map entry and any seam
   contract the slice owns or consumes, `--design` before code where the bead demands
   decisions, acceptance criteria, "commit and reply with hash", no bead closing, no
   pushing, hermetic tests only.
6. **Gate each finished slice with two oracles, differently tasked** (table below;
   `agent: "oracle"`). Spawn them the moment a slice finishes. Each verdict arrives
   with a one-line `Coverage:` summary and a `local://oracle-<slice>-<seat>.md` probe
   matrix; an APPROVE without one is not a verdict — send it back. Do not read the
   matrix unless reconciling a split verdict; it is the arbiter's audit artifact.
   Never collapse the pair into one review; roles never blur — implementers don't
   self-review, oracles never fix, the orchestrator never writes feature code.
7. **Drive fix loops.** REJECT → ONE consolidated fix list to the implementer (both
   oracles' blockers, file:line evidence, required fixes), stating whether the blockers
   expose a brief gap — a requirement the brief never pinned is YOUR defect. Re-review
   goes to the REJECTING oracle, which re-runs its own probes. Cheap nits batch with
   the approval message, non-gating.
   **Contract escalation:** an implementer reporting a seam contract as wrong (cannot
   express needed state, forces an adapter, leaks an internal) is your defect: revise
   the `interface-contract` record, re-issue it to every slice that owns or consumes
   the seam, note the revision on the owning bead. Never let one side adapt around it.
   **Loop escalation:** after 2 consecutive fix rounds with no blocker progress (diff
   the blocker list against the prior round), stop and triage:
   - *Thrash* — blockers hit requirements the brief never pinned, or the two oracles
     pull opposite ways. Orchestrator failure: record the decision as `--design`,
     tighten the brief, re-slice if needed. A stronger model loops identically.
   - *Churn* — the same blocker class recurs or fixes spawn new blockers of that class.
     Re-dispatch `agent: "implementer-max"` with ALL verdicts verbatim, the failed
     branch, and license to discard the approach. The same rejecting oracles re-review.
   If implementer-max also fails 2 no-progress rounds: pull the slice, file the evidence
   on the bead, escalate to the user. Unbounded loops at any tier are PROHIBITED.
8. **Merge + integrate.** Both APPROVEs → merge into the feature branch. You own
   cross-branch integration (signature conflicts, help tables, test callsites); keep it
   minimal and record diff scope + LOC — no slice oracle has seen it. After the last
   merge run the full gate (build, lint/vet, complete suite) plus a hand smoke test of
   the composed surfaces. Each branch green ≠ composition green.
9. **Gate the composition** with one oracle (brief below). REJECT routing: a blocker
   inside one slice's files → that slice's implementer (worktree still live), re-merge;
   a blocker across slices or in your glue → one integration implementer owning exactly
   the seam files, dispatched from the feature branch. The composition oracle re-probes;
   then re-run the step 8 gate.
10. **Polish.** After step 9 APPROVE: `skill://comment-compactor` over touched source,
    then `skill://doc-writer` over touched prose and any prose the change made stale,
    both scoped from `git diff --name-only main...<feature>`. Polish is comment- and
    prose-only; a code defect found here goes to its slice's REJECTING oracle as a fix
    round. Re-run the gate after polish; the PR-ready tip is the post-polish commit.
11. **Stop at PR-ready.** Slices merged, composition APPROVE held, polish done, gate
    green on the polished tip, slice worktrees and branches removed (`git worktree
    prune`), feature branch pushed. Do NOT open the PR, merge to main, or close beads.
    Final report: branch + tip hash; module map and deviations from it; per-slice and
    composition verdict lines verbatim; fix-round counts; `history://` links to raw
    oracle transcripts; integration glue (scope, LOC); merged-state verification;
    polish evidence (pre-polish hash, compactor gate per file, docs revised, commands
    re-run); follow-up beads; draft PR title + body. Record outcomes on each bead.

## Oracle tasking

Two per slice, tasked to fail for different reasons — same-brief pairs find the same
defects; differently-tasked pairs split verdicts because they attack disjoint failure
classes:

| Slice type | Oracle A | Oracle B |
|---|---|---|
| Feature/bug code | `skill://bug-hunt`: the families for the slice's unit shape, run on the diff and its siblings | `skill://acceptance-replay`: base and reviewed builds, motivating case replayed, every criterion probed, then `skill://design-review` |
| Research/audit doc | Evidence integrity: re-derive counts, grep quoted excerpts in primary sources, reproduce claims | Actionability: acceptance fidelity, coverage of the promised space, internal consistency, downstream utility |
| Benchmark/harness | Discrimination: falsify with an audit-faithful bad stub; every claimed-fixed mode must fail on baseline | Engineering: isolation, reproducibility, provenance, self-test quality, doc-command verbatim runs |
| CI/workflow | Greenness: per-job green/red prediction proven locally; version compat of pinned actions | Coverage honesty: what is actually tested vs excluded; disabled-linter audits; deliberate-break bites |

The verdict contract (`VERDICT: APPROVE|REJECT` final line, itemized BLOCKING with
file:line + probe evidence, nits never gate, probe matrix out of band) is in the
`oracle` def; briefs add only the slice's bead IDs, acceptance criteria, motivating
incident, and unit shape.

**Composition oracle (one, step 9).** Subject: `git diff main...<feature>` plus your
integration glue, judged against the step 2 module map. Brief carries the map, the
file-ownership map, every seam record, and the glue diff. Task: the `skill://design-review`
probes on the composed diff (not per slice — that is where duplicate helpers, shallow
seams, and adapters at contracts surface), plus two: **boundary fidelity** — name every
boundary in the branch not in the map and every map boundary that didn't land; **glue
gating** — the integration diff reviewed as feature code. A boundary the map or a
design record says should not exist is BLOCKING.

## Capability allocation

By cost of silent failure, not seniority:

1. **Oracles — strongest available.** A false APPROVE is invisible. Spawn
   `agent: "oracle"`, never generic `task`; same for re-reviews; generous time budgets.
2. **Implementers — mid-tier.** Brief quality substitutes for model strength; their
   failures arrive as visible REJECT evidence. Never pre-assign strong models to "hard"
   slices — `implementer-max` exists only for step 7's churn path.
3. **Scouts/mechanical edits — fast cheap models.**

Agent defs (`oracle`, `implementer`, `implementer-max`, `architect`) live in
`~/.omp/agent/agents/`, managed by nixos-config. If a def or role is missing, restore
it from there — NEVER downgrade to `task`.

## Rules the rounds earned (violations found in practice)

- **xfail counts in the denominator.** A before/after metric that excludes expected
  failures saturates at 100% and can never show improvement.
- **Bead hygiene is part of done.** `--design` before code where decisions were required,
  in `skill://module-design`'s five-part form (a record that lies about rewrite or
  deletion cost is itself a blocker); findings and fix-round outcomes recorded as
  comments; notes refreshed so the landing session inherits full context.
