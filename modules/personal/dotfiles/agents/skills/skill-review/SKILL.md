---
name: skill-review
description: Use when reviewing agent skills, agent definitions, or omp rules (SKILL.md and its files, omp agent defs, rule files), whether one new skill, an edit to one, or how a set of skills composes into roles. Read-only on the repository; judges whether each skill makes sense and does its job (including a dry run by the agent that loads it), checks it against skill-authoring best practices, traces what each role loads, checks ownership of shared facts, triggers, and wiring, and probes technical claims with real toolchains. Trigger on "review this skill", "skill review", "second opinion on the skills", "does this skill make sense", "check the skill flow". Not for writing skill prose (`doc-writer`) or reviewing code design (`design-review`).
---

# Skill Review

A skill is code that runs in a model's context. Review it like code: what loads it,
what it loads, what it asserts, and whether each assertion is true. Every finding
cites a file:line plus a quoted line, a load trace, or an executed probe. Mark a
finding from reading alone as [INFERENCE].

The review is read-only on the repository and on the machine. Work in a scratch
directory under `/tmp` named for the change (`/tmp/skill-review-<short-sha-or-branch>/`),
and delete it before you finish. If a probe or a dry-run agent writes anywhere else
(a crash dump or cache in the repository, a toolchain component, a file under
`$HOME`), undo the write if you can and report it either way.

## Review unit

1. List the changed files with `git status --short` (or the commit range your brief
   names): tracked edits plus every untracked skill, agent definition, and rule file.
2. Add every skill, agent definition, rule, and procedure that names a changed skill,
   bare or as `skill://`. Search the whole dotfiles tree.
3. List the roles that can reach the unit: agent definitions with `autoloadSkills`,
   the briefs that orchestration skills write (skill tables, seat tables), and
   top-level sessions that a description trigger matches.

## Conventions under test

Owned by `doc-writer`, "Skill files":

> - A skill never tells its reader to load another skill. The brief, the agent
>   definition, or the user decides what loads.
> - Name another skill bare (`design-review`) and only to route: "Not for X
>   (`design-review`)." A `skill://` URI is a load instruction. Use one only for the
>   skill's own files (`skill://oracle-rounds/procedure.md`), and in orchestration
>   skills and agent definitions that write briefs.
> - Make a skill complete for its role. When it needs a fact that another skill owns,
>   copy the fact verbatim, in quotes, and name the owner (`owned by bug-hunt`). Never
>   paraphrase or copy a subset; a partial copy drifts from its owner.
> - Triggers in the description cause loads. Name explicit phrases and concrete tasks.
>   Never trigger on a code shape that matches most edits.

## Probes

Run every probe in all three groups. Record the raw result of each before you write
findings. Probes A1–A4 ask whether the skill is worth loading at all; answer them
first, because a skill that fails them makes the rest moot.

### A. Does the skill make sense

A1. **Purpose.** From the first screen of the body alone, write one sentence: the job
    the skill does, for whom, and what it produces. Compare that sentence with the
    description. A body you cannot summarize in one sentence, or a sentence that needs
    "and" between two jobs, is SHOULD-FIX (split or cut). A body that contradicts its
    own description is BLOCKING.
A2. **Necessity.** For each section, ask whether the model that loads the skill
    already knows it. Mark each section as one of: new fact (keep), project decision
    the model cannot guess (keep), or general knowledge (cut). More than a quarter of
    the body in general knowledge is SHOULD-FIX. Name the sections to cut. Ground the
    marks in the A4 baseline when one exists. A baseline that ran on a different
    model from the role's primary model grades necessity for that model only; mark
    the result [INFERENCE] for the primary.
A3. **Actionability.** For each instruction, check that a reader can act on it and
    knows when it is done: a command, a decision rule, an output, or a threshold.
    Check that the degree of freedom matches the risk: exact steps for fragile or
    irreversible operations, heuristics where many approaches work. Check that every
    verdict, grade, or threshold the skill asks for is decidable from evidence the
    reader can collect. An instruction that cannot be acted on, or a gate that cannot
    be decided, is BLOCKING when a role depends on it, and SHOULD-FIX otherwise.
