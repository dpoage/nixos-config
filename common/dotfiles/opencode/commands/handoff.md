---
description: Summarize the current session into a bead so the next session can pick up cleanly
agent: plan
---

Produce a session-handoff summary covering:

1. **What changed** — files touched, intent in one sentence each.
2. **What was tried and rejected** — dead ends worth not repeating.
3. **Open questions** — anything ambiguous or blocked on user input.
4. **Next concrete action** — the single next step.

**Working state:**
!`git status --short`

!`git log --oneline -5`

**In-progress beads:**
!`bd list --status=in_progress`

$ARGUMENTS

After producing the summary, run `bd comments add <id> "<summary>"` against the most relevant in-progress bead — or, if none fits, propose a new bead with `bd create` (don't run it; let the user confirm the title first).
