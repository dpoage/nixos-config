---
name: oracle-rounds
description: Use when driving a multi-issue development round with parallel subagents — worktree-per-slice implementation gated by dual adversarial oracle reviews, merged into a feature branch, composition-reviewed, polished, and left PR-ready. The PR is opened only on explicit user instruction. Trigger when the user asks to "drive issues to ground" or run "the same process" of implementer + two-oracle review rounds.
---

# Oracle-Gated Rounds

One round = a set of beads driven to APPROVE by every seat their tier names, through
parallel worktree slices, merged into a feature branch, composition-reviewed, polished,
and left PR-ready. You orchestrate: map, scope, dispatch, arbitrate, integrate, polish,
report. Roles never blur: you write no feature code, implementers never self-review,
oracles never fix. You NEVER open the PR, merge to main, or close beads.

If the work spans several rounds (an epic), load `skill://arbiter-architect` first: an
epic run directly exhausts this session's context within a few rounds.

## Round lifecycle

1. **Scope.** `bd ready` from the main checkout; `bd show` every candidate. Fold each
   dependency chain into its blocker's slice. The bead list fixed here is the round's
   scope (scope contract below).
2. **Module map** (`skill://module-design`): what modules exist after the round, what
   each hides, its interface, which beads land where. A boundary the round adds or
   moves gets the five-part record as `--design` on its owning bead; otherwise one
   paragraph on the parent bead ("no new boundaries; X, Y land in M").
3. **Slice by module ownership** (Conway). One slice = one module from the map, or a
   coherent set with one owner; never one slice per bead; slice count ≤ modules. One
   implementer does a slice's beads serially. Write the file-ownership map and check
   disjointness by file and pipeline stage, not intent: two slices editing one
   function's stage ("different lines") are one slice, and ordering between two
   features in one code path has one owner. A disjointness failure means the map is
   wrong; fix the map, never split a file.
   - **Shared substrate is wave 0**: implement, gate, merge, then fan out.
   - **Concurrent seams** get a `skill://interface-contract` record with its rejected
     alternative and one owning slice; consumers may not widen it.
   - **Tier every slice** (Docs / Light / Standard / Heavy, table under Oracle tasking)
     by its mechanical trigger. The tier sets the slice's gates; record it in the slice
     map.
3a. **Premortem** (`skill://premortem`) at the size the round's highest slice tier
    names: none for a Docs or Light round, one seat for Standard, three for Heavy. Rule
    every PLAN-BLOCKING item before step 4.
4. **Branch + worktrees.** Feature branch off main; one branch + worktree per slice
   under `../<repo>-wt/`. The user's main checkout is touched only by `bd`. Mark beads
   in_progress.
5. **Dispatch implementers**, one parallel batch per wave (`agent: "implementer"`);
   later waves branch from the feature branch holding wave 0. Briefs are self-contained
   and follow the brief contract: bead IDs, file ownership and non-goals, worktree +
   scratch path + kernel, the module-map entry and seam contracts, criteria as
   properties with their mutants.
6. **Gate each finished slice with the seats its tier names** (`agent: "oracle"`,
   tables below), spawned the moment it finishes; two seats are never one review. The
   verdict contract — `Coverage:` line, out-of-band matrix, `SCOPE:` list — lives in the
   `oracle` def; an APPROVE without its matrix goes back. Read a matrix only to reconcile
   a split verdict. Record each seat's resolved model with its verdict line.
