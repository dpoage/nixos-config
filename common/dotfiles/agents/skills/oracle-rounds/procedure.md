# Oracle-Gated Rounds: Procedure

The steps of a round, with the tables and templates each step uses. `SKILL.md` holds the
rules; a step here never overrides a rule. Rule numbers (R1–R9) refer to `SKILL.md`.

## Steps

1. **Scope.** Run `bd ready` from the main checkout and `bd show` every candidate. Fold
   each dependency chain into its blocker's slice. The bead list fixed here is the
   round's scope (R2).
2. **Module map** (`skill://module-design`). Write what modules exist after the round,
   what each hides, its interface, and which beads land where. A boundary the round adds
   or moves gets the five-part record as `--design` on its owning bead. Otherwise, write
   one paragraph on the parent bead ("no new boundaries; X, Y land in M"). Run the
   necessity checks (below) on every mechanism the plan adds.
3. **Slice** (R3). One slice is one module from the map, or a set of modules with one
   owner. One implementer does a slice's beads serially.
   - Write the file-ownership map. Check disjointness by file and pipeline stage, not by
     intent. Two slices that edit one function's stage on "different lines" are one
     slice. The ordering of two features in one code path has one owner.
   - Implement, gate, and merge shared substrate as wave 0. Then fan out.
   - Give each concurrent seam a `skill://interface-contract` record with its rejected
     alternative. Consumers may not widen the seam.
   - Tier every slice by its trigger (tier table) and record the tier in the slice map.
   - Split a module by change kind. The slices run in sequence, and each is gated before
     the next one branches:
     - **Preserve.** Behavior and assertions stay the same. The harness may change, for
       example when tests move to a new call surface. The reply shows that the assertion
       diff against base is empty. The tier is Light unless the paths hit a Heavy
       trigger. Only a preserve slice moves base tests.
     - **Changed assertion.** Each change to what an existing test asserts traces to a
       named property.
     - **New behavior.**
   - Prose findings from an earlier slice's seats go to the step 10 polish list, never
     into a feature slice's properties.
   - Provisional caps, until the outcome ledger confirms or revises them: split a slice
     that carries more than one Heavy-trigger bead or more than five properties.
3a. **Premortem** (`skill://premortem`). The round's highest slice tier sets the size:
   none for Docs or Light, one seat for Standard, three seats for Heavy. Rule every
   PLAN-BLOCKING item before step 4.
4. **Branch and worktrees.** Branch the feature branch off main. Create one branch and
   one worktree per slice under `../<repo>-wt/`. Touch the user's main checkout only with
   `bd`. Mark the beads in_progress.
5. **Dispatch implementers** (`agent: "implementer"`), one parallel batch per wave. Later
   waves branch from the feature branch that holds wave 0. Every brief follows the brief
   checklist (below).
6. **Gate each finished slice** with the seats its tier names (`agent: "oracle"`). Spawn
   the seats when the slice finishes. The verdict contract (`Coverage:` line, matrix,
   `SCOPE:` list) is in the `oracle` def. Send back an APPROVE that has no matrix. Read a
   matrix only to reconcile a split verdict. Record each seat's resolved model with its
   verdict line.
   - **Pre-screen** (Standard and Heavy; trial). Before the seats, spawn one
     `agent: "prescreen"` with the base and tip hashes, the ownership list, the CI
     commands, and the criterion legs. The pre-screen can only REJECT, and only on a
     reproduced command failure or an ownership violation. Re-run each `BLOCKING:`
     command yourself (R5). If it reproduces, it becomes the fix list and no seats spawn.
     If it does not reproduce, record the REJECT as overturned and spawn the seats. A
     PASS gates nothing. Its `LEADS:` go to seat A's brief, labeled unverified; seat B
     never sees them. A slice that returns after a fix round gets a new pre-screen only
     if the previous pre-screen rejected it. The trial ends after three rounds. Keep the
     pre-screen only if the step 11 tally shows at least one upheld REJECT.
