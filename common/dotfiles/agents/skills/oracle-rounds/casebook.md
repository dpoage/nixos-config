# Oracle-Gated Rounds: Casebook

Incidents from past rounds, filed under the rule in `SKILL.md` that each one shows. This
file adds no rules. Read an entry when a rule's reason is unclear, or when you judge
whether a new incident repeats an old one (R9).

Sources: the fleet-cutover round retro (`docs/retro-2026-09-21-fleet-cutover-round.md`,
lessons cited as L<n>), the apollo `d52-r2` round ledger
(`apollo-wt/shm-pool-core/.cache/d52-ledger-r2.md`), and the sar_build P1 epic retro
(`docs/retro-2026-10-11-sar-p1-epic.md`, cited as sar).

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
- **Rules accumulated until their interactions were the work** (sar 2.5, candidate).
  The flow solver gained exterior classification, promotion through openings, venting,
  bubbling, trapped-air pressing, thin air groups, residual routing, and vacuum
  handling, each added to close a seat's blocker. Most of about 22 fix rounds lived in
  their interactions, and their per-step walks became most of the tick's cost. No gate
  asked whether the model should be simpler; the user did, after the epic.

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
- **File-disjoint lanes on one unlanded base** (sar 2.6 and 3). Both lanes touched
  disjoint files and both built on round 2.5 before it landed. Each waited about a day
  for it. Round 2.6 then needed a 7h35m Heavy slice and two seat re-reviews only to
  merge 2.5's late fixes, and a "review 2.5 and 2.6 as one unit" ruling was built and
  then abandoned.
- **A wave waited for its slowest slice** (sar 2.5). Wave 1 needed two wave-0 slices
  that were approved by about 15:00. It sat idle about 2 hours behind a third slice
  that only fed wave 2. Dispatch on dependency removed the wait.

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
- **An undefined term in a property** (sar 2.5). "Open space" meant any set that was
  not a compartment. Both seats rejected on it, a 2h15m fix round followed, and at least
  three more full rounds traced to brief or contract wording the architect marked "brief
  gap, mine". One seam contract was revised three times mid-round.
- **A spike timed part of the path** (sar S-09 → D-061/D-062). The spike timed its flow
  step on a damaged ship rolling ±2°: 2.29 ms p99. Production's tick also computed water
  mass (81–93% of the cost) on an open hull in a full sea: 283 ms open, 857 ms flooded,
  about 124× over. The 1.0 ms budget had been set from the spike figure.
- **Met mid-round, missed after a merge** (sar 2.6). The optimisation met its 6 ms
  budget at `fe2be43` (3.9–4.5 ms p99). Merging round 2.5's late fixes moved an air walk
  from 0.43 to 6.53 ms mean. Nothing re-timed until the final measurement: 13 ms,
  shipped over budget.
- **A visual deliverable with no visual criterion** (sar 3, candidate). Every slice of
  the testbed round passed review. The arbiter's own look at the rendered sheets found
  the sea drawn inside dry hulls and an air pocket that was never on screen. The fix's
  first colour metric did not separate its mutant (ΔE 37.2 vs 34.9). Cost: a post-polish
  slice of about 7h51m.
- **A budget miss blamed on the wrong tree** (sar 2.8b B-3, K4). The composition read
  the tip's edit p99 over its 49.38 ms bar in 2 of 6 runs and attributed it to WALLS.
  Six interleaved runs in one quiet hold put main over the bar in 4 of 6 and the tip
  in 1. The tail predated the round.
- **A list grew past its pin** (sar 2.8b, Comp28c B1). B added `dry_heel_wake` to CI;
  no slice added its cross-libm golden row, so the golden covered 13 of 14 scenarios
  until composition. The fix shipped a guard test that fails when ci.yml gains an
  unpinned scenario.
