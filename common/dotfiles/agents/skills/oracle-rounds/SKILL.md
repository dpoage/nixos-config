---
name: oracle-rounds
description: Use when landing a multi-issue development round with parallel subagents — worktree-per-slice implementation gated by dual adversarial oracle reviews, merged to a feature branch, PR'd to main, and squash-merged on green CI. Trigger when the user asks to "drive issues to ground", land an epic, or run "the same process" of implementer + two-oracle review rounds.
---

# Oracle-Gated Rounds

One round = a set of beads landed on main through parallel worktree slices, each gated by
TWO differently-tasked adversarial reviews. The orchestrator (you) never writes feature
code; you scope, dispatch, arbitrate verdicts, integrate, and land.

## Round lifecycle

1. **Scope.** `bd ready` from the main checkout. Fold dependency chains into their
   blocker's slice (a blocked bug rides with the bead that unblocks it). Read every
   candidate with `bd show` before slicing.
2. **Slice by real disjointness.** Write a file-ownership map per slice. The test is
   files-and-pipeline-stage, not intent: two slices editing the same function's stage
   ("different lines") are ONE slice. Ordering decisions between two features in the same
   code path belong to one owner, never to merge-time resolution.
3. **Branch + worktrees.** Feature branch off main; one worktree per slice under a
   sibling dir (`../<repo>-wt/` or `../known-wt/`). Never touch the user's main checkout
   except `bd` commands run with cwd there. Mark beads in_progress.
4. **Dispatch implementers in one parallel batch.** Briefs are self-contained (subagents
   see no history): bead IDs + `bd show` first, file ownership + explicit non-goals,
   `--design` recorded BEFORE implementation where the bead demands decisions, acceptance
   criteria, "commit and reply with hash", no bead closing, no pushing, hermetic tests only.
5. **Gate each finished slice with two oracles, differently tasked** (see below). Spawn
   them the moment a slice finishes; don't wait for the whole wave.
6. **Drive fix loops.** REJECT → send the implementer ONE consolidated fix list (merge
   both oracles' blockers; quote file:line evidence; state required fixes). Re-review goes
   to the REJECTING oracle, which must re-run its own probes, not accept claims. Nits are
   fixed non-gating when cheap — batch them with an approval message.
7. **Merge + integrate.** You merge slices into the feature branch and own cross-branch
   integration: signature conflicts, help tables, test callsites. Each branch green ≠
   composition green — after merging, re-verify: `go build`, `go vet`,
   `go test -race -count=1 ./...`, the bench harness against the merged binary, and a
   hand smoke test of the changed surfaces composed together.
8. **PR and land.** PR body: per-slice summary, oracle verdict counts, fix rounds,
   verification evidence, follow-ups filed. Merge ONLY on fully green CI (squash; subject
   ends with the PR number). Then: ff-only the main checkout, close every bead with a
   decision-bearing `--reason` citing PR + commit, `bd dolt push`, remove worktrees and
   local+remote branches, `git worktree prune` (oracles sometimes leave strays in /tmp).

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

## Rules the rounds earned (violations found in practice)

- **Predicates observe real state.** A test/bench predicate asserting output the binary
  never prints (an `Expires:` line, an `elaborates:` suggestion) is fiction; assert via
  `show --json`, exit codes, DB state.
- **xfail counts in the denominator.** A before/after metric that excludes expected
  failures saturates at 100% and can never show improvement.
- **Baseline must fail what the round fixes.** If the old binary passes a scenario the
  audit calls broken, the scenario is mis-specified — falsify with a bad stub.
- **"Already fixed" claims get forensics.** Verify the broken state existed at filing,
  name the fixing commit, and prove the new regression test discriminates by mutation.
- **"Documented" red CI is not green.** A knowingly-failing job blocks the merge; fix
  hermetically (stub embedders/network) without shrinking coverage.
- **Destructive paths get adversarial input.** Empty string, whitespace, unset-$VAR
  expansion — refusal must be proven with before/after state counts.
- **Docs state binary truth.** Every published example runs verbatim against the built
  binary; every claimed default verified by probe. Doc-vs-binary lies are BLOCKING.
- **Bead hygiene is part of done.** `--design` before code where decisions were required;
  close reasons say what was decided and cite the PR; refresh notes after fix rounds.

## Environment appendix (this machine / this repo)

- Git identity unset in worktrees: `git -c user.name=Dustin -c user.email=poage.dustin@gmail.com`
  on every commit/merge you author.
- `gh` needs a PTY (keyring token). Auto-merge is disabled and the ruleset demands an
  impossible self-review: after green CI and user-granted authority, `gh pr merge --squash --admin`.
- Postgres via podman: `systemctl --user start podman.socket`;
  `DOCKER_HOST=unix://$XDG_RUNTIME_DIR/podman/podman.sock TESTCONTAINERS_RYUK_DISABLED=true KNOWN_INTEGRATION=1`.
  Storage changes must keep `storage/contract_test.go` green on BOTH backends.
- Real-embedding probes: temp HOME with `~/.cache/huggingface` symlinked in; never touch
  `~/.known`; never `export HOME` into a persistent shell (poisons the Go module cache and
  fills /tmp) — set env per command and clean temp dirs.
- CI runs `-race` + golangci-lint v2: unit tests must never construct a real HugotEmbedder
  (upstream gomlx race); use the stub-embedder patterns in `cmd/*_test.go`.
- bench/capture conventions: scenario IDs cite their bead, `ExpectFailBaseline` for
  unlanded contracts, paired `_Pass`/`_Fail` self-tests via the stubbed-binary pattern.
