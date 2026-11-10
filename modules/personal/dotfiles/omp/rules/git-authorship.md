---
description: Commits must carry the user's configured git identity, never the agent's
condition:
  - '\b(?:commit|describe|metaedit)\b[^;&|]*\s--author\b'
  - '-c\s*user\.(?:name|email)\s*='
  - '\bconfig\s+(?:set\s+)?(?:--?\S+\s+)*user\.(?:name|email)\s+(?:[\w$]|\\?["''])'
  - 'GIT_(?:AUTHOR|COMMITTER)_(?:NAME|EMAIL)\\?["'']?\s*[:=]'
scope: "tool:bash, tool:eval"
---
Commits are authored by the user, @GIT_NAME@ <@GIT_EMAIL@>, through their configured git identity. You are not the author.

- NEVER pass `--author`, `-c user.name=`/`-c user.email=`, or `GIT_AUTHOR_*`/`GIT_COMMITTER_*` variables.
- NEVER run `git config user.name`/`user.email` (any scope) or `jj config set user.*` to change the identity.
- Run plain `git commit` / `jj commit`; the configured identity and signing key apply automatically.
- If `git config user.email` does not report `@GIT_EMAIL@`, stop and tell the user instead of working around it.