A4. **Dry run.** Test the skill the way it is used.
    1. Before running anything, write three scenarios: two representative tasks the
       skill exists for and one near-miss it must not change. Keep each small enough
       to finish in a `/tmp` scratch repository. For an edit that changes only
       wording, one scenario is enough. For an orchestration skill, dry-run one step,
       not a whole round. For each scenario, name the property the skill claims to
       improve and a measure of it on the artifact, for example invalid states
       reachable through the public API, construction paths that skip the parser,
       distinct failure cases a caller can match on, or blockers a seat would raise.
       Completing the task is not the measure: a baseline usually completes it too.
    2. Dispatch each scenario as the agent that loads the skill in production (for
       example `implementer`, `oracle`, `sweeper`), so it runs on that role's model.
       The brief names the skill the way production does (an absolute file path for
       a skill that is not installed yet), states the task and its acceptance
       criteria, and ends with this paragraph verbatim: "Dry run in a scratch
       repository at `<path>`. Ignore bead, worktree, and branch steps in your
       instructions. Do not install or upgrade toolchains, and write nothing outside
       `<path>`. If a step needs something missing, report it and stop."
    3. For a new skill, run one representative scenario a second time without the
       skill as a baseline. Its brief is the same task and acceptance criteria and
       nothing else: no skill vocabulary, no output format the skill defines.
    4. Read the model each run actually used from its transcript (`history://<id>`).
       A run that fell back to another model counts only for that model; report the
       fallback, and do not count the run toward the role's primary model in B7.
    5. Grade by reading the artifact the run produced (code, diff, reply evidence),
       not the run's description of it, and cite its `history://` link. When a
       baseline exists, take each measure on it and the skill run side by side. A
       run that does the wrong thing because of the skill (wrong instruction, missed
       rule, wrong output) is BLOCKING. A run that hesitates, asks, or reads
       unrelated files because the skill is unclear is SHOULD-FIX. A baseline whose
       measures equal the skill run's is a SHOULD-FIX finding under A2; a baseline
       that only shares the skill run's patterns is not.

### B. Best practices

The source is Anthropic's skill-authoring guide
(<https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices>).
omp adds its own discovery rules (`omp://skills.md`). Check each item and cite the
line that fails it.

B1. **Frontmatter limits (BLOCKING).** `name`: at most 64 characters; lowercase
    letters, digits, and hyphens only; no XML tags; not containing `anthropic` or
    `claude`; equal to the directory name. `description`: non-empty; at most 1,024
    characters; no XML tags. Validators such as omp's Agent Plugins loader reject
    skills that break these.
B2. **Description quality (SHOULD-FIX).** States what the skill does and when to use
    it, in third person or as "Use when …" (never "I" or "you"), with the key terms a
    task would contain. A vague description ("Helps with documents") fails.
B3. **Size and structure.** The `SKILL.md` body is under 500 lines (SHOULD-FIX).
    Detail the reader needs only sometimes lives in separate files that `SKILL.md`
    links directly: one level deep, never a file that links to a further file
    (SHOULD-FIX). A reference file over 100 lines starts with a table of contents
    (NIT). Files are named for their content, with forward-slash paths (NIT).
B4. **Content (SHOULD-FIX).** No time-sensitive statements ("before August 2025",
    "the latest version") outside a clearly marked old-patterns section. One default
    approach, with an escape hatch, instead of a menu of equal options. Examples are
    concrete input and output, not abstract descriptions. One term per concept.
B5. **Workflows.** A quality-critical procedure has a feedback loop: run a check,
    fix, repeat until it passes (SHOULD-FIX). A complex one has a checklist the
    reader can copy and tick (SHOULD-FIX). A multistep procedure written as a
    paragraph instead of numbered steps is NIT.
B6. **Scripts (SHOULD-FIX, when the skill bundles code).** Scripts handle errors
    instead of deferring them to the model, justify every constant, list their
    dependencies, and the instructions say whether to run a script or read it.
