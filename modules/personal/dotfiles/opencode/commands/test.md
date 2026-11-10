---
description: Dispatch the test agent to expand coverage. With no argument, focuses on the current branch's changes; with an argument, focuses on the given path or pattern.
agent: test
subtask: true
---

Expand test coverage.

**Scope:** $ARGUMENTS

If the scope above is empty, focus on code changed in this branch:

!`git diff main...HEAD --stat 2>/dev/null || git diff origin/main...HEAD --stat 2>/dev/null || git diff HEAD --stat`

Otherwise, focus on the path or pattern given.

Follow your procedure: survey the toolchain, measure baseline coverage, identify the highest-leverage gap, plan one test, write it, run it, loop. Halt per your halt conditions and produce the final report.

Reminder: discovering a source bug is a halt condition. Write the test as expected-fail, file a bead, stop — do not fix the source.
