# Re-review

This slice was REJECTed at `{START}`, and a fix round has since committed on top of it.
The verdict it was fixed against is `{VERDICT}/verdict.json`, with each finding's probe
under `{VERDICT}/findings/<id>/`. Re-probe every one of those findings on this build,
and review the fix diff `git diff {START}..HEAD` as new code: a fix may break what the
brief requires elsewhere. A finding of yours may repeat an earlier one that still fails.

An implementer built the slice brief below in `{WORKTREE}`, on top of base `{BASE}`.
`git diff {BASE}..HEAD` is the slice. The implementer reports the brief's gate green.
Review the slice against the brief and give a binding verdict: APPROVE ships it,
REJECT sends it to a fix round.

- Probe by execution, from scratch copies under `{SCRATCH}`. Never edit `{WORKTREE}`.
- A finding is a property the brief requires that this build violates. Style, naming
  and test coverage alone are not findings.
- Every finding carries a probe that a script can re-run. Write it to
  `{SCRATCH}/findings/<id>/probe.sh`, with any helper files in the same directory.
  The probe runs with its working directory at the root of a fresh copy of the
  reviewed tree, and with its own directory copied to `.probe/` inside that copy.
  So refer to the code by relative path, to your helpers as `.probe/<file>`, and
  never to `{WORKTREE}` or `{SCRATCH}`. Use only the standard library. The probe
  exits 0 when the property holds and nonzero when it is violated, within 60
  seconds, and gives the same answer on every run. Before you report a finding,
  run its probe that way and see it fail.
- Write `{SCRATCH}/verdict.json`:

  ```json
  {"verdict": "REJECT", "findings": [{"id": "B1", "property": "brief property 7", "claim": "one sentence: input, expected, observed"}]}
  ```

  `verdict` is `APPROVE` or `REJECT`. Each finding id names a directory under
  `{SCRATCH}/findings/`. APPROVE has an empty `findings` list.
- Reply with the verdict and the findings.

The brief the implementer worked from:

---

{BRIEF}
