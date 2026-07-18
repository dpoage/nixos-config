---
name: oracle-rounds
description: Use when driving a multi-issue development round with parallel subagents — worktree-per-slice implementation gated by dual adversarial oracle reviews. The round STOPS when every slice holds two APPROVE verdicts; integration and landing stay with the user. Trigger when the user asks to "drive issues to ground" or run "the same process" of implementer + two-oracle review rounds.
---

# Oracle-Gated Rounds

One round = a set of beads driven to dual-APPROVE through parallel worktree slices, each
gated by TWO differently-tasked adversarial reviews. The orchestrator (you) never writes
feature code; you scope, dispatch, arbitrate verdicts, and report. You NEVER merge, PR,
push, or land — the round ends when all oracles have returned.

## Round lifecycle

1. **Scope.** `bd ready` from the main checkout. Fold dependency chains into their
   blocker's slice (a blocked bug rides with the bead that unblocks it). Read every
   candidate with `bd show` before slicing.
2. **Slice by real disjointness.** Write a file-ownership map per slice. The test is
   files-and-pipeline-stage, not intent: two slices editing the same function's stage
   ("different lines") are ONE slice. Ordering decisions between two features in the same
   code path belong to one owner, never to merge-time resolution.
3. **Branches + worktrees.** One branch per slice off main, one worktree per branch under
   a sibling dir (`../<repo>-wt/`). Never touch the user's main checkout except `bd`
   commands run with cwd there. Mark beads in_progress.
4. **Dispatch implementers in one parallel batch** — spawn with `agent: "implementer"`.
   Briefs are self-contained (subagents see no history): bead IDs + `bd show` first,
   file ownership + explicit non-goals, `--design` recorded BEFORE implementation where
   the bead demands decisions, acceptance criteria, "commit and reply with hash", no
   bead closing, no pushing, hermetic tests only.
5. **Gate each finished slice with two oracles, differently tasked** (see below). Spawn
   them the moment a slice finishes; don't wait for the whole wave.
6. **Drive fix loops.** REJECT → send the implementer ONE consolidated fix list (merge
   both oracles' blockers; quote file:line evidence; state required fixes). Re-review goes
   to the REJECTING oracle, which must re-run its own probes, not accept claims. Nits are
   fixed non-gating when cheap — batch them with an approval message.
7. **Report and STOP.** The round is over when every slice holds APPROVE from both its
   oracles. Do NOT merge, open a PR, push, or close beads — integration and landing
   belong to the user. Leave every worktree and branch in place. Final report per slice:
   branch + commit hash, both verdict lines quoted verbatim, fix-round count,
   `history://` links to the raw oracle transcripts, follow-ups filed as beads. Record
   outcomes on each bead as comments.

## Oracle tasking patterns

Always two per slice, tasked to fail for different reasons:

| Slice type | Oracle A | Oracle B |
|---|---|---|
| Feature/bug code | Adversarial correctness: edge cases, mutation of scratch copies, forced failures, regression diff of existing tests | Behavior/UX replay: build the binary, replay the motivating incident/transcript live, judge against acceptance + design principles |
| Research/audit doc | Evidence integrity: re-derive counts, grep quoted excerpts in primary sources, reproduce claims | Actionability: acceptance fidelity, coverage of the promised space, internal consistency, downstream utility |
| Benchmark/harness | Discrimination: falsify with an audit-faithful bad stub; every claimed-fixed mode must fail on baseline | Engineering: isolation, reproducibility, provenance, self-test quality, doc-command verbatim runs |
| CI/workflow | Greenness: per-job green/red prediction proven locally; version compat of pinned actions | Coverage honesty: what is actually tested vs excluded; disabled-linter audits; deliberate-break bites |

**Verdict contract (put in every oracle brief):** final line exactly `VERDICT: APPROVE`
or `VERDICT: REJECT`; REJECT preceded by itemized BLOCKING issues (file:line, why, required
fix); nits listed separately and never gate; no style rejections; every finding grounded in
an executed probe. Oracles are read-only on the worktree but must build, run, and mutate
scratch copies.

## Capability allocation

Assign model strength by **cost of silent failure**, not role seniority:

1. **Oracles — strongest available, no exceptions.** A weak oracle's failure mode is a
   false APPROVE, which is invisible; the gate is only as strong as its reviewer. The
   catches that justify this process (math errors, version incompatibilities proven from
   upstream source, adversarial input kills, harness falsification) all required
   top-tier reasoning. Give oracles generous time budgets — a 40-minute oracle that
   finds one real defect is the cheapest agent in the round.
   Spawn with `agent: "oracle"` — NEVER as generic `task` workers (those run the
   mid-tier `task` model role). Same rule for re-reviews.
2. **Implementers — mid-tier suffices; brief quality substitutes for model strength.**
   Their errors are exactly what the gate catches. Too weak churns fix rounds (each
   costs two oracle re-reviews), so not minimal — but a detailed, self-contained brief
   moves more quality than a stronger model does.
3. **Scouts/mechanical edits — fast cheap models.**

Agent definitions (`oracle`, `implementer`, `architect`) live in `~/.omp/agent/agents/`,
managed by nixos-config; each binds its model through a `@role` alias resolved via
`modelRoles` (`~/.omp/agent/config.yml`). If one is missing, restore it from
nixos-config (an unknown `agent:` value errors with the available roster) — NEVER
downgrade to `task`.

Pair DIVERSITY outranks duplication: two equally strong oracles with the same brief find
the same defects; differently-tasked pairs routinely split verdicts (one APPROVE, one
REJECT) because they attack disjoint failure classes. Never collapse the pair into one
"very thorough" review. Roles never blur: implementers don't self-review, oracles never
fix (read-only + scratch copies), the orchestrator never writes feature code.

## Rules the rounds earned (violations found in practice)

- **Predicates observe real state.** A test/bench predicate asserting output the binary
  never prints is fiction; assert machine-readable output, exit codes, DB state.
- **xfail counts in the denominator.** A before/after metric that excludes expected
  failures saturates at 100% and can never show improvement.
- **Baseline must fail what the round fixes.** If the old binary passes a scenario the
  audit calls broken, the scenario is mis-specified — falsify with a bad stub.
- **"Already fixed" claims get forensics.** Verify the broken state existed at filing,
  name the fixing commit, and prove the new regression test discriminates by mutation.
- **A knowingly-failing check is not green.** "Documented" red gates approval; fix
  hermetically (stub network and heavy dependencies) without shrinking coverage.
- **Destructive paths get adversarial input.** Empty string, whitespace, unset-$VAR
  expansion — refusal must be proven with before/after state counts.
- **Docs state binary truth.** Every published example runs verbatim against the built
  binary; every claimed default verified by probe. Doc-vs-binary lies are BLOCKING.
- **Bead hygiene is part of done.** `--design` before code where decisions were required;
  findings and fix-round outcomes recorded as comments; notes refreshed so the landing
  session inherits full context.
