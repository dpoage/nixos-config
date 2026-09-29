# Retro: the fleet-cutover round, 2026-09-21

An oracle-gated round on epic `robot-provisioning-8qv` (two-repo GitOps cutover). Three
slices ran. Two are still in review. One was descoped by the user after three fix rounds,
because most of its work was unnecessary.

Nothing merged. Nothing shipped. The round's largest output was eight pre-existing
defects that nobody was looking for.

## What the round was asked to do

The user asked for a rollout plan for the comin cutover, then asked to fix four named
blockers through oracle-gated slices:

| Blocker | Slice | Bead | State |
|---|---|---|---|
| 2 — no binary-cache gate in the fleet repo | wave 1, never started | `cdup` | blocked on wave 0 |
| 3 — SSH key-scoping collision on the platform input | `slice/platform-transport` | `g7y8` | in review, 3 commits |
| 4 — controller-push/adopt target the wrong flake | `slice/comin-target` | `15vn` | DESCOPED, 3 commits |
| 5 — comin has no fleet deploy key | `slice/comin-identity` | `idj2` | in review, 4 commits |

The user dropped blocker 1 (the fleet repo is 8 robots stale). An oracle later found that
decision has a cost: the CI gate covers 42 of 58 node configs, silently.

## Cost

| Measure | Value |
|---|---|
| Slice commits | 10 across 3 branches |
| Lines added | 1570 |
| Oracle reviews | 18 agent sessions; 15 verdicts delivered (14 REJECT, 1 APPROVE), 3 in flight |
| Fix rounds | 3 on `comin-target`, 3 on `comin-identity`, 2 on `platform-transport` |
| Code about to be deleted as unnecessary | 76 lines of production Nix, ~200 lines of tests |

## Why blocker 4 overscoped

The necessary fix was about two lines.

`fleet.nix` sets `pattern.comin.repositorySubdir = ""`, because the fleet flake sits at
the repository root. `controller-push.sh` defaults `COMIN_REPO_SUBDIR=nix`. After the
cutover, every Pi push would evaluate a `nix/` subdirectory that does not exist. Deriving
that one variable from the option that already exists closes the blocker.

The slice fixed a second variable as well. `GITHUB_FLAKE_BASE` names the repository for
`flake_url`'s fallback arm. Deriving it from `pattern.comin.remoteUrl` required a
URL-grammar parser written in Nix, two NixOS assertions, two exported form lists, a drift
test, and a host-anchoring table.

The fallback arm runs only when `/var/lib/comin/repository` is absent. That arm has never
worked on any robot: it emits no `dir=`, and the platform repo has no root flake. Bead
`s822` records it.

So the parser hardens dead code. Three of the five blockers open at descope time came from
the parser half:

- the assertion-guard test could not tell the two modules apart, so neutering either
  module's assertion left the suite green
- the drift test passed vacuously: emptying either form list left the suite green
- the host dot-anchoring had no witness, so unescaping the dots mapped
  `git@github-com:Pattern-Labs/robot-provisioning.git` onto the real repository with a
  green suite

## Five orchestrator errors, named

**1. I answered the wrong question about the parser.** In round 2 an oracle reported that
the machinery sat on the less load-bearing half, while `repositorySubdir` — on the primary
path — used a plain option with no machinery. I ruled "keep the parser", because a loud
eval failure beats silent divergence. That reasoning is sound and it answered "is this
parser good?". The question was "does this parser need to exist?".

**2. I froze the wrong variable.** The slice exists because the fleet flake sits at the
repository root. I treated the spike's layout as fixed and platform code as the thing that
must adapt. Moving the fleet flake to `nix/` would have removed the blocker with zero
platform changes. I never enumerated that option until the user asked.

**3. I hardened tests without checking that any test runs.** In round 3 an oracle found
that CI executes 0 of 1265 bats tests: the workflow uses the default devShell, which has
no GNU `parallel`, so `bats --jobs` runs nothing, and the step sets
`continue-on-error: true` (bead `xoff`). A second oracle found that no required status
check on `dev` can fail at all (bead `ssjm`). Two fix rounds went into the coverage of a
suite that gates nothing. Checking the gate first costs one command.

**4. I recommended a transport on a contaminated probe.** I reported that `git+https`
authenticates with the netrc robots already carry, and the user chose it on that evidence.
The probe was contaminated by this workstation's ambient `~/.netrc`. Sterile, nix's
`netrc-file` never reaches the `git` CLI that nix shells out to, and the only PAT in sops
is aethon-scoped. The slice pivoted twice mid-round before landing on a `git+ssh` host
alias. An implementer caught this, not me.

