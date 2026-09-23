---
name: premortem
description: Use when attacking a development plan before any code exists — assume the round shipped and failed, then find how by executed probe against the base tree and the state the plan ships into. The plan-stage oracle seat in an oracle round (after slicing, before worktrees); also for any rollout, migration, or cutover plan on demand. Read-only; ends with PLAN: PROCEED or PLAN: REVISE. Trigger on "premortem", "attack the plan", "what could go wrong with this rollout", "before we dispatch". For a diff load `bug-hunt` or `acceptance-replay`; for design judgment of code load `design-review`.
---

# Premortem

Assume the round shipped and failed. Find how, by executed probe against the base tree
and the state the plan ships into. A premortem attacks the plan's premises: what ships,
into what, gated by what, justified by which evidence. It does not redesign; the
orchestrator rules every item it raises. A finding from reading alone is a hypothesis
and is labeled so.

Read-only on every checkout and every live system. Evaluate, build, and dry-run in
scratch copies; never activate, deploy, or write state. Where a probe needs a live host,
state the command you would run and mark the row unverified.

## When it runs

In an oracle round: after slicing, before any branch or dispatch, when any of these
holds:

- the round ships to live systems, or includes a rollout, migration, or cutover;
- it spans more than one repository;
- it touches activation ordering, persistent state, secrets, or CI gates;
- it has three or more slices.

When none holds, the orchestrator records the triggers it checked and skips the seat.

## Subject

The brief carries: the module map and design records; slices, beads, file-ownership
map, waves; every acceptance criterion with its named mutant; every seam record; the
evidence behind each design decision (the probe, command, or source that settled it);
the base commit of every repository; and the deploy path — how the artifact reaches its
target and what it replaces there.

## Families

Run all seven. Each matrix row is an executed probe with its observed result. A family
with nothing in the plan to attack gets one row naming why ("no pinned inputs change:
`git diff --stat <base> -- flake.lock` empty") and stops there; a family ends when
every plan element it applies to has a row.

**Seats.** The families are independent; run them as three parallel `agent: "oracle"`
seats, each with its own scratch path: shipped state (1, 2, 5), plan logic (3, 4), and
evidence (6, 7). Each seat writes its own matrix and lists; the orchestrator merges
them into one report under one `PLAN:` line.

1. **Direction of shipped state.** Build or evaluate what the plan ships and what runs
   now, and diff the values that matter per target: versions, enabled services, pinned
   inputs, per-target settings. Name the direction of every moved value. "N targets
   change" is not a result; an upgrade and a downgrade both change. A regression, a
   loss, or a target that silently drops out of scope is PLAN-BLOCKING.
2. **Gate reality.** For every check the plan relies on — CI job, suite, required
   status, lint — run it the way CI runs it, record the executed-test count, and break
   something on purpose to confirm the required check goes red. A gate that executes
   nothing or cannot fail gates nothing: every criterion resting on it is PLAN-BLOCKING
   until it names a gate that bites. A prior premortem's gate row carries when the
   runner, CI workflow, and suite config are byte-identical to its commit (`git diff
   --stat <prior>..<base> -- <those paths>` empty); cite the row and that diff instead
   of re-running.
3. **Necessity trace.** For every mechanism the map adds or hardens, trace its consumer
   in shipped execution: caller count, and evidence the path runs (config, logs, a dry
   run). A mechanism whose only consumer never runs is PLAN-BLOCKING; the ruling is
   delete or descope, before an implementer builds it.
4. **Accommodation pricing.** At every seam where A adapts to B, price the alternative:
   what changes in B instead, in files and risk. A spike's layout, a default, or an
   existing path is not a constraint until priced. An unpriced accommodation whose
   alternative is cheaper is PLAN-BLOCKING.
5. **Transition walk.** Walk the rollout on one target, in order: what activates first,
   which state persists, which unit restarts which, where anything blocks, what a stop
   halfway leaves behind, how it rolls back. For every step that touches activation
   ordering, deletes state, or cannot be undone, answer: what does it do when it goes
   wrong, compared with doing nothing? No answer, or an answer worse than doing
   nothing, is PLAN-BLOCKING. A one-way door without rollback is at least a RISK with
   its owner named.
6. **Criteria.** Every acceptance criterion executes against the real tree (not an
   orphaned commit, a dirty checkout, or a warm cache), fails on base, observes
   something that differs between the outcome wanted and the outcome feared, and names
   a mutant that exists and dies. A criterion failing any of these is PLAN-BLOCKING as a
   brief defect.
7. **Evidence re-run.** Re-run every probe that settled a design decision, sterile: no
   ambient credentials or dotfiles, cold caches, your own interpreter, real binaries
   (`jq` is jq, not a shadow). State the isolation per row. A decision whose evidence
   changes under isolation is PLAN-BLOCKING.

## Output

Each seat writes its matrix to `local://premortem-<round>-<seat>.md` — family, probe,
command, isolation, observed result; no prose. Each reply carries three lists and two
closing lines; the merged report takes the union and the worst `PLAN:` line:

- **PLAN-BLOCKING** — changes the module map, scope, a seam, or a criterion. Each item:
  the premise it falsifies, the probe and its output, the plan element it hits, and a
  one-sentence remedy. Finding separate from explanation, as in the `oracle` verdict
  contract.
- **RISK** — a hazard the plan may accept: trigger, blast radius, available mitigation,
  owner. Accepted risks go into the rollout notes and the draft PR body.
- **NEW-BEAD** — a pre-existing defect the probes found, filed per the `bug-hunt` output
  rules. Never round work unless it blocks a criterion a round bead already carries.
- `Coverage: <families> families, <probes> probes, <skipped> skipped — local://premortem-<round>-<seat>.md`
- Final line: `PLAN: PROCEED` when no PLAN-BLOCKING item stands, else `PLAN: REVISE`.

Propose no redesign beyond the one-sentence remedy. The plan is the orchestrator's
product.

## After the verdict

The orchestrator rules every PLAN-BLOCKING item before any branch exists: revise the
map, scope, seam, or criterion, or record the probe showing the item does not hold. A
revision re-runs only the families it touches. The report travels to the composition
oracle, which re-probes each established premise on the merged branch.
