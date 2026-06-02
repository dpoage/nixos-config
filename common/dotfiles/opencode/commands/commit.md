---
description: Draft a conventional-commit message from the current staged + unstaged changes
---

Draft a commit message for the current changes.

**Status:**
!`git status --short`

**Staged diff:**
!`git diff --cached`

**Unstaged diff:**
!`git diff`

**Recent commits (for style reference):**
!`git log --oneline -10`

Write a commit message that:

- Uses the imperative mood ("Add X", not "Added X")
- Has a subject line under 72 chars
- Includes a body only if the *why* is non-obvious from the subject
- Matches the style of the recent commits above

Output only the commit message — no preamble, no markdown fence. The user will pipe it into `git commit -F -`.
