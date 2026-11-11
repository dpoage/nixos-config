---
description: Cut over cleanly; do not keep an old interface alive beside its replacement
scope: "tool:edit(*.{rs,go,ts,tsx,mts,cts,js,jsx,mjs,cjs,py,nix,sh,bash,zsh,c,cc,cpp,h,hpp,java,kt,swift,lua,rb,sql,toml,yaml,yml}), tool:write(*.{rs,go,ts,tsx,mts,cts,js,jsx,mjs,cjs,py,nix,sh,bash,zsh,c,cc,cpp,h,hpp,java,kt,swift,lua,rb,sql,toml,yaml,yml})"
condition:
  - '(?i)legacy|deprecat|compat|backwards?|\balias|re-?export|fallback|\bshim\b|\bold[_A-Z]|export\s*\{[^}]*\bas\b|\bpub use\b[^;]*\bas\b|\?\?|\|\|\s*\w+(?:\.\w+)+|\bwrapper|\bforward|\bdelegat|\bformerly\b|\bkept for\b|\brenamed?\b'
question: "The content is the lines a code edit adds, or a new file's full content; removed and unchanged lines are not shown. Answer yes if the added code keeps an old interface alive next to its replacement: a deprecated alias, a re-export under an old name, a wrapper that only forwards to the new name, a fallback to an old config key or code path, or a legacy or compat branch. Answer no if the added code contains no such path, or the compatibility path serves consumers the edit cannot migrate (a published API, persisted on-disk data, a wire protocol)."
---
Your edit keeps an old interface alive beside its replacement. Migrate every caller to the new one and delete the old path: no aliases, re-exports, or fallbacks.

Keep it only if it serves consumers you cannot migrate (a published API, persisted data, a wire protocol), and say which in your report.