7. **Drive fix loops.** On a REJECT, write ONE consolidated fix list in brief-checklist
   form. The list carries every seat's blockers with their probe evidence. For each
   blocker, it says whether the blocker exposes a brief gap (your defect). Rule every
   `SCOPE:` item first. Nits batch with the approval and never gate. Prose nits skip the
   implementer and go to the polish list. Send fix lists to `agent: "implementer-max"` in
   the slice's worktree.
   - **Audit the fix before any oracle sees it.** Bounce the fix without review if
     `git diff -U0 <prev>..<new>` changes lines outside the blast radius, if `--stat`
     lacks a file the reply claims, or if the diff adds a runner, harness, gate, or CI
     wiring that no criterion names.
   - **Re-review** follows the `oracle` def: the rejecting seat re-probes the delta.
   - **An APPROVE carries past the paired seat's fix** only if that fix diff misses the
     approving seat's matrix files. Otherwise the approving seat re-probes the delta.
   - **Contract escalation.** If an implementer reports a seam contract as wrong, the
     defect is yours. Revise the record, re-issue it to the owner and every consumer,
     and note it on the owning bead. Never let one side adapt around the contract.
   - **Loop cap.** A seat's second consecutive REJECT forces triage. A blocker that the
     fix introduced counts as no progress; a blocker is fix-introduced if its lines
     intersect the fix's `git diff` hunks. Record the class and the ruling on the bead:
     - *Thrash*: blockers hit requirements the brief never pinned, the fix closed
       exactly the cited sites and the property survived, or the seats pull in opposite
       directions. Rewrite the brief in property form, `--design` the decision, and
       re-slice if needed. A stronger model loops the same way.
     - *Overscope*: blockers sit on machinery of unproven necessity, or the slice grew
       past its opening diff (`git diff --stat` per round, split product / tests /
       prose). Rule the `SCOPE:` items, cut, and re-brief. Descope is a normal exit.
     - *Churn*: the same blocker class recurs.
     - *Unreliable*: twice, the implementer's claims failed measurement or its fixes
       deleted lines outside the blast radius.

     For Churn or Unreliable, dispatch a fresh `agent: "implementer-max"` with every
     verdict verbatim, the failed branch, and license to discard the approach. Each
     ruling buys one fix round. If implementer-max draws two consecutive REJECTs, pull
     the slice, file the evidence on the bead, and escalate to the user. "One more round"
     without a recorded triage is a violation.
8. **Merge and integrate.** When every tier seat APPROVEs, merge. Cross-branch
   integration is yours. Keep it minimal and record its diff scope and LOC, because no
   slice oracle saw it. After the last merge, run the full gate (build, lint, complete
   suite) and a hand smoke test of the composed surfaces.
9. **Gate the composition** (R7) with one oracle (composition brief below). A blocker in
    one slice's files goes to that slice's implementer, then re-merge. A blocker across
    slices or in your glue goes to one integration implementer that owns exactly the
    seam files. Re-probe, then re-run the step 8 gate.
10. **Polish.** After the composition APPROVE, run `skill://comment-compactor` over
    touched source. Then run `skill://doc-writer` over touched or now-stale prose, plus
    every prose nit the seats carried. Scope both with
    `git diff --name-only main...<feature>`. Polish changes comments and prose only. A
    code defect found here is a fix round through its slice's rejecting seat. Re-run the
    gate; the PR-ready tip is the post-polish commit.
11. **Stop at PR-ready.** The gate is green on the polished tip, slice worktrees and
    branches are removed, and the feature branch is pushed. Send the report (template
    below). Record outcomes and findings on each bead and refresh its notes for the
    landing session.

## Necessity checks

Apply these at step 2 and whenever you rule a `SCOPE:` item (R2).

- For every mechanism the plan adds, say what breaks if the mechanism does not exist.
- If a surface's only consumer never runs, the default ruling is delete or descope.
- When component A must accept component B, price a change to B as well as to A. A
  spike's layout is not a constraint.
- Scope to where the value is. A variable that feeds the primary path and a variable that
  feeds a never-run branch are not equal jobs.
- When a fix touches activation ordering, deletes state, or cannot be undone, its
  behavior when it goes wrong, compared with doing nothing, is an acceptance criterion.

## Brief checklist

Every implementer brief and fix list contains these items.

- Bead IDs, file ownership, and non-goals.
- Every skill the worker must load, named as `skill://<name>`. Subagents start blank.
- Worktree, scratch path, and interpreter kernel (R8).
- The module-map entry and the seam contracts the slice owns or consumes.
- Criteria as properties with their mutants (R4). Prefer the closing form: one
  end-anchored equality kills a class of defects that N presence assertions cannot.
- A preserve clause with its before-and-after probe, and a blast radius (files, region).
  When a fix replaces a mechanism, name the observation the old mechanism made that the
  new one must keep.
- The mutant for each property. Default: delete the line the fix adds. For defaults and
  unset variables: run the shipped artifact with nothing exported. The implementer
  returns the legs its def specifies. Deletion and type-shape criteria take `grep -c`
  and a green build instead of legs. Docs-tier criteria take the doc-truth probe. If
  leg (a) is already red, the test is redundant. If a mutant is green in the suite while
  the shipped artifact dies, the suite supplies an input that production does not:
  require a leg that runs the artifact with nothing supplied.
- A harness, runner, or gate ships only when a criterion names it.
- Before any brief requires tests, verify the gate: run the suite as CI runs it, confirm
  a nonzero executed-test count, and confirm that a deliberate break fails the required
  check.
- A prose blocker travels as the property its sentences must satisfy, plus the
  falsifying probe. It never travels as replacement text, whether the text is the
  oracle's or yours. Narrowing or deleting the claim always satisfies the property.

## Tiers and seats

