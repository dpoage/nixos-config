---
name: skill-review
description: Use when reviewing agent skills, agent definitions, or omp rules (SKILL.md and its files, omp agent defs, rule files), whether one new skill, an edit to one, or how a set of skills composes into roles. Read-only; traces what each role loads, checks ownership of shared facts, trigger quality, frontmatter, and wiring, and probes technical claims with real toolchains. Trigger on "review this skill", "skill review", "second opinion on the skills", "check the skill flow". Not for writing skill prose (`doc-writer`) or reviewing code design (`design-review`).
---

# Skill Review

A skill is code that runs in a model's context. Review it like code: what loads it,
what it loads, what it asserts, and whether each assertion is true. Every finding
cites a file:line plus a quoted line, a load trace, or an executed probe. Mark a
finding from reading alone as [INFERENCE].

The review is read-only on the repository. Work in a scratch directory under `/tmp`
named for the change (`/tmp/skill-review-<short-sha-or-branch>/`), and delete it
before you finish. If a probe writes into the repository (a crash dump, a cache, a
lockfile), delete the file and report that you did.

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

Run every probe. Record the raw result of each before you write findings.

1. **Mechanics.** Parse every frontmatter with a strict YAML loader. A skill's `name`
   equals its directory. An agent definition's `name` and `description` are strings.
   A rule has no `name`; its filename is its name. Resolve every `skill://` target
   to a file. Check that every changed skill file, agent definition, and rule is
   installed by the repository's wiring (in nixos-config, a `home.file` entry in
   `common/home/dotfiles.nix`). A parse failure, a wrong `name`, a dead target, or a
   file that is not installed is BLOCKING.
2. **Load trace.** For each role in the unit, list the files it loads, in order, with
   `wc -c` / 4 as a token estimate. These are BLOCKING: a worker skill that tells its
   reader to load another skill; an instruction that a reader can follow only by
   reading another skill (it counts as a load instruction); a loop; a pointer to a
   missing section, step, rule, or probe number. A role that lacks a fact it needs is
   BLOCKING when the gap produces wrong code or a wrong verdict, and SHOULD-FIX
   otherwise. Name the fact and the file that owns it.
3. **Ownership.** For each rule or fact stated in more than one file, name its owner.
   Two copies that contradict are BLOCKING. A copy that paraphrases, drops part of
   the owner's text, or omits the owner's name is SHOULD-FIX. Check each quoted copy
   against its owner with whitespace normalized.
4. **Triggers.** No tool evaluates description matching, so this probe is reading
   only; say so in its result. For each new or edited description, write three tasks
   it must fire on and three near-miss tasks it must not. A trigger on a code shape
   that matches most edits is SHOULD-FIX. A trigger that misses a role's task is
   BLOCKING when no brief or agent definition loads the skill for that role.
5. **Claims.** For each technical claim (flag, lint, or option name; API semantics;
   default; version), run a minimal probe with a local toolchain. If no toolchain
   exists, cite the primary documentation. Otherwise mark the claim [INFERENCE]. A
   wrong claim that leads to wrong code or a false verdict is BLOCKING. An outdated or
   imprecise claim is SHOULD-FIX.
6. **Self-consistency.** Check that every example obeys the rules of the file it is
   in, that each concept has one term, and that the levels, thresholds, and tables a
   file defines agree with every place that uses them. An example that breaks its
   own file's rule is BLOCKING, because readers copy examples.
7. **Source fidelity.** When a skill distills an external source, read enough of the
   source to judge it. Check that the central ideas are present, quotes are verbatim,
   and additions are labeled as additions. A misrepresented source is BLOCKING. An
   unlabeled addition is SHOULD-FIX.
8. **Style.** Check the prose against the `doc-writer` rules. The `skill-reviewer`
   agent loads them with this skill. When they are not in your context, skip this
   probe and say so. Style findings are NIT unless a sentence can be misread.

## Output

1. Findings in three groups: BLOCKING, SHOULD-FIX, NIT. Each finding gives file:line,
   the problem, the evidence (probe output, quoted lines, or a load trace), and a
   concrete fix written as target wording or structure.
2. The load-trace table: role, files loaded in order, tokens.
3. Three to five lines on whether the skills compose soundly and what you would
   change structurally.
4. The model you ran as.
5. Final line: `VERDICT: APPROVE` when no BLOCKING finding stands, else
   `VERDICT: REJECT`.
