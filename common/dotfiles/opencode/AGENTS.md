# Development Tips

Code correctness over speed. Benchmarks and tests are critical.

## Beads -- Cross-Session Memory

`bd prime` gives you the commands. This section tells you how to think.

Beads is not a todo list. It is **persistent memory**. Context gets compacted; bead fields survive. Every finding, decision, and rationale that matters beyond this session belongs on a bead -- not in chat.

**Bead before code.** Create a bead before investigating, deciding, or writing non-trivial code. Skip only for mechanical changes where nothing is decided.

### Write: Capture Knowledge on Fields

- **`--reason` on close**: What was *decided*, not "done."
- **`--design`**: Alternatives evaluated, rationale for the chosen approach.
- **`--notes`**: Gotchas the next session needs to know.
- **`--acceptance`**: Concrete, testable conditions -- not vague goals.
- **`--description`**: The intent. Update it if scope changes.
- **`bd comments add <id> "..."`**: Timestamped progress and open questions.

**Goal**: `bd show <id>` tells a future session *what*, *why*, and *what was tried*.

For research beads: capture findings in `--design`/`--notes` on close, close with `--reason` stating the recommendation, put rationale on the *consuming* issue.

### Read: Retrieve Before You Act

- **Session start**: `bd ready` + `bd list --status=in_progress`. Don't start fresh when prior work exists.
- **Before new work**: `bd search "<topic>"` for prior beads (open or closed). Check `--notes` and `--design` on hits.
- **Closed beads are not dead**: `bd search "<topic>" --status closed` surfaces past decisions. A closed bead's `--reason` is institutional memory.

### Rules of Thumb

- Dependencies: children depend on *siblings*, not the parent epic. After closing a blocker, `bd ready` to see what unblocked.
- Prefer a single well-described task over an epic with subtasks.
- Never close without `--reason`. Never start work without `bd search`.
- If description no longer matches intent, update it or create a new bead.
