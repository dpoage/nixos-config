---
name: oracle-rounds
description: Use when driving a multi-issue development round with parallel subagents — worktree-per-slice implementation gated by dual adversarial oracle reviews, merged into a feature branch, composition-reviewed, polished, and left PR-ready. The PR is opened only on explicit user instruction. Trigger when the user asks to "drive issues to ground" or run "the same process" of implementer + two-oracle review rounds.
---

# Oracle-Gated Rounds

A round takes a set of beads to a PR-ready feature branch. Implementers build each slice
in its own worktree. Oracle seats gate each slice, and one composition oracle gates the
merged whole. You orchestrate: map, scope, dispatch, rule, integrate, polish, report. You
NEVER open the PR, merge to main, or close beads.

If the work spans several rounds (an epic), load `skill://arbiter-architect` first.

This file holds the rules. `skill://oracle-rounds/procedure.md` holds the steps, tables,
and templates. Read `procedure.md` in full before step 1; a step you have not read is a
step you skip. `skill://oracle-rounds/casebook.md` holds the incidents behind the rules.
The casebook gives examples; it adds no rules.

## Rules

1. **Roles never blur.** You write no feature code. Implementers never review their own
   work. Oracles never fix what they review.
   Why: each role's output is the next role's evidence. A role that checks itself
   produces no evidence.

2. **Scope is the bead list fixed at slicing.** Everything the round discovers becomes a
   bead. Nothing becomes round work unless it blocks a criterion a round bead already
   carries. Ask "does this need to exist?" before "is it correct?", and rule every
   `SCOPE:` item before the next dispatch. A new criterion mid-round replaces a named
   criterion; criteria never accumulate.
   Why: hardening a path that never executes is the most expensive thing a round does.

3. **A slice has one owner and asks one oracle question.** Slice by the module map, not
   by the bead list. If two slices would edit one file at one pipeline stage, the map is
   wrong; fix the map. Shared substrate is wave 0. Every concurrent seam has one owning
   slice and an interface-contract record. Keep three kinds of change in separate
   slices: behavior-preserving work, changes to what existing tests assert, and new
   behavior.
   Why: a seat judges one kind of change per diff. A diff that refactors code and
   changes the assertions of the same tests leaves the refactor with no oracle.

4. **Criteria are properties, each with a mutant.** State what must hold as one
   quantified sentence. Cited lines are witnesses, not the criterion. Each property names
   the mutant that must make it fail. Each change names what must survive it, with a
   probe that runs before and after the change.
   Falsifier: if the implementer closes exactly the cited sites, can the property still
   fail? If yes, rewrite the property.
   Why: a brief shaped like a list produces a fix shaped like a list, and the property
   survives.

5. **Claims carry their evidence.** Measure a claim about repository state before you
   use it: a hash, a diff hunk, a count. Pick evidence by what it rules out: a suite that
   is green on both sides of a hunk cannot show that the hunk landed. Relay an oracle's
   finding and its command, never its explanation. This rule binds your rulings too:
   "another gate covers that" is a hypothesis to probe.
   Why: a claim that moves without its evidence costs a round when it fails.

6. **Seats are independent and fail for different reasons.** The slice's tier sets its
   seats. Two seats are never one review. An APPROVE binds a hash, and a merge needs
   every seat's APPROVE on the merged hash. A count caps fix loops: a seat's second
   consecutive REJECT forces a recorded triage.
   Why: a false APPROVE is invisible, and seats with the same brief find the same
   defects.

7. **The whole gets a gate.** After the last merge, one composition oracle reviews the
   composed diff, including your glue as feature code. It runs before the branch is
   PR-ready.
   Why: a per-slice gate cannot see a defect that no slice owns.

8. **Every worker has a named place.** Every brief names the worker's worktree, scratch
   directory, and interpreter kernel.
   Why: parallel workers without a named place collide and corrupt each other's
   evidence.

9. **Evidence changes the process.** Record escapes in the outcome ledger. Change a
   gate's cost, or add a rule to this file, only with ledger evidence or a second recorded
   occurrence of the same failure. A one-off incident goes to the casebook.
   Why: a rule added for every incident makes the process too large to follow.
