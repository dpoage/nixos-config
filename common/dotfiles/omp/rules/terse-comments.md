---
description: Most code needs no comment; a kept comment states one fact the code cannot, and a block of five or more comment lines is cut before it lands
condition:
  - '(?m)^(?:\+?[ \t]*(?://|#(?:[ \t]|$)|-- |/\*|\*(?:[ \t/]|$))[^\n]*\n){4}\+?[ \t]*(?://|#(?:[ \t]|$)|-- |/\*|\*(?:[ \t/]|$))'
scope: "tool:edit(*.{rs,go,ts,tsx,mts,cts,js,jsx,mjs,cjs,py,nix,sh,bash,zsh,c,cc,cpp,h,hpp,java,kt,swift,lua,rb,sql,toml,yaml,yml}), tool:write(*.{rs,go,ts,tsx,mts,cts,js,jsx,mjs,cjs,py,nix,sh,bash,zsh,c,cc,cpp,h,hpp,java,kt,swift,lua,rb,sql,toml,yaml,yml})"
interruptMode: tool-only
---
You wrote a comment block of five or more lines. Most code needs no comment. Re-issue the call with each comment deleted or cut to its cap. Full rules: `skill://comment-compactor`.

Keep a comment only if, without it, a competent reader would break an invariant the code does not enforce, "fix" something deliberate, or misuse an exported API. Then state that one fact.

| Comment | Cap |
|---|---|
| Inline, or above a statement | 1 line; 2 if the fact needs it |
| Unexported function, type, field | 2 lines; usually none |
| Exported API doc | Summary sentence + up to 3 lines of contract |
| Test function doc | None; 1 line for a non-obvious bound or setup |

Never write: how the code came to be, rejected alternatives, ticket or phase ids, restated code or names, mechanism in docs, examples in docs, banners, reassurance. Rationale goes in the commit message.

Re-issue unchanged only for a license header, machine-read comments, doctests, or commented-out code you did not write.

```
// process_batch requires timestamp order; the query does not guarantee it.
entries.sort_by_key(|e| e.ts);
```
