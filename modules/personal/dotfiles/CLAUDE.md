# Development Principles

Read before writing. Understand existing code, tests, and context before proposing changes.

Verify with tests and benchmarks — do not assume correctness from reading alone.
Thoroughness is never wasted. Reading extra files, running tests to confirm,
and checking edge cases are all preferable to fast but wrong output.

## GitHub Voice

When posting to GitHub (comments, issues, PR bodies, reviews), follow
`~/.claude/github-voice.md`. Terse, evidence-linked, no assistant-ese.

## Coding Guidelines

You MUST:
- Make invalid states unrepresentable
- Use strong typing
- Parse, don't validate

### KISS · YAGNI · DRY

- **KISS** — the boring solution wins unless cleverness buys something
  measurable. Optimize for the next maintainer, not the author.
- **YAGNI** — governs what you *build*, not what you *handle*. No features,
  options, or hooks without a demonstrated need; no generality before the
  second concrete use. NOT license to strip defensive code: guards on
  reachable states (I/O, user input, concurrency) stay until the type system
  makes the state unrepresentable. An untested branch is a missing test, not
  dead code.
- **DRY** — deduplicate *knowledge*, not text: one source of truth per
  invariant. Extract on the second concrete use; duplication is cheaper than
  the wrong abstraction.

### Reuse Before Writing

Before authoring any new function, type, or helper:
- Search for an existing implementation or near-match. Extend it rather than duplicate it.
- Match the conventions of the surrounding module. A second convention beside an existing one is a bug, not a style choice.
- Limits: do not contort an ill-fitting abstraction to force reuse.

## Beads as Persistent Memory

`bd prime` gives you the commands. This section tells you how to think.

Beads is not a todo list. It is **cross-session memory**. Conversation context gets compacted; beads fields persist. Every finding, decision, and rationale that matters beyond this session must be written to a bead — not left in chat.

**Bead before code.** If you'll investigate, decide, or write more than a few lines — create a bead first. It makes work visible in `bd ready` and captures knowledge as you go.

### Bead Requirements (every bead, no exceptions)

| When | MUST do |
|---|---|
| **Create** | Set `--description` (what and why) AND `--acceptance` (testable "done" conditions) |
| **Close** | Set `--reason` (what was decided — never just "done") |

A bead without `--acceptance` cannot be verified as complete. A bead without `--reason` loses its decision context. These are not optional.

### Creating a Bead

ALWAYS set these two fields:
- **`--description`**: The intent statement. What is this bead *about* and *why*.
- **`--acceptance`**: Concrete, testable conditions for "done." Not vague goals.

Set these at creation if known, otherwise add during work:
- **`--design`**: Architectural decisions, alternatives evaluated, rationale.
- **`--notes`**: Implementation gotchas, things the next session needs to know.

### During Work

- **`bd comments add <id> "..."`**: Timestamped findings, progress, open questions.
- Update `--design` and `--notes` as you learn things a future session needs to know.

### Closing a Bead

- **`--reason`**: MUST capture *what was decided*, not "done" or "completed."

**Goal**: `bd show <id>` tells a future session *what* to do, *why* this approach, and *what was already tried*.

### Research Tasks

1. Create issue with clear evaluation criteria in `--description` and `--acceptance`
2. Capture findings in `--design` or `--notes` as you go — not just in conversation
3. Close with `--reason` stating the recommendation
4. Put detailed rationale on the *consuming* issue via `--design`

### Dependency Design

- Children depend on *siblings*, not the parent epic
- After closing a blocker, `bd ready` to see what unblocked

### Anti-patterns

- **Missing acceptance**: A bead created without `--acceptance` cannot be verified as complete. ALWAYS set it at creation.
- **Empty closes**: No `--reason` loses decision context. ALWAYS state what was decided.
- **Orphan knowledge**: Research that exists only in conversation will be lost at compaction.
- **Description drift**: If the description no longer reflects the bead's actual intent, update it or create a new bead.
- **Over-nesting**: A single well-described task often beats an epic with subtasks.
