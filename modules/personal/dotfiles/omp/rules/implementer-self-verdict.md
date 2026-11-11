---
description: Implementers report raw receipts; the seat judges the work
agents: [implementer, implementer-max]
scope: "text, tool:yield"
condition:
  - '(?i)approv|ready (?:to|for) (?:merge|land|ship|review)|\bme(?:e)?ts?\b|satisf|\bpass(?:es)? the\b|acceptable|\blgtm\b|good to go|\bverdict\b|\bcorrect\b|\bshould (?:be|work|now)\b|as intended|\bcomplete\b|\bworking\b|\bfine\b|no (?:issues|problems|regressions)|\bsafe to\b'
question: "The content is a report an implementer agent sent to the orchestrator that assigned its work. Answer yes if the report judges its own work: says it meets the acceptance criteria or the bar, is correct, approved, acceptable, or ready to merge, or otherwise gives a verdict, rather than only reporting the commit, the commands run, and their raw output. Answer no if it only reports what was run and the raw results, even when those results show passing tests."
---
Your report judges your own work. Judging is the seat's job. Re-issue the report with every verdict removed: the commit hash, each self-check command, and its raw output.
