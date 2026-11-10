---
description: Dispatch the current diff to the review subagent
agent: review
subtask: true
---

Review the following diff for correctness bugs, security issues, and overengineering.

**Status:**
!`git status --short`

**Diff vs HEAD:**
!`git diff HEAD`

$ARGUMENTS

Report findings as a punch list grouped by severity (blocker / nit / question). Cite `file:line` for each. Do not propose stylistic rewrites unless they fix a real bug.
