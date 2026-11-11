---
description: Handle specific errors; never swallow or suppress one to make a failure go away
scope: "tool:edit(*.{rs,go,ts,tsx,mts,cts,js,jsx,mjs,cjs,py,nix,sh,bash,zsh,c,cc,cpp,h,hpp,java,kt,swift,lua,rb,sql,toml,yaml,yml}), tool:write(*.{rs,go,ts,tsx,mts,cts,js,jsx,mjs,cjs,py,nix,sh,bash,zsh,c,cc,cpp,h,hpp,java,kt,swift,lua,rb,sql,toml,yaml,yml})"
condition:
  - '(?i)\bcatch\b|\bexcept\b|\|\|\s*(?:true\b|:)|2>\s*/dev/null|@ts-(?:ignore|expect-error|nocheck)|eslint-disable|#\[allow\(|#\[ignore\]|\bnolint\b|\bnoqa\b|type:\s*ignore|\blet _ =|\.ok\(\);|set \+e|\.skip\(|mark\.skip|t\.Skip'
question: "The content is a code edit. Answer yes if the edit adds error swallowing or suppression (a broad catch or except that discards the error or only logs it, `|| true`, a discarded result, a lint or type-check suppression, a skipped or ignored test) whose evident purpose is to make an error, warning, or failure go away rather than to handle a specific expected case. Answer no if the handler catches a named, expected error and recovers in a defined way, or the suppression is narrow and states its reason."
---
Your edit swallows or suppresses an error. Fix the cause instead: handle the specific expected error with a defined recovery, or let it propagate. Keep a suppression only when it is narrow and you can state why in one line next to it.