| Tier | Trigger (touched paths and state, not judgment) | Seats |
|---|---|---|
| Docs | The diff touches only prose: docs, changelog, help text, comments, content copy. Research and audit docs are Standard | One: doc truth |
| Light | Rename, dead-code deletion, dedup, or a refactor whose behavior existing tests already pin | One: seat B |
| Standard | Any behavior change that is not Heavy | Seat A + seat B |
| Heavy | Persistent state, auth or money, activation ordering, rollout or migration, irreversible steps, cross-repo | Seat A + seat B |

If a seat's probe hits a higher tier's trigger, the seat REJECTs with `re-tier` as its
blocker, and the slice restarts at step 6 under the new tier. Misfiling a slice to a
lower tier is silent, so the arbiter or the user audits tiers with the plan.

**Doc-truth seat (Docs tier).** Run `skill://acceptance-replay` step 6 on the sentences
the diff adds or changes, plus `skill://bug-hunt` family 7. Blockers follow the `oracle`
def's prose rule. No design review, no mutant legs, no second seat.

Seats are tasked to fail for different reasons (R6):

| Slice type | Seat A | Seat B |
|---|---|---|
| Feature or bug code | `skill://bug-hunt` families for the unit shape, on the diff and its siblings | `skill://acceptance-replay`, then `skill://design-review` |
| Research or audit doc | Evidence integrity: re-derive counts, grep quotes in primary sources, reproduce claims | Actionability: acceptance fidelity, coverage of the promised space, consistency, downstream use |
| Benchmark or harness | Discrimination: a bad stub faithful to the audit fails every claimed-fixed mode; xfail counts in the denominator | Engineering: isolation, reproducibility, provenance, self-tests, doc commands run verbatim |
| CI or workflow | Greenness: per-job green or red, predicted and proven locally; pinned-action compatibility | Coverage honesty: tested vs excluded, disabled linters, deliberate breaks fail |

Seat briefs add only the bead IDs, the criteria with their mutants, the motivating
incident, the unit shape, and the seat's scratch path.

**Composition brief (step 9).** Subject: `git diff main...<feature>` plus your glue,
judged against the module map. Inputs: the module map, the file-ownership map, the seam
records, the glue diff, and the premortem report. Tasks:

- `skill://design-review` on the composed diff. Duplicate helpers, shallow seams, and
  seam adapters surface here.
- Boundary fidelity: every boundary that is not in the map, and every map boundary that
  did not land.
- Glue gating: review the glue as feature code.
- Premise fidelity: re-probe each premortem premise on the merged branch. Skip this task
  on a Docs or Light round.

A boundary that the records say should not exist is BLOCKING. A premise that no longer
holds is BLOCKING.

## Capability allocation

Rank model strength by the cost of silent failure. The tempting default, a strong
architect with cheaper oracles, is backwards: it guards the visible failure and starves
the invisible one.

| Role | Model | Reason |
|---|---|---|
| Oracles | `@ORACLE`, strongest available, generous time budget | A false APPROVE is invisible |
| Architect (epic mode) | `@ARCHITECT`, strong | Its failures are visible at checkpoints |
| Implementers | `@IMPLEMENTER`, mid-tier | Their failures surface as REJECTs |
| implementer-max | `@AUGUR`, oracle-class, from a different model family than `@ORACLE` | Fix rounds concentrate collateral edits and false claims. A fixer from the reviewer's family shares the reviewer's blind spots |
| Pre-screen, sweepers, scouts, mechanical edits | Cheap (`@PRESCREEN`, `@SWEEP`) | None can approve. The pre-screen only rejects, and sweeper output is leads the oracle re-probes |

The defs (`oracle`, `prescreen`, `sweeper`, `implementer`, `implementer-max`, `architect`)
live in `~/.omp/agent/agents/`, managed by nixos-config. If a def is missing, restore it.
NEVER substitute `task`.

## Outcome ledger

Pre-merge gates are proxies. What escapes them is the only measure of which gates pay.

1. Label every round bead `round:<round-id>`.
2. When a defect is later filed against code a round shipped, label the new bead
   `escaped-from:<round-id>`.
3. In that bead's body, name the gate that should have caught the defect (brief,
   premortem, seat A, seat B, composition, polish), or write "none could have".

R9 uses this ledger, plus the step 11 wall-time line, as its evidence.

## Report template (step 11)

- Branch and tip hash.
- Module map, and where the landed branch deviates from it.
- Premortem size, verdict, and rulings, or the tier that skipped it.
- Slice tiers.
- Every verdict line verbatim, with its seat's model.
- Pre-screen tally: REJECTs, REJECTs you overturned, and PASSes that a seat then
  rejected on a mechanical failure the pre-screen should have run.
- Fix-round counts and triage rulings.
- `history://` links to the raw oracle transcripts.
- Glue scope and LOC; merged-state verification.
- Polish evidence: pre-polish hash, compactor gate per file, docs revised, commands
  re-run.
- Wall time per phase: premortem, each slice's first commit, first verdicts, each fix
  round, composition, polish.
- Follow-up beads; draft PR title and body.