- **A changed assertion lost its mutant** (sar 2.8b, PocketSeatB r1 B1). A granted
  rewrite of the guard-release leg widened its window; a 9.35 s guard timer passed the
  whole suite where 10 s was specified. A changed assertion names the mutant the old
  one killed and shows it still dies.
- **A pin on a chaotic trajectory was a coin flip** (sar 2.10b, LD3 probe). Flood legs
  pinned one run's peak at a named step. Under 1e-9° heel nudges, base failed its own
  gate in 30 of 32 runs, and base and tip were statistically indistinguishable. On a
  chaotic trajectory, judge the settled state plus an ensemble of nudged runs (tip and
  base on the same nudges, a rank test), never one run's value at one step.
- **A state variable judged by the variable it is bounded through** (sar 2.10a U-p,
  found in 2.10b). Seats approved a pipe law because water levels stayed sane, and the
  positivity pass guaranteed that. The flow q, which later slices read as momentum,
  reached 1.5e6 m/s. Judge a state variable by its readers.

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
- **A ruled guard that fired in production** (sar HULL, LOCATE-G). The arbiter specified
  `debug_assert!(rayon::current_thread_index().is_none())` around an index build. Every
  production structure solve runs inside a rayon pool, so the assert fired on the real
  path. A thread-local build permit replaced it. A mechanism a ruling names is probed
  on the production path before dispatch, like any other term.
- **A brief's figure named the wrong quantity** (sar HULL, LOCATE-P). The brief recorded
  a "4.02 MB table"; 4.02 MB was the whole lookup index. The seat caught it against the
  heap measurement.
- **An optional sentence reopened doc-truth** (sar P3-R1, polish S3). A non-gating
  rewording of `Link::send`'s doc added a claim no one probed; the seat showed it false
  for streams, and the doc-truth loop hit its cap. Optional prose edits get the same
  falsifying probe as gating ones, or they aren't made.
- **A quantity premise went stale at a merge** (sar P3-R1, sar-yd7). A scope ruling
  rested on "R1 constructs ≤ 32 KB"; HULL's landing brought a 138 KB world. Re-measure
  quantity premises after every main merge, not only when they were set.
- **A render mask that marked geometry, not what is seen** (sar VIS F1, O4). A "water
  pixel" mask made by painting the water magenta marks the mesh footprint, which a fade
  never changes, so the film check could not fail. Pass/fail masks come from the
  measured variant's own visible output (difference against the same frame with the
  effect hidden).
- **A measurement twin that the scene still shaded** (sar VIS FILM, OCEAN O2). Thickness
  and depth encoded as colour read wrong because fog and an air-pocket overlay blended
  into the twin. Twins turn off fog and every overlay, and forced-value probes (all 0,
  all 1, a known 6 cm) prove they read true before use.
- **Status from messages** (sar arbiter, candidate). The arbiter reported a slice still
  waiting on seat B, from the architect's last message. The ledger showed both APPROVEs
  hours earlier. ETAs given from implementation time slipped more than 2×; the
  remaining time was review rounds.
- **A gate that could not fail** (sar P3-R1, found by a P3-R2 premortem seat). The
  gate ran each multi-line step as `( body ) ; rc=$?` without `-e`, so only the last
  command's status counted. A fake tree whose `cargo test` exited 101 printed GATE
  GREEN. Fix: `bash -eo pipefail` per step, plus failure-signature grep; every gate
  script now ships with a fake-failure probe in local and remote mode.
- **A determinism alarm from the gate itself** (sar 2.8b, GateAccel). `sar determinism`
  reported Diverged twice under load. The binary hashes its own executable into each
  recording header, and a parallel archive extraction replaced `target/debug/sar`
  between the two passes. A one-byte exe swap mid-run reproduced it exactly. Legs that
  run a self-identifying binary use a private copy.
