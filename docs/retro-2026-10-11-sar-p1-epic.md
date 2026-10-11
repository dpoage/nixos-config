# Retro: the sar_build P1 epic, rounds 2.5, 2.6 and 3, 2026-10-07 to 10-11

An arbiter session drove the P1 epic of `sar_build` (a Rust voxel ship simulator) through
oracle-gated rounds, each run by an architect subagent (`skill://arbiter-architect`).
Three rounds landed on main in about 98 hours of wall time: 2.5 (volume-graph water and
air flow), 3 (Godot testbed) and 2.6 (flow-tick optimisation). The code was correct
and the testbed impressed the user. The flow budget was missed in both windows, and the
user flagged slow progress three times.

This retro is the evidence behind the 2026-10-11 changes to `oracle-rounds`,
`arbiter-architect`, `premortem` and the agent defs. The casebook cites it as "sar".

## Sources

The raw records live outside this repository and may be deleted:

| Record | Path |
|---|---|
| Round ledgers (every verdict, ruling, incident, with times) | `~/.cache/sar-P1R{2,25,26,3}Architect-notes/*-ledger.md` |
| CP3 reports (deviations, wall time per phase) | `~/.cache/sar-P1R{25,26,3}Architect-notes/cp3*.md` |
| Arbiter rulings, spawn briefs, lane rules | `~/.cache/sar-arbiter-notes/` |
| Handoff files | `sar_build/.cache/handoff-p1-*.md` |
| Arbiter session | `~/.omp/agent/sessions/-code-personal-sar_build/2026-10-07T16-12-03-619Z_01a11722-*.jsonl` |

The figures below come from those records. Ledger line numbers are cited as `ledger:N`.

## Outcome

| Round | Landed | Result |
|---|---|---|
| 2.5 | `4c1bb6f` | Flow correct to within 3% of an exact calculation. Flow tick ~283 ms p99 open, ~857 ms flooded, against a 1.0 ms goal (D-061, failed) |
| 3 | `e679acf` | Testbed renders every claim world. Needed a post-polish VIEW slice after the arbiter's own look at the contact sheets |
| 2.6 | `3e307b3` | Bit-identical optimisation, ~22× faster open. 13 ms open, 44–56 ms flooded, against a 6 ms budget (D-061 (b), missed) |

## Where the time went

Compute was never the bottleneck. The local load stayed near 0.2 while three remote
workspaces ran every build. The time went to agent turns run in sequence.

| Sink | Evidence |
|---|---|
| Fix loops on one seam | Round 2.5 ran about 22 fix rounds; about 10 sat on the flow seam. One fixer ran about 23 hours |
| Waiting on other lanes | Rounds 2.6 and 3 each waited about a day for 2.5 to land. Merging 2.5's late fixes into 2.6 took a 7h35m slice (`ec03e3b` + fix) |
| Wave barriers | Wave 1 of 2.5 sat idle about 2 hours behind a slice it did not depend on |
| Prose-only REJECTs | 6 of 2.5's first 10 REJECTs; each cost a 40–80 minute fix round with a full re-gate |
| Seat latency | Verdicts took 50 minutes to 2 hours each; one seat took 9h11 |

The code for wave 0 of 2.5 was committed in the first hour. At hour 7 the wave had
still merged nothing.

## Lessons

### 1. Rulings stayed in project notes

Every process fix of the epic was ruled mid-flight and written into a lane file or a
spawn brief: per-slice merge, the scripted gate, prose to polish, the 60-minute chase,
standing merge authorization, re-timing after merges, whole-path spike timing, and the
hygiene rules. None reached the skills. Each successive architect brief grew by the same
additions. R9 had no step that moved a ruling back into the reusable process.

### 2. Gate cost did not follow change size

- Wave barriers made every slice wait for the slowest one.
- A wording fix re-ran the full pre-screen, the claims suite and the mutant legs.
- Nits batched into a fix round grew into 210 lines of code that then needed full review.
- The pre-screen agent passed 5 of 5 times in 2.5 and never had a REJECT upheld in
  three rounds. Its sunset clause dropped it; a scripted gate replaced it.

After the arbiter's rulings, round 3 absorbed about 5 prose REJECTs with zero fix rounds,
and four carried prose blockers in 2.5 cost one docs-only round.

### 3. Measurements did not cover what the budget named

- **Spike scope.** S-09 timed its own flow step on a damaged ship rolling ±2°: 2.29 ms
  p99. Production also computes water mass (81–93% of the tick, D-062) on an open hull
  in a full sea. The gap was about 124×. The 1.0 ms budget came from the spike figure.
