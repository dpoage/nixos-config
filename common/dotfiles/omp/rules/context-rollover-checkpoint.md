---
description: After a reply closes a checkpoint, roll the context over
agents: [main, architect]
scope: "text"
question: "The content is a status message an AI orchestrating agent wrote to its user. Answer yes if the message closes out a checkpoint: the agent made or recorded a decision, ruling, approval, or merge, and handed the next step to other agents or the user, so nothing is left for the agent itself except waiting. Answer no if the message is a question to the user, reports that the agent is still investigating, or describes work the agent will do next itself."
---
Your last message closed a checkpoint: you recorded a decision and handed the next step to others. That is a natural cutover point, so roll the context over now.

Skip the rollover in these cases, and reply with one line that says why:

- The current window started in the last few turns.
- You are a subagent and you already called `yield`.
- The next checkpoint needs raw detail from this window that you cannot write into the notebook.

Otherwise:

1. Write the handoff with `context_notes`: goal, state, decisions and reasons, open risks, what you wait for, and references (paths, ledger files, bead IDs, agent IDs, branches). If the lane keeps a handoff file, update that file first. Then the notes give its path and only what the file does not hold.
2. Call `new_context`.
3. Reply with one line: "Context rolled over." Do not repeat your report.
