---
description: Roll your own context over with new_context at natural cutover points, not at the window limit
alwaysApply: true
---
# Context rollover

If your tools include `context_notes` and `new_context`, start each new context window yourself at a natural cutover point. Do not wait for the window to fill. A rollover at the window limit cuts work in the middle of a unit and loses the reasoning behind it.

A natural cutover point is a moment when the finished work no longer needs its raw tool output:

- A bead, issue, or todo phase is closed.
- Work lands on the main branch, or a round, lane, or epic completes.
- A checkpoint closes: you recorded a decision, ruling, or approval and handed the next step to other agents.
- A subagent, oracle, or review round returns its verdict, and you recorded the result.
- An investigation ends, and you recorded its conclusion.
- The user moves to an unrelated topic.

Roll over at a cutover point only if work remains in this session and the window holds earlier work that you no longer read. Skip the rollover in these cases:

- You are about to give your final answer or yield. A checkpoint reminder that arrives after your final answer overrides this case.
- This window holds fewer than about 20 of your turns, counted from the session start or the last rollover.
- You are in the middle of a debug loop, or you have edits whose reasons are not recorded.

## Procedure

1. Write the notebook with `context_notes` as a handoff to a reader with no memory of this window. Record the goal, the current state, the decisions and their reasons, the open risks, the exact next action, and the references: file paths, bead IDs, agent IDs, branch names. If the lane keeps a handoff file, update that file first. Then the notes give its path and only what the file does not hold.
2. Call `new_context`.
3. Continue with the next action from the notebook. Do not stop the turn.

After a rollover, treat the notebook as the source of truth. To recover a detail that the notebook omits, use `grep` or `read` on `history://current/full`.

Keep the notebook current between cutover points too. Update it when a decision changes, so an automatic rollover at the window limit loses nothing.
