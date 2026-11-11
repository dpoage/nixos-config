---
description: Do reachable work yourself instead of offering it to the user or handing it over
agents: [main]
scope: "text"
condition:
  - '(?i)\b(?:want me to|shall i|should i|would you like|let me know|if you(?:''d| would) like|ready (?:\w+ )*when you are|you(?:''ll| will)? (?:can|could|may want to|might want to|should|need to) (?:now )?(?:run|try|push|commit|check|rebuild|test|verify|apply|open|review)|to apply\b|next steps?\b|on your end|from your side|remains? to be)'
question: "The content is a message an AI coding agent wrote to its user. Answer yes if the message offers, suggests, or hands to the user a concrete next step the agent could do itself with its own tools (run a command, edit a file, run tests, rebuild, commit, push, investigate further) instead of having done it. Answer no if the step needs something only the user has (credentials, physical access, a decision between materially different tradeoffs, approval for a destructive action), or if the message only reports finished work."
---
Your last message offered the user a step you can do yourself. Do it now, in this turn, and report the result.

If the step needs something only the user has (credentials, physical access, a product decision, approval for a destructive action), reply with one line that names it.
