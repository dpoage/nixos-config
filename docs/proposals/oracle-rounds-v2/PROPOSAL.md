# Proposal: restructure oracle-rounds and arbiter-architect

This proposal splits `oracle-rounds` into a short rule file, a procedure reference, and
a casebook. It also removes the rules that `arbiter-architect` copies from
`oracle-rounds`. Status: approved 2026-09-28 and installed under
`common/dotfiles/agents/skills/`; install steps 1–5 are applied, and step 6 (rebuild and
check) is pending. This file stays as the design record.

| New file | Replaces |
|---|---|
| `oracle-rounds/SKILL.md` | the rules in `common/dotfiles/agents/skills/oracle-rounds/SKILL.md` |
| `oracle-rounds/procedure.md` | the steps, tables, ledger, and report of the same file |
| `oracle-rounds/casebook.md` | the incident examples embedded in the same file (new file) |
| `arbiter-architect/SKILL.md` | `common/dotfiles/agents/skills/arbiter-architect/SKILL.md` |

## What changes

1. **Nine rules, each with its reason.** `SKILL.md` holds R1–R9 and nothing else. The
   architect autoloads this file, so the rules stay in context for the whole round.
2. **A separate procedure file.** `procedure.md` holds the steps, tables, and templates.
   The orchestrator reads it in full before step 1 (see "Loading"). Step numbers are
   unchanged, so references such as "step 3a" and "step 11" in `architect.md` still hold.