7. **Drive fix loops.** REJECT → ONE consolidated fix list in brief-contract form,
   carrying every seat's blockers with their probe evidence and stating whether they
   expose a brief gap (your defect). Rule every `SCOPE:` item first. Nits batch with the
   approval, non-gating; prose nits skip the implementer and go to the step 10 polish
   list. Fix lists go to `agent: "implementer-max"` in the slice's worktree. Run the
   judge lints (below) on every fix list before sending it and on every reply before
   measuring it.
   - **Audit the fix before any oracle** (brief rule 5). Bounce it without review if
     `git diff -U0 <prev>..<new>` changes lines outside the blast radius, `--stat` lacks
     a file the reply claims, or the diff adds a runner, harness, gate, or CI wiring no
     criterion names.
   - **Re-review is delta-scoped.** The REJECTING seat re-probes its blocker rows, its
     matrix rows on touched files, and its families on the fix diff. A fix diff that
     touches only prose re-probes the blocker rows alone. Full re-review only when the
     fix rewrites the slice.
   - **An APPROVE binds a hash.** It carries past the paired seat's fix iff that diff
     misses its matrix files; otherwise the seat delta re-probes. Merge needs every
     tier seat's APPROVE on the merged hash.
   - **Contract escalation.** An implementer reporting a seam contract as wrong is your
     defect: revise the record, re-issue it to owner and consumers, note it on the
     owning bead. Never let one side adapt around it.
   - **Loop cap — counted, not judged.** A seat's 2nd consecutive REJECT forces triage;
     a blocker the fix introduced counts as no progress. Record class and ruling on the
     bead:
     - *Thrash* — blockers hit requirements the brief never pinned, the fix closed
       exactly the cited sites and the property survived, or the seats pull opposite
       ways. Rewrite the brief in property form, `--design` the decision, re-slice if
       needed. A stronger model loops identically.
     - *Overscope* — blockers on machinery of unproven necessity, or the slice grew past
       its opening diff (`git diff --stat` per round: product / tests / prose). Rule the
       `SCOPE:` items, cut, re-brief. Descope is a normal exit.
     - *Churn* — the same blocker class recurs. *Unreliable* — twice, the implementer's
       claims failed measurement or its fixes deleted outside the blast radius. Both:
       dispatch a fresh `agent: "implementer-max"` with every verdict verbatim, the failed
       branch, and license to discard the approach.

     Each ruling buys one fix round. implementer-max drawing 2 consecutive REJECTs →
     pull the slice, file the evidence on the bead, escalate to the user. "One more
     round" without a recorded triage is a violation.
8. **Merge + integrate.** Every tier seat APPROVEs → merge. Cross-branch integration is
   yours: minimal, with diff scope + LOC recorded, since no slice oracle saw it. After
   the last merge: full gate (build, lint, complete suite) plus a hand smoke test of the
   composed surfaces.
9. **Gate the composition** with one oracle (brief below). A blocker in one slice's
   files → that slice's implementer, re-merge; across slices or in your glue → one
   integration implementer owning exactly the seam files. Re-probe, then re-run the step
   8 gate.
10. **Polish.** After composition APPROVE: `skill://comment-compactor` over touched
    source, then `skill://doc-writer` over touched or now-stale prose plus every prose
    nit the seats carried, scoped by `git diff --name-only main...<feature>`. Comment-
    and prose-only; a code defect found here is a fix round through its slice's
    REJECTING seat. Re-run the gate; the PR-ready tip is the post-polish commit.
11. **Stop at PR-ready**: gate green on the polished tip, slice worktrees and branches
    removed, feature branch pushed. Report: branch + tip; module map and deviations;
    premortem size, verdict, and rulings (or the tier that skipped it); slice tiers;
    every verdict line verbatim with its seat's model; fix-round counts and triage
    rulings; `history://` links to raw oracle transcripts; glue scope + LOC;
    merged-state verification; polish evidence (pre-polish hash, compactor gate per
    file, docs revised, commands re-run);
    wall time per phase (premortem, each slice's first commit, first verdicts, each fix
    round, composition, polish); follow-up beads; draft PR title + body. Record outcomes
    and findings on each bead and refresh its notes for the landing session.

## Outcome ledger

Pre-merge gates are proxies; what escapes them is the only measure of which gates pay.
Label every round bead `round:<round-id>`. When a defect is later filed against code a
round shipped, label the new bead `escaped-from:<round-id>` and name in its body the
gate that should have caught it (brief, premortem, seat A, seat B, composition, polish)
or "none could have". Change a gate's cost only with this ledger and the step 11
wall-time line as evidence.

## Brief contract

Most fix rounds are spent on brief defects. A brief that breaks a rule here costs rounds
you will misattribute to the implementer.

1. **Brief the invariant, not the lines.** State what must hold after the fix as one
   quantified sentence ("every rendered X equals its expected value, end-anchored").
   `file:line` citations are non-exhaustive witnesses. Falsifier: if the implementer
   closes exactly the cited sites, can the property still fail? Then rewrite. Prefer the
   closing form: one end-anchored equality kills a class that N presence assertions
   cannot — a presence check never sees a peer's `mkForce` deletion.