**5. Two of my briefs caused blockers.** I told the identity implementer to assert against
a `controllerPush`-disabled host. It did, and thereby stopped testing the shape 29 of 31
robots actually have. I also set an acceptance criterion that could not be satisfied: an
identical drvPath against a lock pinned to an orphaned commit that no remote ref carries.

Smaller process defects: I dispatched five oracles into a shared `eval` kernel with no
isolation requirement, and two clobbered each other's path variables. I ran `bd update`
with an invalid flag, which aborted the whole command, so the bead kept stale acceptance
criteria until an oracle caught it.

## What the round found instead

Eight pre-existing defects, five at P1. None were in scope. All rest on an executed probe.

| Bead | Defect |
|---|---|
| `xoff` | CI executes 0 of 1265 bats tests; the failure reads as success |
| `ssjm` | No required status check on `dev` can fail (`if: false`, plus `continue-on-error`) |
| `y8w9` | Fleet repo would deploy r218 as `r000-pc`; the real profile is stranded and undiscovered |
| `s822` | The `github:` fallback drops `dir=`, so it has never worked on any robot |
| `9dar` | `eval_failed` exits 0 with no Slack, which is what kept `s822` invisible |
| `3v84` | Per-robot values interpolate unquoted into the shipped operator binary |
| `gd5y` | `BUILD_ON_TARGET` is set in the unit but not baked, so the operator path can diverge |
| `a0id` | Filed by me, then closed: an oracle falsified its premise |

`xoff` and `ssjm` together mean this repository has not been gated for some time. That is
worth more than the round's code.

## What worked

- **The oracle pairs caught everything.** Fifteen verdicts, every finding tied to an
  executed probe. One slice reached an APPROVE on one seat; its pair rejected the same
  commit, so it did not merge.
- **Differently-tasked pairs split.** The seats disagreed twice, and both times the
  disagreement was the useful signal. One seat executed the CI eval step and called it
  green; the other measured 21.96 GiB peak RSS against a 7.8 GB runner. Execution proved
  the commands work, not that they fit.
- **Probing beat reading.** The fatal defect in the fleet CI was `.nodes.platform-prod`,
  which is not valid jq — `-` lexes as subtraction. `actionlint` and `shellcheck` pass it,
  because jq programs are quoted strings. Only running it finds it.
- **Implementers escalated contracts instead of adapting.** One stopped on the orphaned
  base commit rather than inventing an interpretation. One asked before placing a new
  shared file. One found the contaminated netrc probe that invalidated my recommendation.
- **The process corrected the orchestrator.** Oracles caught my stale acceptance criteria,
  my unsatisfiable control, and my falsified bead.

## Lessons

1. **Ask whether a thing needs to exist before asking whether it is good.** A design
   finding about necessity is a scope question for the orchestrator. Do not resolve it as
   a quality question inside the slice.
2. **Enumerate both sides of an accommodation.** When component A must accept component B,
   list what could change in A and in B, then price both. A spike's layout is not a
   constraint.
3. **Verify the gate before investing in coverage.** Run the suite the way CI runs it, and
   confirm a nonzero executed-test count, before you require tests.
4. **State the isolation with every probe, or the probe is not evidence.** Contamination
   hit four times in one round: an ambient netrc, a warm nix fetcher cache, a shared
   interpreter kernel, and a `jq` that is actually `jaq`.
5. **Scope to where the value is, not symmetrically.** Two variables were wrong. One fed
   the primary path; one fed dead code. They got equal engineering.
6. **Require raw output for mutation claims.** Two "mutant verified RED" claims were green
   when oracles re-ran them. That cost two fix rounds.
7. **Verify your own tool calls, not just the agents'.** Three orchestrator slips of one
   family, each caught by an oracle rather than by me: a `bd update` with an invalid flag
   aborted the whole command, so stale acceptance criteria stood in front of three agents;
   an acceptance criterion pinned a drvPath against an orphaned commit that no remote ref
   carries; and this retro was first written to `nix/nix/docs/`, because the path was
   relative to a working directory already inside `nix/`.
8. **Brief the property, not a list of mutants.** The identity slice took four rounds. Each
   round closed every mutant the fix list named, and each time an oracle found a fresh
   escape of the same shape: a presence assertion that cannot see a deletion, an unordered
   bag of substrings, an unanchored block end. The fix lists enumerated instances. The
   brief should have stated the property — the rendered value must equal an exact
   end-anchored expected value — which closes the whole class in one assertion and is
   simpler than the patches. Per `skill://oracle-rounds` that pattern is Thrash, and Thrash
   is an orchestrator failure by definition.
9. **A test that asserts presence cannot defend a merged option.** `programs.ssh.extraConfig`
   is a `types.lines` option with two writers. One `lib.mkForce` deletes another module's
   block, passes every check, and reroutes root's GitHub identity to a personal key. Assert
   equality on merged values, not membership. Filed as `nl30`.