B7. **Tested (SHOULD-FIX).** The skill has been exercised on representative tasks
    with each model that loads it. Probe A4 supplies this evidence for the review;
    report which roles' models it covered.

### C. Does the skill compose

C1. **Mechanics.** Parse every frontmatter with a strict YAML loader (`yq`, or Python
   with PyYAML, for example through `nix shell`). A skill's `name` equals its
   directory. An agent definition's `name` and `description` are strings. A rule has
   no `name`; its filename is its name. Resolve every `skill://` target
   to a file. Check that every changed skill file, agent definition, and rule is
   installed by the repository's wiring (in nixos-config, a `home.file` entry in
   `common/home/dotfiles.nix`). A parse failure, a wrong `name`, a dead target, or a
   file that is not installed is BLOCKING.
C2. **Load trace.** For each role in the unit, list the files it loads, in order, with
   `wc -c` / 4 as a token estimate. Count the agent definition and the brief; leave
   out the harness's own system prompt. These are BLOCKING: a worker skill that tells
   its reader to load another skill; an instruction that a reader can follow only by
   reading another skill (it counts as a load instruction); a loop; a pointer to a
   missing section, step, rule, or probe number. A role that lacks a fact it needs is
   BLOCKING when the gap produces wrong code or a wrong verdict, and SHOULD-FIX
   otherwise. Name the fact and the file that owns it.
C3. **Ownership.** For each rule or fact stated in more than one file, name its owner.
   Two copies that contradict are BLOCKING. A copy that paraphrases, drops part of
   the owner's text, or omits the owner's name is SHOULD-FIX. Check each quoted copy
   against its owner with whitespace normalized.
C4. **Triggers.** No tool evaluates description matching, so this probe is reading
   only; say so in its result. For each new or edited description, write three tasks
   it must fire on and three near-miss tasks it must not. A trigger on a code shape
   that matches most edits is SHOULD-FIX. A trigger that misses a role's task is
   BLOCKING when no brief or agent definition loads the skill for that role.
C5. **Claims.** For each technical claim (flag, lint, or option name; API semantics;
   default; version), run a minimal probe with a local toolchain. If no toolchain
   exists, cite the primary documentation. Otherwise mark the claim [INFERENCE]. A
   wrong claim that leads to wrong code or a false verdict is BLOCKING. An outdated or
   imprecise claim is SHOULD-FIX.
C6. **Self-consistency.** Check that every example obeys the rules of the file it is
   in, that each concept has one term, and that the levels, thresholds, and tables a
   file defines agree with every place that uses them. Readers copy examples: an
   example whose copy produces a defect the file warns against is BLOCKING; an
   example that breaks a rule without producing such a defect is SHOULD-FIX.
C7. **Source fidelity.** When a skill distills an external source, sample enough of
   the source to check two things: every quote appears verbatim, and each central
   idea of the source appears in the skill. You need not find a source location for
   every rule. Additions must be labeled as additions. A misrepresented source is
   BLOCKING. An unlabeled addition is SHOULD-FIX.
C8. **Style.** Check the prose against the `doc-writer` rules. The `skill-reviewer`
   agent loads them with this skill. When they are not in your context, skip this
   probe and say so. Style findings are NIT unless a sentence can be misread.

## Output

1. Findings in three groups: BLOCKING, SHOULD-FIX, NIT. Each finding gives its probe
   ID, file:line, the problem, the evidence (probe output, quoted lines, a dry-run
   transcript, or a load trace), and a concrete fix written as target wording or
   structure.
2. The dry-run table: scenario, agent and model, expected behavior, observed
   behavior, grade, `history://` link.
3. The load-trace table: role, files loaded in order, tokens.
4. Three to five lines on whether each skill earns its place, whether the skills
   compose soundly, and what you would change structurally.
5. The model you ran as.
6. Final line: `VERDICT: APPROVE` when no BLOCKING finding stands, else
   `VERDICT: REJECT`.
