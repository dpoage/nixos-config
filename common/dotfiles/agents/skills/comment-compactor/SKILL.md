---
name: comment-compactor
description: Use when pruning verbose LLM-generated code comments — narration, change-log residue, task references, restated code, oversized docs. Trigger when the user asks to compact, clean, or prune comments, or after a large generated diff lands. Dispatches light agents that delete by default and hold survivors to hard length caps. Comments-only; never changes code.
---

# Comment Compactor

Most code needs no comment. Names, types, and tests carry intent. A comment exists
only to state what the code cannot: a fact a reader would otherwise get wrong. Every
comment starts condemned; keeping one needs a reason from the test below.

**Code is read-only.** Every "delete" in this skill means a comment. A diff that
touches any non-comment, non-blank line is a failed batch: restore the file from
the baseline and redo it. Never keep a "mostly good" result, and never accept a
code deletion because the surrounding comment work looks correct.

## The test

Apply to every comment. Imagine it deleted and read the code alone. Keep it only if a
competent reader of this codebase would then:

- break an invariant or ordering requirement the code does not enforce;
- "fix" something deliberate: a workaround, a surprising constant, a lock that looks
  missing, a bound that looks arbitrary;
- misuse an exported API: an error, panic, blocking call, ownership rule, or unit the
  signature hides.

Anything else is deleted. "Useful context", "explains the design", "aids navigation",
and "each line states a fact" are not reasons. A kept comment states that one thing
and nothing around it.

Short trailing comments are the cheapest comments that pass. One that gives a value
its meaning (a size, a unit, why a sleep, which case a fixture row is, why `true`
here) stays unless it restates a name. Never delete one to bring the count down.

## Caps

Hard limits on what survives. A comment over its cap is cut until it fits.

| Comment | Cap |
|---|---|
| Inline, or above a statement | 1 line; 2 if the fact needs it |
| Unexported function, type, field | 2 lines; usually none |
| Exported API doc | Summary sentence + up to 3 lines of contract |
| Test function doc | None; the test name says it. 1 line for a non-obvious bound or setup |
| Package doc | 5 lines |

The only exemptions are the **Never touch** list at the end.

## Always delete

- **Narration**: how the code came to be, what was tried, what changed ("now uses",
  "previously", "renamed from"), rejected alternatives, incident stories (keep a bare
  upstream bug link if the workaround needs one).
- **References to work items**: tickets, phases, spec section ids (`P7.3`, `X15`, `R2`),
  "per review", "as requested". The reader has the code, not the plan.
- **Restated code**: what the next line does, what the name already says, the type
  signature in prose, constant values, the list of callers.
- **Mechanism in docs**: how a function works inside. Docs state the contract; the body
  is the mechanism.
- **Examples in doc comments**, unless they are executable doctests. Tests show usage.
- **Banners and dividers**: `// ---- Section ----`, `// Helpers`, `// Constants`.
- **Hedges and reassurance**: "a bit hacky", "for now", "this is fine because". If the
  bound is load-bearing, state the bound.
- **Cross-references** to code in the same file or one call away.
- **Empty or stub docs** and `Note:` / `Important:` / `This function` openers.
- **TODOs** that do not name a concrete defect. File durable ones in the issue tracker.

## Writing what survives

- Fact first, present tense, the code's own names. No "we", no setup sentence.
- An exported doc keeps its summary sentence in the toolchain's form (Go: starts with
  the identifier). Never delete that line; cut everything after it to the cap.
- Keep the file's wrap width. Rewrap a shortened comment; never join lines into one
  past the width the surrounding comments use.
- Never invent facts. Cut to what the existing comment already says.

Inline why, 6 lines → 1:

```
// We need to sort the entries here because the downstream consumer
// (see process_batch) assumes they arrive in timestamp order. Previously
// we relied on the database returning them sorted, but that turned out
// to be unreliable when the query planner picked a hash join, which caused
// the flaky CI test. So now we sort explicitly to be safe. This is
// O(n log n) but n is small so it's fine.
entries.sort_by_key(|e| e.ts);
```

```
// process_batch requires timestamp order; the query does not guarantee it.
entries.sort_by_key(|e| e.ts);
```

Exported doc, 31 lines → 3. The cut lines were mechanism, an example, and a debugging
aside:

```
// Scope returns a Timeline that receives only events the parent positions
// after this call; events already visible on the parent never reach it.
// Scope on a stopped timeline returns a stopped timeline.
func (tl *Timeline) Scope() *Timeline {
```

Test doc, 5 lines → 0. `TestCollector_StopUnblocksWaiters` already says it.

Writing agents get the same rules from the `terse-comments` TTSR rule, which interrupts
any edit that adds five or more consecutive comment lines.

## Workflow

1. **Scope.** Default to files touched in the working diff or branch; otherwise the
   paths the user names. Never sweep the whole repo unasked. On a branch, only the
   comment lines the branch added are in scope (`git diff -U0 <merge-base>`); give
   agents that command and the line ranges of over-cap blocks.
2. **Baseline.** Snapshot before every dispatch, including re-dispatches: the default
   scope is a dirty worktree, so without this there is nothing to revert to.
   `git stash create` records the tree without touching it (note the hash), or copy
   the target files aside. Do not dispatch until the snapshot exists.
3. **Dispatch.** Batch files and send each batch to a light, low-reasoning agent
   (`quick_task` / `sonic` class). Inline these rules in the task — the agent starts
   blank — and paste the guardrail block below **verbatim** at the top of every task.
   Run batches in parallel; cut concurrency if the provider rate-limits.
4. **Verify (mechanical gate).** Walk `git diff -U0` per touched file. Every `-` line
   must be a whole-line comment, a blank line, or a code line whose `+` counterpart
   keeps the code before the comment marker byte-identical. Every `+` line must be a
   comment or blank. Any violation → restore that file from the baseline snapshot and
   redo it yourself; never hand-patch around a bad agent diff, and never let a code
   change through because it "looks harmless". Then rewrap any added comment line
   past the file's width yourself; light agents tend to join lines when shortening.
5. **Measure.** Count comment blocks still over their cap. Report before → after
   comment lines and over-cap blocks. Re-dispatch files that still exceed caps once,
   naming the blocks; whatever survives a second pass, cut yourself.
6. **Build.** Typecheck or build the touched files if the repo has a cheap way to do
   so (docstrings and doc-tests are load-bearing in some toolchains).

### Guardrail block (paste verbatim into every agent task)

```
CODE IS READ-ONLY. You edit comments only. Rules, in order of precedence:
1. Never delete, rewrite, reorder, or reformat a code line — not code a removed
   comment described, not commented-out code, not code you believe is dead or wrong.
2. You may delete a whole line only if it contains nothing but a comment and
   indentation.
3. Trailing comment on a code line: change only the text from the comment marker
   onward; the code before the marker stays byte-identical.
4. Delete comment lines by exact line numbers you have just read. Never use
   block/structural delete or replace operations — they can swallow adjacent code.
5. Unsure whether a line is code, a directive, or a comment? Leave it untouched
   and mention it in your report.
6. If you notice a bug, dead code, or a missing fix, report it; do not touch it.
A diff from you containing any non-comment change is a failed task, even if every
comment edit in it is correct.
```

## Never touch

- License and copyright headers.
- Machine-read comments: shebangs, encoding lines, lint directives (`eslint-disable`,
  `noqa`, `#[allow]`, `@ts-expect-error`), pragmas, region markers, generated-file
  markers, template/build annotations.
- Executable doc content: doctests, Go `Example` output blocks (`// Output:`).
- Commented-out code: flag it in the report for a human decision; do not delete or
  rewrite it.
