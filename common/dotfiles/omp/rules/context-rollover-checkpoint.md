---
description: After a reply reports finished work, roll the context over
agents: [main, architect]
scope: "text"
condition:
  - '(?i)\b(?:on|to|into) main\b|\bmain (?:is|at)\b|\bclean(?:ed)? ?up\b|\bpaused\b|\bclosed\b|\blanded\b'
question: "The content is a status message an AI agent wrote to its user. Answer yes if the message reports that a deliverable is finished: work landed or merged on the main branch, a round, lane or epic completed, its agents or worktrees cleaned up, or work paused at the user's request. Answer no if the message mainly reports a ruling, a fix, a review verdict, a diagnosis, a measurement, a slice merged into a feature branch, or other work still in progress."
---
Your last message reported finished work. That is a natural cutover point, so roll the context over now.

Skip the rollover in these cases, and reply with one line that says why:

- The current window started in the last few turns.
- You are a subagent and you already called `yield`.
- The message did not report finished work.

Otherwise:

1. Write the handoff with `context_notes`: goal, state, decisions and reasons, open risks, next action, and references (paths, bead IDs, agent IDs, branches).
2. Call `new_context`.
3. Reply with one line: "Context rolled over." Do not repeat your report.
