---
name: bug-hunt
description: Use when probing a named unit (package, adapter, state machine, test suite) for latent defects by executing adversarial inputs and paths nobody tested — on demand, before a release, or as the adversarial-correctness oracle in an oracle round. Read-only; every finding rests on an executed probe with a base-commit observation and lands as a bead. Trigger on "hunt bugs", "what else is broken here", "probe this adapter", "find latent defects". For a diff's design load `design-review`; for acceptance of a change load `acceptance-replay`.
---

# Bug Hunt

Ask "what does this unit do on inputs and paths nobody wrote a test for?" — then run
them. A finding rests on an executed probe with file:line, a reproduction, and a
base-commit observation; a finding from reading alone is a hypothesis and is not filed.
Read-only on the tree: probes run in scratch copies (`/tmp`), findings become beads,
never fix, never weaken a test to make a probe pass.

## Scope and seeds

Name the unit first (a package with its internal siblings, one adapter, one test
file). When the user names none, pick by yield, highest first: units with N sibling
implementations of one interface; test files dense in skip/retry/tolerance; units
with prior oracle REJECTs or flake history; units that write to an external contract
(wire, DB schema, vendor API). Do not sweep a repo.

Compose the repo's own shipped pieces end to end for every probe; "unreachable via
shipped code" is a claim to falsify, not a reason to stop.

## Families by unit shape

| Unit shape | Run |
|---|---|
| N implementations of one interface (adapters, decorators, drivers) | 1, 3, 4 |
| Fields with a documented invariant between them | 2 |
| Guards, sentinels, classifiers on untrusted input | 3 |
| Writes to an external contract with documented incompatibilities | 4 |
| Test suite with skips, retries, tolerances, or ordering assertions | 5, 6 |
| Docs or godoc that count or close a set | 7 |
| Always, on every candidate finding | 8 |

1. **Sibling predicate.** For every guard, trim, sentinel compare, or classification
   in the unit, find the same predicate shape in each sibling. Run one adversarial
   input set through every copy; tabulate divergence. A sibling missing a fix its
   peer has is a bug in the sibling.
2. **Last writer.** For each invariant between fields, enumerate every writer of each
   field — every assignment, including post-constructor stages (finalize, decorators,
   retry stitching), not just the line that "always sets it". Drive the real producer
   over a stub for each stage; assert the invariant on the result. The bug is the
   stage that writes after the invariant was established.
3. **Guard input matrix.** For every input a guard classifies: nil; empty; the literal
   sentinel; sentinel with each whitespace class the decoder tolerates and each it
   does not; empty container with inner whitespace; typed-but-empty; valid-padded;
   malformed. Two columns per row: local outcome, and what reaches the far side (count
   with a stub). A row that reaches the far side with a payload the contract calls
   invalid is a bug. Mark which rows the repo's own serialization can produce and which
   need hand-built input.
4. **Contract cross product.** From the external contract's documented incompatibilities
   (fields that cannot co-occur, modes that force others), build request fields ×
   capability flags — including synthetic fields the unit adds itself — capture the
   full body per cell, and mark cells that emit a documented-invalid combination. Quote
   the contract sentence verbatim with its scope words.
5. **Skip-masks-regression mutation.** For every test that skips or retries on a
   premise, mutate production to break the contract the test guards, run the test: a
   skip instead of a failure means run the whole hermetic suite under the mutant. Green
   suite + skipping test = coverage hole; required fix is a
   hermetic pin — a test, not a new runner or gate — that fails under the mutant.
6. **Path-dependent assertions.** For every equality, ordering, or tolerance assertion
   over a quantity produced by more than one runtime path (single pass, retry,
   continuation, empty-turn), script each path hermetically and check the assertion
   on each. For a reported flake: reproduce the exact message against a stub serving
   the reported vector, derive the correct bound from the data source's precision,
   construct the vector that attains it, and scan the file for the same family (map
   iteration order, argmax ties, `%g` of an inexact bound). Run candidates 24× per
   orientation.
7. **Closed-enumeration doc probe.** Every sentence that counts or closes a set ("two
   rejection paths", "never interpreted", "always populates") is a claim; search the
   matrices from 3–4 for a further member or counterexample. A doc-vs-binary lie is a
   finding even when the code is right.
8. **Baseline forensics.** Run each reproduction against the base commit. Fails-on-base:
   real defect, discriminating repro. Passes-on-base: the repro is wrong or the defect
   was introduced later — find the introducing commit. No base observation, no bead.

## Output

A finding is a bead, never a fix and never new work for the round in flight. Run as an
oracle seat, a defect outside the reviewed diff that no criterion of the slice's bead
covers is filed and reported as a `SCOPE:` note: it never becomes a blocker, and it
never grows the slice.

One bead per finding, `--type=bug` (wrong behavior) or `--type=task` (coverage gap),
with: impact class — `wire-invalid`, `silent-data-loss`, `wrong-output`,
`coverage-gap`; family; reproduction (stub shape, inputs, command); base-vs-current
observation; file:line of the defect and of the last writer or guard; the contract or
doc sentence verbatim where one applies; one-sentence fix; `history://` link to the
hunt. Duplicates of open beads are comments on the existing bead.

Close with the probe matrix (family × probes × result, null results included) — when
run as an oracle this is the `Coverage:` matrix the verdict contract requires.
