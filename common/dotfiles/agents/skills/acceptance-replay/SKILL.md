---
name: acceptance-replay
description: Use when judging whether a change does what it claims — replaying the motivating incident against the built artifact and verifying every acceptance criterion, claimed fix, and published doc by executed probe. The behavior-replay oracle in an oracle round; also for verifying any PR's claims on demand. Read-only. Trigger on "does this actually fix it", "verify the acceptance criteria", "replay the incident", "check the PR's claims". For latent-defect probing load `bug-hunt`; for design judgment load `design-review`.
---

# Acceptance Replay

The question is not "is the code right" but "does the built artifact do what the
change claims, on the case that motivated it, and on the cases the claim implies".
Every judgment is an executed probe against the built binary or artifact; a claim you
could not execute is reported as unverified, never as passing. Read-only on the tree;
build and run in scratch copies.

## Procedure

1. **Build the artifact** from the reviewed tree, and separately from the base commit.
   Both must exist before any probe: every probe below runs against both.
2. **Replay the motivating case.** Reconstruct the incident, transcript, or issue that
   motivated the change and run it verbatim against both builds. Base must exhibit the
   defect; the reviewed build must not. If base passes, the scenario is mis-specified
   or the defect lives elsewhere — this is BLOCKING until a scenario exists that
   discriminates the two builds.
3. **Probe each acceptance criterion** as written in the bead or brief. One executed
   probe per criterion, observing real state: machine-readable output, exit codes,
   files, DB rows, wire bodies — never log prose the binary might not print. A
   criterion with no executable observation is a brief defect; report it as such.
4. **Forensics on "already fixed" and "regression test added".** Prove the broken state
   existed at filing (base build), name the fixing commit, and mutate the fix in a
   scratch copy to prove the new test fails without it. A regression test that passes
   under the mutant discriminates nothing.
5. **Adversarial input on every destructive or irreversible path** the change touches:
   empty string, whitespace-only, unset `$VAR` expansion, path with spaces, the
   sentinel value. Refusal must be proven with before/after state counts, not by
   reading the guard.
6. **Docs state binary truth.** Run every published example, command, and flag in
   changed docs verbatim against the reviewed build; verify every stated default by
   probe. A doc-vs-binary mismatch is BLOCKING even when the code is right.
7. **Gate honesty.** A check the change marks skipped, expected-fail, or "known red" is
   not green. Run it; if it fails, the fix is a hermetic pin (stub network and heavy
   dependencies) that keeps coverage, not documentation of the red.
8. **Then design.** Run the `skill://design-review` probes on the diff.

## Verdict

Per the `oracle` def: itemized BLOCKING with file:line and probe evidence, nits
separate, probe matrix out of band. The matrix rows here are: criterion or claim,
build (base / reviewed), command, observed result. Base-passes-what-the-change-claims
and doc-vs-binary mismatch are always BLOCKING; unverifiable criteria are BLOCKING as
brief defects.
