---
description: Comments state lasting facts about the code, never the story of the change
scope: "tool:edit(*.{rs,go,ts,tsx,mts,cts,js,jsx,mjs,cjs,py,nix,sh,bash,zsh,c,cc,cpp,h,hpp,java,kt,swift,lua,rb,sql,toml,yaml,yml}), tool:write(*.{rs,go,ts,tsx,mts,cts,js,jsx,mjs,cjs,py,nix,sh,bash,zsh,c,cc,cpp,h,hpp,java,kt,swift,lua,rb,sql,toml,yaml,yml})"
condition:
  - '(?m)^\+?[ \t]*(?://|#(?:[ \t]|$)|-- |/\*|\*(?:[ \t/]|$))'
question: "The content is the lines a code edit adds, or a new file's full content; removed and unchanged lines are not shown. Answer yes if a comment in it narrates the change or its history instead of stating a lasting fact about the code, for example: now uses X, changed to, added to fix, instead of the old, new:, ticket or phase references, or a restatement of what the next line plainly does. Answer no if every comment in it states a fact a reader needs that the code cannot express, or if it contains no comments."
---
Your edit adds a comment that narrates the change. Delete it, or rewrite it as the one lasting fact a reader needs. The story of the change goes in the commit message. Full rules: the `comment-compactor` skill.
