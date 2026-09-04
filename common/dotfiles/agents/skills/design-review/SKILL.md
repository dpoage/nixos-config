---
name: design-review
description: Use when reviewing a diff, branch, PR, or module for architectural quality — module depth, information hiding, cohesion, coupling, speculative generality, and interface cost. Read-only; produces findings with file:line evidence from executed probes, in the oracle verdict format (BLOCKING vs nit). Load in oracle and reviewer briefs whenever the brief says "design", "architecture", "code review", "is this abstraction worth it", "judge against design principles", or the change introduces a new module or public surface. For producing a design load `module-design`; for API decisions load `interface-contract`.
---

# Design Review

Judge three things about each boundary the change touches: is it **deep** (small
interface, large hidden functionality), is its knowledge **hidden** in one place, and
does every piece of structure have a **caller that exists**. A finding is grounded
when it names a file:line and the probe that produced it. Taste without a probe is a
nit, never a blocker.

Vocabulary is Ousterhout and Parnas; the authoring rules live in `module-design` and
`interface-contract`. This skill is the inverse: the same rules, applied as probes.

**Module** means the smallest unit with an enforced boundary in the language: a Rust
module, a Go package with its subpackages, a TypeScript directory with one entry file,
a class that owns a decision. A module whose implementation lives in sibling packages
(ports plus adapters) is one module with them. Name the unit before running any probe.

## Probes

Run every probe that applies. Record raw results (file lists, counts) before writing
findings. To enumerate references, use the language's tooling when present (`go list
-deps`, `cargo tree -i`, an LSP `references` tool if the harness exposes one);
otherwise search the tree for each exported name.

1. **Rewrite probe.** For each new or changed module: "if its internals are rewritten
   from scratch, which files change?" Enumerate them from the import graph and
   references, ignoring test files. Any non-test file outside the module on the list is
   a leak, except a composition root that constructs the module's concrete types — one
   per binary (main, a wiring or factory file). Name each root; a second root in the
   same binary is a leak. BLOCKING when the leaked knowledge is a format, protocol,
   invariant, or decision; nit when it is a name.
2. **Deletion probe.** For each new abstraction (type, interface, layer, helper,
   option, hook): count its callers in the diff and in the tree. Zero callers →
   BLOCKING (speculative), unless the module is a published library surface, a sibling
   slice named in the round owns the caller, or the language requires the symbol
   (trait impls, `MarshalJSON`, exported enum variants). One caller → write what that
   caller does inline instead; if the inline form is one to three lines and hides no
   decision, BLOCKING (shallow). A test double is not a caller.
3. **Surface count.** Count the module's exported names, parameters, error variants,
   and documented caller obligations. Count the non-blank, non-test lines of the
   implementation the module hides, including sibling adapter packages. Fewer than 5
   implementation lines per surface item → shallow; BLOCKING if the module is new,
   nit if pre-existing.
4. **Fact-location probe.** For each constant, format, mapping, or validation rule in
   the diff, search the tree for a second copy, and for an existing module with the
   same secret (`parser_v2` beside `parser`). Two places that must agree → BLOCKING
   when one module can own the fact and the other import it. When no single artifact
   can own it (DDL plus code, generated clients, an external spec), nit; required fix
   is one test that fails when they diverge.
5. **Caller-knowledge probe.** Read each new call site as the caller. List what the
   caller must know that the signature does not say: call order, valid ranges,
   ownership, thread safety, task ownership, which errors to expect. Each item is
   interface surface with no type enforcing it. BLOCKING when a plausible caller
   mistake produces a wrong result silently; nit when it produces a clear failure.
6. **Error-classification probe.** For each error the change introduces: could the
   operation be defined so the case succeeds? Is it a precondition violation that
   should assert inside its trust domain? Does every caller handle two variants
   identically? Each yes is a nit; BLOCKING when a caller in the diff already ignores
   or defaults away the error.
7. **Generality probe.** For each exported name, name a second plausible caller and
   check whether it can use the signature unchanged. A different parameter, return
   shape, or flag needed → the interface mirrors one caller. Nit, unless the second
   caller already exists in the diff (then BLOCKING: it is being duplicated).
8. **Cohesion probe.** For each module the diff grows, finish "callers do not know
   that ..." for its contents as they now stand. A sentence that needs an "and"
   between two verbs or decisions names two secrets; a list of nouns the one secret
   covers does not. BLOCKING when the diff introduced the second secret, nit when it
   widened a pre-existing one.

## Smells no probe reaches

Each hit needs a file:line. Without a confirming probe result these are nits.

- Temporal decomposition: modules or functions named by execution phase.
- `utils` / `helpers` / `common`, or `Manager` / `Handler` / `Service` as the whole
  name.
- Sibling internals imported, private fields reached into, visibility widened for a
  test.
- Shared mutable context object passed through more than two layers; one lock around
  the whole state.
- Barrel file re-exporting every name.
- Untyped bag (`any`, `interface{}`, `Value`, `Record<string, unknown>`) crossing the
  boundary.
- Unlabeled boolean parameters; functions differing by a mode suffix.
- Aliases, deprecated overloads, or shims left for callers that were all migrated.

## What is NOT a finding

- Style, naming preferences, formatting, comment wording.
- "Could be more general" with no second caller. Generality without a caller is the
  defect this skill exists to catch; do not request it.
- Structure the user or bead explicitly asked for. Note the cost as a nit; do not
  block.
- An abstraction whose only caller lands in a sibling slice of the same round. Verify
  the slice exists and owns the call site, then record it as a nit.
- A pre-existing smell the diff did not introduce or widen. Report it as a follow-up
  outside the verdict.

## Verdict

Follow the oracle verdict contract when one is in force: itemized BLOCKING issues with
file:line, the probe result that grounds it, and the required fix; nits in a separate
list; final line `VERDICT: APPROVE` or `VERDICT: REJECT`. Outside an oracle brief,
use the same two lists without the verdict line.

A required fix names the target structure, not only the smell: "inline `normalize()`
into its single caller at `src/parse.rs:88`", "replace `dry_run: bool` with
`Mode::{Apply, DryRun}`", "move the retry policy from `client.rs:40` and `queue.rs:12`
into `retry.rs`; both callers import it".

## Workflow

1. **Read the design record** if one exists (`bd show`, PR body, brief). Parts 1, 4,
   and 5 are claims. Part 1: strike "callers do not know that" and search every caller
   for the named secret; a secret the callers already reference is not hidden, and
   part 1 is then a BLOCKING misstatement. Parts 4 and 5: the rewrite and deletion
   probes test them; a record that understates rewrite cost or overstates deletion
   cost is BLOCKING.
2. **Name the modules** the diff touches, what each hides, and the import edges the
   diff adds.
3. **Run the probes** in order. Record raw results before interpreting them.
4. **Walk the smell list** against the probe results.
5. **Write the verdict.** Each blocker: file:line, probe evidence, required fix. Never
   reject on smells alone.
