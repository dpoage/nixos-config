---
description: After a commit, push, or bead close, check for a context rollover
condition:
  - '\bgit\s+(?:-C\s+\S+\s+)?(?:commit|push)\b'
  - '\bjj\s+(?:commit|git\s+push)\b'
  - '\bbd\s+close\b'
scope: "tool:bash, tool:eval"
interruptMode: never
---
This call closes a unit of work, which is a natural cutover point. If you have `new_context`, work remains in this session, and you are not about to yield, roll over now:

1. Write the handoff with `context_notes`: goal, state, decisions and reasons, open risks, next action, references.
2. Call `new_context`.
3. Continue with the next action.

If this window started recently, or you are about to give your final answer, ignore this reminder.
