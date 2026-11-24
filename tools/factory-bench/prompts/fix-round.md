# Fix round

An implementer built the slice brief below in `{WORKTREE}`, on top of base `{BASE}`
(`git diff {BASE}..HEAD` is the slice). A review seat REJECTed it. You run the fix
round: you have the verdict and a fresh context, and you may discard the approach.

- The verdict is `{VERDICT}/verdict.json`. Each finding's probe is
  `{VERDICT}/findings/<id>/probe.sh`. A probe runs with its working directory at the
  root of a copy of the tree and its own directory copied to `.probe/` inside it; it
  exits 0 when the property holds. To run one on your tree, copy the tree to scratch
  under `{SCRATCH}`, copy the finding's directory to `.probe/` in that copy, and run
  `bash .probe/probe.sh` from the copy's root.
- Fix every finding at its cause, so that its probe passes for the reason the brief
  gives. Do not edit a probe, and do not special-case its inputs. A finding you judge
  wrong: quote the sentence of the brief that decides against it in your reply, and
  leave the code.
- Keep everything else the brief requires. The brief's gate stays green, with a test
  of yours for each fixed finding.
- Commit on `main` with plain `git commit`. Reply with each finding id and what you
  changed, or the sentence of the brief that decides against it.

The brief the implementer worked from:

---

{BRIEF}
