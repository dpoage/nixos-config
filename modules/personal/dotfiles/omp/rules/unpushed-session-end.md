---
description: A session that made commits ends with them pushed when the repo requires it
agents: [main]
scope: "text"
condition:
  - '(?i)\bcommit'
question: "The content is a message an AI coding agent wrote to its user. Answer yes if the message wraps up a task or work session after the agent made commits, and does not say the commits were pushed to the remote or why a push was impossible or not wanted. Answer no if it reports a successful push, if the agent plainly continues working after the message, or if no commits were made."
---
You wrapped up after committing without reporting a push. If the repo's instructions require pushing at session end (nixos-config's AGENTS.md does): `git pull --rebase`, `git push`, then `git status` must show the branch up to date; in a repo that uses beads, also `bd dolt push`. Report the result in one line.

If the user said not to push, or the repo does not require it, reply with one line that says so.