3. **Incidents become examples.** One-incident material (`mkForce`, "execute, don't
   lint", the d52-r2 S2 parenthetical) moves to `casebook.md`, filed by rule, with a
   source for each entry. The casebook is not normative.
4. **One home per rule.** The arbiter's CP1 audit now points at R2, R3, and R4 and keeps
   only arbiter-specific checks. The capability table exists once, in `procedure.md`.
5. **An admission rule (R9, new).** A rule enters `SKILL.md` only with outcome-ledger
   evidence or a second recorded occurrence of the same failure. A one-off incident goes
   to the casebook.
6. **An end condition for the pre-screen trial (new).** The trial ends after three
   rounds. The pre-screen stays only if a step 11 tally shows at least one upheld REJECT.
7. **The judge lints are cut** (ruled 2026-09-28). Two parts survive as plain text: the
   brief checklist names every skill the worker must load, and the loop cap defines a
   fix-introduced blocker by `git diff` hunk intersection.

The change-kind split added on 2026-09-28 stays in procedure step 3. Its casebook entry
is marked **candidate**, because the split was seen once.

## Measured size

| Text | Before (words) | After (words) |
|---|---|---|
| Always in context (the autoloaded `oracle-rounds/SKILL.md`) | 3263 | 762 |
| `oracle-rounds` normative total (rules + procedure) | 3263 | 3306 |
| `arbiter-architect` | 2261 | 1400 |
| Normative total, both skills | 5524 | 4706 |
| Casebook (not normative) | — | 907 |

The always-loaded text drops by 77% and the normative total by 15%. The procedure
carries almost every mechanism over unchanged; a mechanism leaves only on evidence (R9)
or on your ruling. The judge lints are the one ruled cut so far.

## Rulings

- Judge lints: cut.
- Pre-screen trial, loop-cap triage classes, the seat table rows, and the provisional
  caps: kept as drafted.

## Loading

Three facts decide whether agents see the new files. Each fact below was checked against
this machine or the harness docs.

1. **Nix installs only `SKILL.md` today.** `common/home/dotfiles.nix:10-27` links each
   skill's `SKILL.md` by name, one `home.file` entry per file. Without new entries,
   `procedure.md` and `casebook.md` never reach `~/.agents/skills/oracle-rounds/`, and
   every `skill://oracle-rounds/procedure.md` read fails. Installation step 2 adds the
   entries.
2. **The URL form resolves.** `omp://skills.md` ("`skill://` URL behavior"): 
   `skill://<name>/<relative-path>` resolves inside that skill's directory.
3. **Autoload injects `SKILL.md` only.** `omp://skills.md` describes the autoload format
   as the skill body plus `Skill: <path>`. `omp://task-agent-discovery.md` says
   `autoloadSkills` injects the named skills before the child's first prompt. Nothing
   injects `procedure.md`. The architect therefore reads it only on instruction. Two
   instructions cover this: `SKILL.md` says "Read `procedure.md` in full before step 1",
   and installation step 3 adds the same instruction to `architect.md`.

`omp://compaction.md` states that `read` results of `skill://` paths are never pruned.
So after one full read, `procedure.md` stays in the architect's context. Compaction by
summary is a separate process; it can still drop the file, as it can drop the current
`SKILL.md`.

What remains unverified: that an architect in a real round obeys the read instruction.
Installation step 6 is the check.

## Migration map

Every section of the current files, and where it goes. "Moved" means the content is
unchanged apart from wording.

### `oracle-rounds/SKILL.md`

| Current section | Destination |
|---|---|
| Intro (roles, never open PR) | `SKILL.md` intro + R1 |
| Epic pointer | `SKILL.md` intro |
| Step 1 Scope | procedure step 1; the scope principle is R2 |
| Step 2 Module map | procedure step 2 |
| Step 3 Slice (ownership, disjointness, substrate, seams, tiers, change kinds, caps) | R3 (principle) + procedure step 3 (checks) |
| Step 3a Premortem | procedure step 3a |
| Steps 4–5 | procedure steps 4–5 |
| Step 6 Gate + pre-screen | R6 (principle) + procedure step 6; trial end condition added |
| Step 7 Fix loops, audit, re-review, carry, escalation, loop cap | R6 (count cap) + procedure step 7. The re-review detail points at the `oracle` def, which already states it |
| Steps 8–11 | R7 (composition) + procedure steps 8–11 |
| Outcome ledger | procedure "Outcome ledger"; R9 uses it |
| Brief contract 1 (invariant, falsifier, closing form) | R4 + brief checklist; `mkForce` → casebook |
| Brief contract 2 (preserve clause) | R4 + brief checklist |
| Brief contract 3 (mutants, legs) | brief checklist; the leg definitions stay in `implementer.md` |
| Brief contract 4 (verify the gate) | brief checklist; the 0/1265 incident → casebook |
| Brief contract 5 (measure the claim) | R5 |
| Brief contract 6 (finding, not explanation; prose blockers) | R5 + brief checklist |
| Brief contract 7 (name the place) | R8 |
| Scope contract (scope, necessity, both sides, value, replace criteria, fix worse than bug) | R2 + procedure "Necessity checks"; the incidents → casebook |
| Oracle tasking (tier table, doc-truth seat, seat table, composition) | procedure "Tiers and seats" |
| Capability allocation | procedure "Capability allocation" (merged with the arbiter's table) |
| Judge lints | cut (ruled); skill naming → brief checklist; hunk-intersection provenance → loop cap |

### `arbiter-architect/SKILL.md`

| Current section | Destination |
|---|---|
| Intro, why the architect exists, topology table, switching, concurrency | kept, shortened |
| Capability table | procedure "Capability allocation"; the arbiter's row becomes one sentence |
| Spawning | kept; the escalation summary points at `architect.md` |
| CP1 audit: premortem, tiers, design directions | kept |
| CP1 audit: slicing, change kinds, disjointness, substrate, dependencies | one bullet citing R3 and procedure step 3 |
| CP1 audit: necessity, scope | one bullet citing R2 |
| CP1 audit: criteria falsifier | one bullet citing R4 |
| CP2, CP3, conduct | kept, shortened |

## Installation (after approval)

1. Replace `common/dotfiles/agents/skills/oracle-rounds/SKILL.md` with the draft, and add
   `procedure.md` and `casebook.md` beside it. Replace
   `common/dotfiles/agents/skills/arbiter-architect/SKILL.md` with the draft.
2. In `common/home/dotfiles.nix`, add one `home.file` entry each for
   `.agents/skills/oracle-rounds/procedure.md` and
   `.agents/skills/oracle-rounds/casebook.md`, in the existing per-file form.
3. In `common/dotfiles/omp/agents/architect.md`, add one sentence under the opening
   paragraph: "Autoload injects only `SKILL.md`. Read
   `skill://oracle-rounds/procedure.md` in full before step 1."
4. In `premortem/SKILL.md:21`, change "`oracle-rounds`, Oracle tasking" to
   "`oracle-rounds` procedure, Tiers and seats".
5. Commit `docs/retro-2026-09-21-fleet-cutover-round.md`; the casebook cites it and the
   file is untracked today.
6. Rebuild. Then check the result:
   - `skill://oracle-rounds/procedure.md` and `skill://oracle-rounds/casebook.md` resolve.
   - A throwaway `architect` spawn, told to stop before step 1, reads
     `skill://oracle-rounds/procedure.md` in full. Its transcript shows the read.

## Not in this proposal

The agent defs repeat the skill in three places. A second pass can remove the copies:

- `architect.md` lists the checkpoint contents, and the arbiter skill repeated them.
  The draft leaves `architect.md` as their only home.
- `implementer.md` defines the mutant legs, and the current brief contract 3 repeats
  them. The draft leaves `implementer.md` as their only home.
- `oracle.md` defines delta re-review, and the current step 7 repeats it. The draft
  leaves `oracle.md` as its only home.

This pass removes only the skill-side copies. The defs are unchanged.

## Risks

- **The orchestrator skips `procedure.md`.** A step it never reads is a step it never
  runs. `SKILL.md` and `architect.md` both require a full read before step 1. A skip
  still shows at a checkpoint: CP1 needs the tiers, the ownership map, and the
  premortem, and CP2 needs the triage records.
- **A direct-mode session reads only `SKILL.md`.** Without the architect def, only the
  `SKILL.md` instruction asks for the procedure read.
- **Casebook detail no longer reaches briefs.** Today the `mkForce` example sits inside
  the brief rule. After the change, the orchestrator reads it only when it opens the
  casebook. R4's falsifier still carries the rule.
- **R9 freezes a process that needs change.** R9 allows a rule on a second recorded
  occurrence, so a repeated failure still gets a rule, and you can override R9 at any
  time.
