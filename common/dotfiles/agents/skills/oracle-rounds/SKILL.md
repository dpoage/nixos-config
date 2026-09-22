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
   it. Briefs are self-contained (subagents see no history) and obey the brief contract
   below: bead IDs + `bd show` first, file ownership + explicit non-goals + the
   worktree and scratch path that worker owns, the module-map entry and any seam
   contract the slice owns or consumes, `--design` before code where the bead demands
   decisions, acceptance criteria as properties with their mutants, "commit and reply
   with hash", no bead closing, no pushing, hermetic tests only.
6. **Gate each finished slice with two oracles, differently tasked** (table below;
   `agent: "oracle"`). Spawn them the moment a slice finishes. Each verdict arrives
   with a one-line `Coverage:` summary and a `local://oracle-<slice>-<seat>.md` probe
   matrix; an APPROVE without one is not a verdict — send it back. Do not read the
   matrix unless reconciling a split verdict; it is the arbiter's audit artifact.
   Never collapse the pair into one review; roles never blur — implementers don't
   self-review, oracles never fix, the orchestrator never writes feature code.
7. **Drive fix loops.** REJECT → ONE consolidated fix list to the implementer, written
   to the brief contract below (property, preserve clause, witnesses), carrying both
   oracles' blockers with file:line probe evidence and stating whether the blockers
   expose a brief gap — a requirement the brief never pinned is YOUR defect. Rule every
   `SCOPE:` item before dispatching: a necessity finding relayed as a blocker becomes
   an implementer hardening the thing that should have been deleted. Measure the
   implementer's state claims yourself before spending an oracle on them (rule 5).
   Re-review goes to the REJECTING oracle, which re-runs its own probes. Cheap nits
   batch with the approval message, non-gating.
   **Contract escalation:** an implementer reporting a seam contract as wrong (cannot
   express needed state, forces an adapter, leaks an internal) is your defect: revise
   the `interface-contract` record, re-issue it to every slice that owns or consumes
   the seam, note the revision on the owning bead. Never let one side adapt around it.
   **Loop escalation:** after 2 consecutive fix rounds with no blocker progress (diff
   the blocker list against the prior round), stop and triage:
   - *Thrash* — blockers hit requirements the brief never pinned, the fix closed exactly
     the sites the brief enumerated and the property survived, or the two oracles pull
     opposite ways. Orchestrator failure: record the decision as `--design`, rewrite the
     brief in property form, re-slice if needed. A stronger model loops identically.
   - *Overscope* — blockers are about machinery whose necessity is unproven, or the fix
     rounds have grown the slice past the diff that opened it (`git diff --stat` per
     round). Orchestrator failure: rule the `SCOPE:` items, cut the unnecessary half,
     re-brief the remainder. Descope is a normal exit from a fix loop.
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

## Brief contract

The brief is the orchestrator's product, and most fix rounds are spent on its defects.
Every rule here has rounds behind it; a fix list that violates one costs rounds you will
misattribute to the implementer.

**1. Brief the invariant, not the line numbers.** State what must be true after the fix
as one quantified sentence — "every rendered X equals its expected value, end-anchored",
"no writer of Y runs after the invariant is established". `file:line` citations are
WITNESSES, labeled non-exhaustive, never the fix list itself. Falsifier before dispatch:
*if the implementer closes exactly the cited sites and nothing else, can the property
still be violated?* Yes → the brief is list-shaped; rewrite it. Prefer the closing form
to the patch set — one exact end-anchored equality kills a class that N presence
assertions cannot, and is smaller than the patches.

**2. Name what must survive, not only what must stop.** Every required fix carries a
preserve clause: what must still hold, with the probe that shows it, run before AND
after. Bound the blast radius — which files, which region may change — because "add this
annotation" otherwise lands as a replacement of the block that happened to contain it.
When the fix REPLACES a mechanism, name the observation the old one made that the new
one must still make: you can be handed exactly what you asked for and lose what you
never named.