- **A premise relayed to the user was a calibration** (sar 2.10b LIFT). The architect
  called k = 1.5 "the published value"; the user chose on it. A seat checked the source:
  the published law is k = 1, and 1.5 was a transfer from another hull. Any "published",
  "standard" or "physical" claim put to the user carries its citation, checked by a seat
  before the question goes out.
- **Four gates on one slot** (sar, 10-30). The slot lock was a flock on the gate
  process's fd. Gates killed by tool-call timeouts freed it while their remote children
  ran for hours, and the next gate's partial pkill wiped their evidence. Slot ownership
  must outlive the process (a keeper, a verified nuke by cwd/session). Lanes killing
  `$!` after `setsid … &` hit the wrapper, not the gate: record the real PID.

## R6: seats

- **Seats tasked differently disagreed usefully** (fleet, "What worked"). One seat ran
  the CI eval step and called it green. The other measured 21.96 GiB peak RSS against a
  7.8 GB runner.

## R7: the whole

- **Every slice approved; the composition would downgrade 42 robots** (fleet, L22, L23).
  The fleet repo's robot state was a stale fork of the platform's. No slice owned fleet
  state. The acceptance evidence, "42/42 evaluate and move", reads the same for an
  upgrade and a downgrade.
- **Gated before anything called it** (sar 2.5). The flow slices passed both seats
  while the sim did not step flow yet, so claim worlds could not see them. A flood probe
  the architect improvised after wiring found water levels running away to 786–945 m.
  The fix chain that followed took about two days, more than half the round's fix time.
- **A composed gate replaced the slice gates, and a slice skipped its crate suite**
  (sar 2.10b PART). Seats ran the slice's targeted legs; the composed gate had not
  reached the crate's other suites, and two of them regressed. When one composed gate
  replaces slice gates, each slice runs its crate's full suite before composition.

## R8: named places

- **Shared kernel, shared checkout** (fleet, L25). Five oracles shared one `eval`
  interpreter and overwrote each other's globals. Two implementers were both handed
  `comin.nix`. Three implementers were told "Platform worktree" and pointed at one
  checkout.
- **A contaminated probe** (fleet, L4). A recommendation that `git+https` authenticates
  with the robots' netrc rested on this workstation's ambient `~/.netrc`. The slice
  pivoted twice. Contamination hit four times in that round: an ambient netrc, a warm
  fetcher cache, a shared kernel, and a `jq` that was `jaq`.
- **Hygiene in briefs, not defs** (sar rounds 1–2.6). Relative paths wrote into the
  user's checkout in three rounds, including after briefs gained a cd/pwd PRECONDITION;
  once the edit tool itself resolved worktree paths to the user's checkout. `pkill -f`
  killed sibling workers' tests twice. An orphaned Xvfb inherited a lock fd and held the
  shared machine for 3h22m. Remote build names left behind filled the pool's disks
  twice.

## R9: evidence changes the process

- **Rulings stranded in project notes** (sar). Per-slice merge, a scripted gate in
  place of the pre-screen, prose to polish, a 60-minute chase, standing merge
  authorization, re-timing after merges, and whole-path spike timing were all ruled
  mid-epic. All lived in round lane files and briefs; none reached these skills until a
  retro after the epic.
- **A gate retired by its own sunset clause** (sar 2.5). The pre-screen trial needed
  one upheld REJECT in three rounds to stay; it had none, and it added an agent turn of
  latency to every hash. A scripted gate running the same commands replaced it.
- **Prose blockers priced as code** (sar 2.5). 6 of the round's first 10 REJECTs were
  wording only, each a 40–80 minute fix round with a full re-gate. After prose moved to
  the polish list, four carried prose blockers cost one docs-only round.
- **Wall time bought with parallel seats** (sar 2.8b, P3-R1/R2, user directive). Seats
  spawned on a candidate hash in parallel with its gate, implementer-max on every fix
  round, and a build-once sharded gate runner (6h17m → 1h41m, identical test lists,
  fail-closed probe) cut each slice's wall time without changing any gate.
