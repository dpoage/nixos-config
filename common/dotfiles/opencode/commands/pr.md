---
description: Build a PR body from the diff between the current branch and main
---

Build a pull request body for the current branch.

**Branch:**
!`git rev-parse --abbrev-ref HEAD`

**Commits on this branch (not yet on main):**
!`git log --oneline origin/main..HEAD 2>/dev/null || git log --oneline main..HEAD`

**Full diff against main:**
!`git diff origin/main...HEAD 2>/dev/null || git diff main...HEAD`

Produce a PR body with this structure:

```
## Summary
<1-3 bullets covering what changed and why>

## Test plan
- [ ] <concrete verification step>
- [ ] <another>
```

Keep the title (first line) under 70 chars; put detail in the body. Write in the voice
described by `~/.config/opencode/github-voice.md`: terse, honest test plan, no filler.
Output only the title on the first line, a blank line, then the body — nothing else.
