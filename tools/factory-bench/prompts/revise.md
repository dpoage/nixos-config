## Revision round: peer tests

Your earlier commit in the worktree is the starting point. Other engineers built this
same brief independently, each with their own tests. Below are their tests that fail
against your code.

A peer test is a lead, never a ruling: the brief decides. For each failing test:

- If a sentence of the brief requires what the test asserts, fix your code, add a test
  of your own for that property, and show its mutant red.
- If the brief contradicts the test, or says nothing, change nothing. Under
  `## Left alone`, quote the sentence that decides it, or write "brief is silent".

Never copy a peer's test file. Keep every property you already had green. Commit.

{FAILURES}
