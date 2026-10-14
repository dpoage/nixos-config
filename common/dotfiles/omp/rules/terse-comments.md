---
description: Code comments state one non-obvious fact in a line or two; a block of six or more comment lines is cut before it lands
condition:
  - '(?m)^(?:\+?[ \t]*(?://|#(?:[ \t]|$)|-- |/\*|\*(?:[ \t/]|$))[^\n]*\n){5}\+?[ \t]*(?://|#(?:[ \t]|$)|-- |/\*|\*(?:[ \t/]|$))'
scope: "tool:edit(*.{rs,go,ts,tsx,mts,cts,js,jsx,mjs,cjs,py,nix,sh,bash,zsh,c,cc,cpp,h,hpp,java,kt,swift,lua,rb,sql,toml,yaml,yml}), tool:write(*.{rs,go,ts,tsx,mts,cts,js,jsx,mjs,cjs,py,nix,sh,bash,zsh,c,cc,cpp,h,hpp,java,kt,swift,lua,rb,sql,toml,yaml,yml})"
interruptMode: tool-only
---
You wrote a comment block of six or more lines. Re-issue the call with every comment cut to what the code cannot say. Full rules: `skill://comment-compactor`.

- A comment states one fact the code cannot: an invariant, a constraint, a reason, a hazard. One line; two when the fact needs it.
- Cut: what the code does, how it came to be, alternatives considered, change history, task or review references, reassurance, restated names and types.
- Design rationale, rejected approaches, and incident narrative go in the commit message or the bead. Keep an upstream bug link if one exists.
- Public API docs keep their contract (behavior, errors, panics, safety, units) and drop narration.
- Re-issue unchanged only if the block is a license header, machine-read (directives, generated markers), commented-out code you did not write, or API docs where every line is contract.

Before:

```
// We need to sort the entries here because the downstream consumer
// (see process_batch) assumes they arrive in timestamp order. Previously
// we relied on the database returning them sorted, but that turned out
// to be unreliable when the query planner picked a hash join, which caused
// the flaky CI test. So now we sort explicitly to be safe. This is
// O(n log n) but n is small so it's fine.
entries.sort_by_key(|e| e.ts);
```

After:

```
// process_batch requires timestamp order; the query does not guarantee it.
entries.sort_by_key(|e| e.ts);
```