- **No re-time after merge.** Round 2.6 met its budget at `fe2be43` (3.9–4.5 ms p99).
  Merging 2.5's late fixes moved one air walk from 0.43 to 6.53 ms mean. Nothing
  re-timed until the final measurement, so 2.6 shipped at 13 ms.
- **Metric without discrimination.** Round 3's first colour metric for "dry vs swamped"
  read ΔE 37.2 against 34.9 for its mutant.

### 4. Parts were gated before anything called them

The flow slices passed both seats while the sim did not yet step flow. The claim worlds
could not see their defects (ledger, gate on `150f9be`). After wiring, a flood probe the
architect improvised found water levels running away to 786–945 m. The fix chain that
followed (FlowFix r1, r2, AirFix, CompFix) ran from Thursday 09:31 to Saturday 13:15.

### 5. Undefined terms caused most of the rework

"Open space" meant any set that was not a compartment. Both seats rejected on it, and a
2h15m fix round followed. At least three more full rounds traced to wording the
architect logged as "brief gap, mine". One seam contract was revised three times; one
revision was the arbiter's own wording.

### 6. Hygiene rules lived in briefs

- Relative paths wrote into the user's checkout in three rounds, including after briefs
  gained a cd/pwd PRECONDITION. Once the edit tool resolved a worktree path to the
  user's checkout.
- `pkill -f` killed sibling workers' test runs twice.
- An orphaned Xvfb inherited the shared lock fd and held the machine for 3h22m.
- Remote build names left behind filled the pool's disks twice. One pre-screen created
  about 20 names against a brief limit of 3.
- A merge slice squashed merge ancestry, which caused an 11-file conflict on the next
  main merge.

### 7. File-disjoint lanes shared an unlanded base

Rounds 2.6 and 3 touched disjoint files, so the lanes passed the "fully disjoint" test.
Both built on 2.5 before it landed. The cost came through the base: a day of waiting
each, the re-freeze slice, seat re-reviews, and a "review 2.5 and 2.6 as one unit"
ruling that was built and then abandoned.

### 8. Status and estimates were not measured

The arbiter once reported a slice still waiting on seat B from the architect's last
message; the ledger showed both APPROVEs hours earlier. ETAs given from implementation
time slipped more than 2×: on Thursday 2.5 was 8–12 hours away, and it landed on
Saturday night.

### 9. Rules accumulated in one subsystem

To close seat blockers, the flow solver gained exterior classification, promotion
through openings, venting, bubbling, trapped-air pressing, thin air groups, residual
routing and vacuum handling. Most fix rounds lived in their interactions. Their
per-step graph walks became most of the remaining cost. No gate asked whether the model
should be simpler. The user asked after the epic, and round 2.7 opened as a design spike
for one fidelity-tunable model.

### 10. A human look caught what the seats missed

Every round-3 slice passed review. The arbiter's own look at the rendered sheets found
the sea drawn inside dry hulls, retained water indistinguishable from the sea, and an
air pocket never on screen. The fix cost about 7h51m after polish. The user's own run
of the testbed later reset the direction of the project.

## What worked

- **Premortem.** Round 2.6's three seats took about 1h45 and showed the plan's 4.07 ms
  figure was a fast-core number; the true figure was 8 ms.
- **Loop-cap triage.** It fired four times. Each time a property-form re-brief, or a
  spin-out to the owning slice, closed the loop in one more round.
- **Root-cause fixes to tooling.** The remote runner reused stale build output through
  preserved mtimes. The fix (`rsync --checksum`, no `-t`) came with a reproduction, and
  every run under the old names was redone.
- **Speculative branches** from approved, unmerged hashes cut serialization in 2.5.
- **The arbiter's CP3 audit** was the only gate that caught the visual gap.

## Changes made

| Lesson | Change |
|---|---|
| 1 | R9 requires promotion at round end; procedure step 12; `arbiter-architect` CP3 promotion |
| 2 | Dispatch on dependency (step 5); scripted gate and 60-minute chase (step 6); prose never starts a fix round (step 7); per-slice CP2 and standing authorization; `prescreen` def and role removed |
| 3 | R4 measurement clause; brief checklist; re-measure after each merge (step 8); premortem families 6 and 7 |
| 4 | R7 extends to wired paths; step 3 names the probe, step 8 runs it |
| 5 | R4 term clause; brief checklist; premortem family 6 |
| 6 | R8; workspace hygiene and merge ancestry in the `implementer`, `implementer-max` and `oracle` defs |
| 7 | R3; step 3 prices reintegration; `arbiter-architect` lane rule |
| 8 | R5 covers status; `arbiter-architect` conduct |
| 9 | R2; necessity checks; premortem family 3; CP1 accumulation check |
| 10 | Step 8 user-facing look; artifact criteria in the brief checklist and premortem family 6 |
