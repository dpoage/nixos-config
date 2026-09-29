# Oracle-Gated Rounds: Casebook

Incidents from past rounds, filed under the rule in `SKILL.md` that each one shows. This
file adds no rules. Read an entry when a rule's reason is unclear, or when you judge
whether a new incident repeats an old one (R9).

Sources: the fleet-cutover round retro (`docs/retro-2026-09-21-fleet-cutover-round.md`,
lessons cited as L<n>) and the apollo `d52-r2` round ledger
(`apollo-wt/shm-pool-core/.cache/d52-ledger-r2.md`).

Each entry states what happened, its cost, and the rule it shows. An entry marked
**candidate** records a failure seen once; a second occurrence can promote it to a rule.

## R2: scope

- **A parser for dead code** (fleet, L1, L5). A slice derived `GITHUB_FLAKE_BASE` with a
  URL-grammar parser in Nix. The parser only fed a fallback branch that had never worked
  on any robot. Three of five open blockers came from the parser. The necessary fix was
  about two lines. The orchestrator ruled "is the parser good?" instead of "does it need
  to exist?".
- **A frozen spike layout** (fleet, L2). The slice treated the fleet flake's location as
  fixed and changed platform code to match. Moving the flake to `nix/` removed the
  blocker with zero platform changes. Nobody priced that option until the user asked.
- **A replacement criterion dropped the old one** (fleet, L10). "Execute every changed CI
  step" was added after `actionlint` missed a jq defect. The implementer stopped running
  `shellcheck`. The next round shipped an unassigned `$secrets_dir` that `shellcheck`
  flags as SC2154.
- **A fix worse than the bug** (fleet, L26). A cutover-wedge guard restarted comin while
  ordered `Before=comin.service`. On all 21 PCs, it would have deadlocked systemd during
  activation. The wedge it prevented costs one SSH round.

## R3: slicing

- **Three change kinds in one slice** (d52-r2 S2, candidate). S2 carried 3 beads,
  8 properties, 61 base tests to move to a new call surface, and 13 carried doc findings.
  One property asked the implementer to move the tests and to rewrite their `notify_gap`
  assertions as `LossSink` totals in the same pass. On that property, a changed
  assertion can be a refactor regression or a requested change, and the diff does not
  say which. The implementer run was overloaded before any seat saw it.
- **Commit staging inside one slice** (d52-r2, first delivery attempt, candidate).
  `slice/d52r2-delivery` staged its work as commits C1 and C2 in one slice. The slice
  reached 2534 added lines and was re-cut; later slices kept parts of it only as salvage.
  Ordering commits did not bound one implementer's load.

## R4: criteria

- **A list-shaped brief survived seven rounds** (fleet, L8, L19). Each fix list named the
  cited sites, and each fix closed exactly those sites. The false claim survived in the
  one surface an operator reads. One end-anchored equality would have closed the class.
- **A presence assertion missed a deletion** (fleet, L9). `programs.ssh.extraConfig` has
  two writers. One `lib.mkForce` deleted the other module's block, passed every check,
  and rerouted root's GitHub identity to a personal key.
- **A test suite supplied the input production lacked** (fleet, L13). Deleting the
  `PUSH_STATE_FILE` default left 223/223 green, because every test exported the
  variable. The shipped binary aborted under `set -u`.
- **A fold-in became a replacement** (fleet, L11, L20). A request for one error annotation
  replaced the block that held a variable definition. A request for host safety removed
  the leg that ran with the variable unset. Both briefs named what to add and not what
  must survive.
- **The gate gated nothing** (fleet, L3). CI executed 0 of 1265 bats tests, and no
  required check on `dev` could fail. Two fix rounds bought coverage of a suite that
  gated nothing.

## R5: evidence

- **A relayed cause was false** (fleet, L12). A fix list carried an oracle's sentence
  that the robot netrc "carries only the cachix entry". The next oracle found a GitHub
  PAT in that netrc. Two of three blockers in that round traced to wording the
  orchestrator supplied.
- **"Verified in-file" twice, absent twice** (fleet, L16, L17). A green suite held on both
  sides of a comment-only hunk, so the suite could not show whether the edit landed. An
  md5 across the commit lineage settled the question in seconds.
- **An untested ruling** (fleet, L21). The orchestrator declined to restore coverage
  because "SC2154 covers the class". SC2154 does not see an assignment moved below its
  first use. That mutant passed every gate, and the shipped binary died on every robot.

## R6: seats

- **Seats tasked differently disagreed usefully** (fleet, "What worked"). One seat ran
  the CI eval step and called it green. The other measured 21.96 GiB peak RSS against a
  7.8 GB runner.

## R7: the whole

- **Every slice approved; the composition would downgrade 42 robots** (fleet, L22, L23).
  The fleet repo's robot state was a stale fork of the platform's. No slice owned fleet
  state. The acceptance evidence, "42/42 evaluate and move", reads the same for an
  upgrade and a downgrade.

## R8: named places

- **Shared kernel, shared checkout** (fleet, L25). Five oracles shared one `eval`
  interpreter and overwrote each other's globals. Two implementers were both handed
  `comin.nix`. Three implementers were told "Platform worktree" and pointed at one
  checkout.
- **A contaminated probe** (fleet, L4). A recommendation that `git+https` authenticates
  with the robots' netrc rested on this workstation's ambient `~/.netrc`. The slice
  pivoted twice. Contamination hit four times in that round: an ambient netrc, a warm
  fetcher cache, a shared kernel, and a `jq` that was `jaq`.
