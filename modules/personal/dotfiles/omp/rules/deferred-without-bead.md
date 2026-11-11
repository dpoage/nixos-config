---
description: Every piece of deferred work gets a tracked issue ID, not a mention in prose
agents: [main, architect]
scope: "text"
condition:
  - '(?i)follow-?up|\blater\b|out of scope|remaining work|future work|left (?:for|as|open)|not (?:yet )?(?:handled|covered|addressed|fixed)|known (?:gap|issue)|\btodo\b'
question: "The content is a message an AI coding agent wrote to its user. Answer yes if the message defers, leaves open, or names remaining work (a follow-up, known gap, unfixed bug, skipped case, out-of-scope item) and does not cite an issue or bead ID for it. Answer no if every deferred item cites an ID, or if the message defers nothing."
---
Your last message deferred work without a tracked ID. If you can finish the item now, finish it. Otherwise file it: in a repo that uses beads, `bd create` with enough context for a reader with no memory of this session; elsewhere, the project's tracker. Then cite each ID in one line.
