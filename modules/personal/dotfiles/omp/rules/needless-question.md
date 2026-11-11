---
description: Find facts with tools and take the conventional choice instead of asking the user
agents: [main]
scope: "text, tool:ask"
condition:
  - '\?'
question: "The content is a message or form an AI coding agent sent to its user. Answer yes if it asks the user for a fact the agent could get with its own tools (a file path, file contents, a version, a config value, command output, repository history), or asks the user to approve or choose when one option is the conventional, safe choice. Answer no if the question needs knowledge only the user has (intent, preference between materially different tradeoffs, credentials, state the agent cannot reach) or permission for a destructive action, or if the message asks nothing."
---
You asked the user for something your tools can answer, or for a choice with a conventional answer. Find the fact yourself, or take the conventional, safe option, state your choice in one line, and continue.