2. **Name what must survive.** Every fix carries a preserve clause with its probe, run
   before and after, and a blast radius (files, region). When a fix replaces a
   mechanism, name the observation the old one made that the new one must keep.
3. **Every defended property names its mutant**, one per property — default: delete the
   line the fix adds; for defaults and unset variables: run the shipped artifact with
   nothing exported. The implementer returns the three raw legs its def specifies: (a)
   full suite under the mutant without the test, (b) the test's module alone with it,
   (c) one shared full suite with every mutant reverted, both full runs invoked as CI
   invokes the suite. Deletion and type-shape criteria take `grep -c` plus a green build
   instead of legs; Docs-tier criteria take the doc-truth probe instead. The legs are
   reply evidence; a harness, runner, or gate ships only when a criterion names it. Leg
   (a) already red means the test is redundant. A mutant green in the suite while the
   shipped artifact dies means the suite supplies an input production does not: require
   a leg that runs the artifact with nothing supplied.
4. **Verify the gate before buying coverage.** Before any brief requires tests, run the
   suite as CI does: nonzero executed-test count, and a deliberate break fails the
   required check.
5. **Measure the claim; never relay it.** A claim about repository state is measured by
   its consumer before use: `git show <hash>:<path> | md5sum` across the lineage,
   `git diff -U0`, `grep -c`. Pick evidence by what it rules out — a suite green on both
   sides of a hunk cannot say whether the hunk landed. This binds your rulings too:
   declining to act ("the other gate covers that") is a hypothesis to probe.
6. **Relay the finding, never the explanation.** A verdict's observed behavior and its
   command are evidence; its causal story is not. Never paste a causal sentence into a
   fix list as required wording; require the fix round to evidence any mechanism it
   states. A prose blocker travels as the property its sentences must satisfy plus the
   falsifying probe, never as replacement text — the oracle's or yours: the implementer
   writes the words, and narrowing or deleting the claim always satisfies it.
7. **Name the place.** Every parallel worker gets its own worktree, scratch dir, and
   interpreter kernel, named in its brief.

## Scope contract

Scope is the bead list fixed at slicing. Everything the round discovers is a bead;
nothing becomes round work unless it blocks a criterion a round bead already carries.

- **Necessity precedes quality.** "Does this need to exist?" is your question, and "is it
  correct?" never answers it. Hardening a path that has never executed is the most
  expensive thing a round does. Rule `SCOPE:` items before the next dispatch; the default
  ruling for a surface whose only consumer never runs is delete or descope.
- **Price both sides of an accommodation.** When A must accept B, price changing B. A
  spike's layout is not a constraint.
- **Scope to where the value is.** A variable feeding the primary path and one feeding a
  never-run arm are not equal jobs.
- **Mid-round criteria replace, never accumulate.** A new criterion is a scope change:
  record it on the bead, name what it replaces, check it is satisfiable against the
  implementer's tree. "Execute, don't lint" silently dropped the lint — require both,
  name both.
- **A fix can be worse than the bug.** When a fix touches activation ordering, deletes
  state, or cannot be undone, what it does when it goes wrong — compared with doing
  nothing — is an acceptance criterion.

## Oracle tasking

Seats are tasked to fail for different reasons: same-brief pairs find the same defects.

| Tier | Mechanical trigger (touched paths and state, not judgment) | Seats |
|---|---|---|
| Docs | Diff touches only prose: docs, changelog, help text, comments, content copy. Research or audit docs are Standard | One: doc truth |
| Light | Rename, dead-code deletion, dedup, refactor whose behavior existing tests already pin | One: seat B |
| Standard | Any behavior change not Heavy | Seat A + seat B |
| Heavy | Persistent state, auth or money, activation ordering, rollout or migration, irreversible steps, cross-repo | Seat A + seat B |

The round's highest tier sizes the premortem (step 3a). Any seat whose probe hits a
higher tier's trigger REJECTs with `re-tier` as its blocker; the slice restarts at step 6
under the new tier. Misfiling down is silent, so the arbiter or user audits tiers with
the plan.

