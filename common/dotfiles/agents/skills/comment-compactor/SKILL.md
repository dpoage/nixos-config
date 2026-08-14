---
name: comment-compactor
description: Use when pruning verbose LLM-generated code comments — development narration, change-log residue, task references, restated code. Trigger when the user asks to compact, clean, or prune comments, or after a large generated diff lands. Dispatches light agents to rewrite comments so they describe the code as it is NOW. Comments-only; never changes code.
---

# Comment Compactor

A comment earns its place by stating a fact about the code **as it is now** that
the code cannot state itself. Everything else is deleted, not rewritten. When in
doubt between a shorter comment and no comment, prefer no comment.

## Delete on sight

- **Development narrative**: "First we tried X", "after refactoring", "I decided to",
  stream-of-consciousness reasoning about how the code came to be.
- **Change-log residue**: "Changed from X to Y", "Now uses", "Previously", "Updated to",
  "New helper for", "Renamed from". Git history owns this; comments do not.
- **Task and conversation references**: "as requested", "per the review", "addresses
  the feedback", "see the task description", ticket prose that restates the diff.
- **Restated code**: any comment a reader reconstructs from the line below it
  ("// increment the counter", "// loop over users").
- **Hedges and apologies**: "a bit hacky but works", "simple version for now",
  "should probably be improved". Either it is a concrete TODO or it is noise.
- **Generation scaffolding**: "... rest of implementation", "existing code unchanged",
  section banners around trivial code, empty doc stubs ("/** Constructor. */").
- **Signature echoes**: param/return docs that add no fact beyond the type signature.

## Keep, but tighten

- **Why-facts**: invariants, non-obvious constraints, ordering requirements, workaround
  rationale (keep the link to the upstream bug).
- **Safety notes**: concurrency, unsafe blocks, aliasing, failure modes.
- **Public API doc comments**: they are the contract — compress, never delete. Preserve
  the toolchain's doc syntax (rustdoc, JSDoc, docstrings) and any executable doctests.
  Compaction only: if a doc comment needs substantive rewriting or expansion, that is
  writing, not compacting — load `skill://doc-writer` and handle it yourself, outside
  the light-agent batch.
- **Actionable TODO/FIXME**: keep only those naming a concrete defect or follow-up. If
  the repo has an issue tracker (e.g. beads), file durable ones there and drop the comment.

## Rewrite rules

- Present tense. The comment describes current behavior, not a delta or an intention.
- Lead with the fact. One line where one line suffices.
- Never invent facts. If you cannot verify WHY the code does something, tighten the
  existing explanation; do not guess a new one.

## Workflow

1. **Scope.** Default to files touched in the working diff or branch; otherwise the
   paths the user names. Never sweep the whole repo unasked.
2. **Dispatch.** Batch files and send each batch to a light, low-reasoning agent
   (`quick_task` / `sonic` class). Inline these rules in the task — the agent starts
   blank. State the comments-only mandate explicitly. Run batches in parallel.
3. **Constrain.** Agents touch only comment lines and blank lines they leave behind.
   No code edits, no reformatting, no import shuffling — even to "fix" something a
   deleted comment described.
4. **Verify.** Read the combined diff: every changed line is a comment or blank line.
   Then typecheck or build the touched files if the repo has a cheap way to do so
   (docstrings and doc-tests are load-bearing in some toolchains).

## Never touch

- License and copyright headers.
- Machine-read comments: shebangs, encoding lines, lint directives (`eslint-disable`,
  `noqa`, `#[allow]`, `@ts-expect-error`), pragmas, region markers, generated-file
  markers, template/build annotations.
- Commented-out code: flag it in the report for a human decision; do not delete or
  rewrite it.