10. **"Execute, don't lint" must not become "execute instead of lint".** I added an
    acceptance criterion requiring every changed CI step body to be executed, because
    `actionlint` had missed a jq defect — it cannot parse a composite action at all,
    rejecting `action.yml` as a workflow with no `jobs`/`on`. The implementer then
    reported YAML and actionlint results and stopped running `shellcheck`. The next
    round shipped a step referencing `$secrets_dir`, assigned nowhere, dying at
    `git init -q ""` with rc=128 before any network call. `shellcheck` finds it
    instantly: exactly one finding, `SC2154`. Require both, and name both.
11. **A fold-in request can be implemented as a replacement.** I asked for one error
    annotation; the implementer replaced the block that happened to contain a variable
    definition. The blast radius of a one-line ask is not one line. Say what must be
    preserved, not only what must be added.
12. **Never relay an oracle's causal claim into a fix list as fact.** An oracle wrote
    that the robot's `/etc/nix/netrc` "carries only the cachix entry", so the `github:`
    fetcher has no credential. I put that sentence in a fix list as the required wording.
    The next oracle falsified it by executed probe: the robot netrc does carry a GitHub
    PAT (`secrets/layered-secrets.nix:152-160`), and an unset `nix.settings.netrc-file`
    means nix falls back to that exact default file. The 404 is real; the stated cause
    was not. Two of three blockers on that round traced to wording I supplied — the
    other was my instruction to "cite 9dar", which produced a paragraph attributing a
    tick, an eval and an `eval_failed` arm to a program that has none of them
    (`grep -c 'nix eval' controller-adopt.sh` is 0). A verdict's FINDING is evidence; its
    EXPLANATION may not be. Require the fix round to evidence the mechanism it states, or
    to state only the observed behaviour and the command that produced it.
13. **A suite can be structurally blind to exactly what ships.** Deleting the
    `PUSH_STATE_FILE` default left 223/223 green, because all 32 state-file tests export
    the variable themselves. The shipped binary aborts under `set -u` after switching the
    Pi, recording nothing. Tests that supply an input can never discover that production
    does not.
14. **A correct comment can be made wrong by narrowing it.** An oracle nit said a
    "fails closed" comment was over-claimed, because a numeric-but-out-of-range count
    clears the `case` and then errors in `[`. I relayed "narrow the comment". The rewrite
    demoted the guard to near-redundant — and the original sentence, recovered from
    reflog, was exactly right: without the `case`, a non-numeric count exits **0, green**,
    because `if` consumes `test`'s rc=2. A partial guarantee is still a guarantee. Ask for
    the second sentence, not a weaker first one.
15. **Predicting a defect in a brief does not prevent it.** I asked the reviewer whether
    anything invoked the new binding auditor, precisely because an unexercised gate is not
    a gate. Nothing invoked it, and it shipped calling itself a gate anyway — in a file
    that strikes another mechanism on the grounds that "an unexercised skip hatch is a
    trap". A predicted failure belongs in the acceptance criteria, or the thing belongs
    deleted. A question in a brief is not a control.
16. **A claim transported without its evidence is the same failure whether it is mine or
    an implementer's.** "Verified in-file at HEAD" was an assertion, not a check, and the
    edit had never been made — claimed twice, absent twice. My "the `github:` fetcher has
    no credential" was a cause I supplied that nobody probed, and it was the wrong
    explanation three rounds running. One mechanism: a claim moved from one head to
    another while its evidence stayed behind. The hunk-or-md5 rule for edits and the
    raw-output rule for mutations are the same rule applied to two kinds of work.
17. **Pick evidence by what it rules out, not by how strong it looks.** 225/225 and 7/7
    held identically on both sides of a comment-only hunk, so a green suite was never
    capable of distinguishing "landed" from "not landed" — yet it was what got offered.
    Three parties argued about whether that edit existed, and two oracles contradicted
    each other on it; an md5 across the lineage settled it in seconds. When the claim is
    *did this change*, hashes answer it and prose does not.
18. **A well-fitting explanation is still an inference.** The harness demonstrably
    destroyed uncommitted work from `df7457d` through `bc55c86`, and it did eat a real
    `PUSH_STATE_FILE` restore during the round. I extended that to "it ate the `:98` edit"
    and stated it as established; the second absence proved the edit had simply never been
    made. Best-supported is not verified. That is lesson 12 turned on its author.