**Doc-truth seat (Docs tier).** `skill://acceptance-replay` step 6 on the sentences the
diff adds or changes, plus `skill://bug-hunt` family 7; blockers only under the `oracle`
def's prose rule. No design review, no mutant legs, no second seat.

| Slice type | Seat A | Seat B |
|---|---|---|
| Feature/bug code | `skill://bug-hunt` families for the unit shape, on the diff and its siblings | `skill://acceptance-replay`, then `skill://design-review` |
| Research/audit doc | Evidence integrity: re-derive counts, grep quotes in primary sources, reproduce claims | Actionability: acceptance fidelity, coverage of the promised space, consistency, downstream use |
| Benchmark/harness | Discrimination: an audit-faithful bad stub fails every claimed-fixed mode; xfail counts in the denominator | Engineering: isolation, reproducibility, provenance, self-tests, doc commands run verbatim |
| CI/workflow | Greenness: per-job green/red predicted and proven locally; pinned-action compatibility | Coverage honesty: tested vs excluded, disabled linters, deliberate breaks bite |

Seat briefs add only bead IDs, criteria with their mutants, the motivating incident, the
unit shape, and the seat's scratch path.

**Composition oracle (step 9).** Subject: `git diff main...<feature>` plus your glue,
judged against the module map. Brief: the map, the file-ownership map, seam records, the
glue diff, the premortem report. Task: `skill://design-review` on the composed diff
(where duplicate helpers, shallow seams, and seam adapters surface), plus **boundary
fidelity** — every boundary not in the map, every map boundary that didn't land; **glue
gating** — the glue reviewed as feature code; **premise fidelity** — each premortem
premise re-probed on the merged branch (none on a Docs or Light round). A boundary the
records say should not exist, or a premise that no longer holds, is BLOCKING.

## Capability allocation

By cost of silent failure: oracles strongest available, with generous time budgets — a
false APPROVE is invisible; implementers mid-tier for first implementation — their
failures surface as REJECTs; fix rounds on `implementer-max`, bound to `@AUGUR`: an
oracle-class model from a different family than `@ORACLE`, so the fixer and its
re-reviewer never share blind spots; scouts and mechanical edits cheap. The defs
(`oracle`, `implementer`, `implementer-max`, `architect`) live in
`~/.omp/agent/agents/`, managed by nixos-config. If one is missing, restore it — NEVER
substitute `task`.

## Judge lints

Run through the eval `judge()` / `judge_batch()` helpers. State is one paragraph or
bullet, except skill routing, which judges the whole brief. Lints flag for you; they
never skip an oracle or block a dispatch.

| Where | Question (verbatim) | Flag at | Action |
|---|---|---|---|
| Every brief, before dispatch | For each installed skill: "A coding agent received this message. Should it load the skill '<name>' before acting? The skill's trigger: <its description>" | ≥ 0.8 | Name `skill://<name>` in the brief unless it already does; subagents start blank |
| Every brief and fix list, before dispatch | "This text is one unit of instructions sent to a coding implementer. Does it assert why something happens or how a system behaves internally (a mechanism, cause, or factual claim about system behaviour) as established fact, without quoting in this same text the command or probe output that establishes it?" | ≥ 0.85 | Probe it and quote the output, or cut to the observed behaviour (brief rule 6) |
| Every implementer reply, before measuring | "This text is one unit of a status report a coding implementer sent its orchestrator. Does it claim an edit landed, a test or mutant passed or failed, or something was verified, WITHOUT including raw evidence for that claim in this text — no command with its output, no diff hunk, no checksum, no quoted test output?" | ≥ 0.7 | Measure these claims first (brief rule 5); each that fails counts toward *Unreliable* |
| Every REJECT, per blocker | choice over PRODUCT / TEST_MACHINERY / PROSE: "What does the BLOCKER UNDER JUDGMENT concern?" | confidence ≥ 0.8, else classify yourself | Track the share per round; a rising non-product share is the *Overscope* signal. A PROSE blocker whose required fix quotes replacement text goes out as its property (brief rule 6) |

Add no other judge lints. Blocker provenance is `git diff` hunk intersection.