**3. Every defended property ships with the mutant that kills it.** One mutant per
property, not per test function. The brief names it — default: delete the line the fix
adds; for defaults and unset-variable classes: run the shipped artifact with nothing
exported — and requires raw output, no prose, for three legs: (a) suite under the mutant
WITHOUT the new test — green, and that is the hole; (b) under the mutant WITH it — the
new leg red and every other leg named green, so the new leg is the sole discriminator;
(c) mutant reverted — all green. Each leg invoked exactly the way CI invokes the suite.
A mutant that reddens a pre-existing leg at (a) means the hole is elsewhere and the test
is redundant. A mutant that stays green at (a), at the lint gate and in the mutation
harness while the shipped artifact dies means the suite supplies an input production
does not; the required fix is a leg that runs the shipped artifact with nothing supplied.

**4. Verify the gate before buying coverage.** Run the suite the way CI runs it, confirm
a nonzero executed-test count, and confirm a deliberate break actually fails the required
check — before any brief requires tests. Two fix rounds once bought coverage in a suite
that executed 0 of 1265 tests behind `continue-on-error`. Checking costs one command.

**5. Measure the claim; never relay it.** A claim about repository state — "the edit
landed", "the file says X", "the mutant was red" — is measured by its consumer before
use: `git show <hash>:<path> | md5sum` across the lineage, `git diff -U0 <base>..<hash>
-- <path>`, `grep -c`. Rules that depend on the producer's compliance fail. Pick evidence
by what it rules out: for *did this change*, a hash answers it and a suite that is green
on both sides of the hunk never can. An oracle round spent adjudicating whether an edit
exists is a round you burned. This binds your own rulings too — declining to act ("the
other gate covers that class") is a hypothesis, and ruling on it untested is the defect
you reject in implementers.

**6. Relay the finding, never the explanation.** A verdict's observed behavior and the
command that produced it are evidence; its causal story is inference with no gate behind
it. Never paste a causal sentence into a fix list as required wording. Require the fix
round to evidence any mechanism it states, or to state only the observed behavior and
the command that produced it.

**7. Name the place, not only the work.** Every parallel worker gets its own worktree,
scratch dir and interpreter kernel, named in its brief. Isolation you assume but never
assign is discovered by the agents as collisions — at best.

## Scope contract

The round's scope is the bead list fixed at slicing. Everything the round discovers is a
bead; nothing becomes work inside the round unless it blocks a criterion a round bead
already carries. A round that filed eight pre-existing defects, five at P1, and shipped
none of them, got that part right.

- **Necessity precedes quality.** Rule on whether a thing needs to exist before ruling
  on whether it is good. "Is this parser correct?" is a slice question; "does this parser
  need to exist?" is yours, and answering the first never answers the second. Hardening a
  path that has never executed is the most expensive thing a round can do.
- **Enumerate both sides of an accommodation.** When A must accept B, price what could
  change in A and what could change in B. A spike's layout is not a constraint: moving
  one file has removed blockers that cost three fix rounds on the other side.
- **Scope to where the value is, not symmetrically.** Two wrong variables are not two
  equal jobs when one feeds the primary path and one feeds an arm that has never run.
- **Mid-round criteria replace; they never accumulate.** A new acceptance criterion is a
  scope change: record it on the bead, name what it replaces, and check it is satisfiable
  against the tree the implementer actually has. "Execute, don't lint" added to a brief
  deleted the lint the next round needed — require both, and name both.
- **`SCOPE:` items are ruled, not patched.** Oracles report necessity and dead-path
  findings on a channel that never gates. Rule each before the next dispatch; the default
  ruling on a surface whose only consumer is a path that has never executed is delete or
  descope, not harden.
- **A fix can be more dangerous than the bug.** Where a fix touches activation ordering,
  deletes state, or is otherwise irreversible, the brief asks what it does when it goes
  wrong compared with doing nothing — and that answer is an acceptance criterion.

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
file:line + probe evidence, nits never gate, `SCOPE:` items never gate and return to you
for a ruling, probe matrix out of band) is in the `oracle` def; briefs add only the
slice's bead IDs, acceptance criteria with their mutants, motivating incident, unit
shape, and the scratch path that seat owns.

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
- **Assert the merged value, not membership.** A presence assertion cannot defend an
  option with more than one writer: one `mkForce` deletes a peer's block and every
  membership check still passes. Equality against an exact expected value, end-anchored,
  is the only form that sees a deletion.
- **A suite can be structurally blind to what ships.** Tests that export the variable
  they are testing can never discover that production does not. One leg must run the
  shipped artifact with nothing supplied.