19. **A list-shaped brief produces a list-shaped fix, and the property survives.**
    Criterion 4 was rejected seven consecutive rounds, and each round corrected the
    sentence it was handed and left another statement of the same disproven claim. Round
    7's brief was mine: "land `:98` and `:1192-1193`" — the two grep hits for the token
    `per-rev`. The token reached 0/0/0/0 across four files; the paraphrase survived in the
    only surface an operator reads, contradicting a `FILES` entry corrected in the same
    commit. Lesson 8 already says this. Writing a lesson down is not learning it — the
    test is whether the next brief is shaped by it, and mine was not.
20. **You can be given exactly what you asked for and lose what you did not name.** After
    a seat found the built-bin test could write `/var/lib`, I mandated a host-safe
    restructure. I got host safety: the replacement pins the default by grepping the
    shipped bin for that default's own literal — a copy of the value, not a test of it —
    and exports the variable in the leg that runs. The version it replaced ran the tick
    with the variable unset and died on `set -u`, which is the shipped incident in lesson
    13. Name what must survive a change, not only what must stop.
21. **A decision not to act is a claim, and needs the same probe as a decision to act.**
    I declined to restore behavioural coverage of a default because "the SC2154 gate
    covers the class more broadly, so the protection moved rather than vanished." That is
    a testable hypothesis and I ruled on it untested — in the same hour I wrote lesson 16
    about an implementer doing exactly this. SC2154 flags a variable referenced and never
    assigned; it is not flow analysis, so an assignment relocated below its first use is
    invisible to it, and `grep -F` passes for the same reason. That mutant is green on
    225/225, green on the fatal lint gate and green on the mutation harness, while the
    shipped binary dies on every robot with `PUSH_STATE_FILE: unbound variable` and
    records nothing. One probe was available and I ruled without it. Orchestrator rulings
    get no exemption from the evidence rule that binds implementers, and the cost of this
    one would have been paid in fleet rather than in rounds.
22. **A per-slice gate cannot see a defect that no slice owns.** Twenty-plus oracle
    reviews approved this round slice by slice. The composition gate then found that the
    fleet repo's robot state is a stale fork of the platform's: cutting over would have
    downgraded 42 robots — apollo `2.55.0 -> 2.52.0`, and aethon `on -> off` on 16
    controllers. No slice was wrong; no slice owned fleet state. Every gate that reviews
    parts needs one gate that reviews the whole, and it has to run before the thing ships,
    not after it breaks.
23. **"Did it change?" is not "did it change in the right direction?"** The round's
    acceptance evidence was "42/42 configurations evaluate" and "42/42 toplevels move". A
    downgrade evaluates and moves exactly like an upgrade, so both measurements were
    structurally incapable of detecting the defect above, and I ran them myself and read
    them as success. When a check cannot distinguish the outcome you want from the one you
    fear, it is not evidence, however green it is.
24. **An inherited explanation is still an unchecked claim.** I accepted a precedent —
    "every toplevel moves because shared platform content is in every closure" — and
    repeated it when all 42 moved. The truth was 2 differing derivations out of 3470: one
    secret appended to a shared sops file, whose store path sops-nix embeds in every
    consumer's `manifest.json`. Give it its own file and 21 Pis stop moving. A sops file
    is a unit of cache invalidation, not only of encryption.
25. **Describing what to work on is not describing where.** Three separate collisions this
    round, all mine, all the same shape: five oracles sharing one `eval` interpreter and
    silently overwriting each other's globals; two implementers both handed `comin.nix`;
    three implementers all told "Platform worktree" and pointed at one checkout. Each time
    I specified the task precisely and the isolation not at all, then assumed isolation I
    had not provided. Parallel work needs an explicit place per worker — a worktree, a
    scratch dir, a kernel — named in the brief, or the agents discover the collision for
    you, at best.
26. **A fix can be more dangerous than the bug.** The cutover-wedge guard was correct in
    its own logic and would have deadlocked systemd on all 21 PCs at once: it restarts
    comin while declaring `Before=comin.service`, and comin is the parent of
    `switch-to-configuration`, which calls `systemctl restart` blocking, with
    `TimeoutStartUSec=infinity`. The wedge it prevents costs an SSH round; the deadlock it
    caused costs an SSH round *and* a half-applied activation. When a fix touches
    activation ordering or deletes state, the question is not "does it work" but "what
    does it do when it goes wrong, compared to doing nothing at all".

## Where the work stands

- `slice/comin-target` at `281b7a2` holds the parser in history. If `s822` ever wants a
  derived flake base, it is there. The descoped commit keeps the subdir derivation, the
  `${VAR-}` unset-only form, the operator-binary bake, and the man-page repair.
- `slice/platform-transport` at `47869ca` and `slice/comin-identity` at `af517a7` are in
  review.
- Wave 1 (the binary-cache gate, bead `cdup`) has not started. It needs a
  `CACHIX_AUTH_TOKEN` value and an org-level runner grant, neither of which the harness
  can obtain.
