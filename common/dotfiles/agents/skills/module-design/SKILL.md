---
name: module-design
description: Use BEFORE writing code that adds, splits, or restructures a module — a package, crate, service, subsystem, or a class that owns a decision — and whenever a brief demands a design record (e.g. `bd update --design`). Produces a five-part design record (what the module hides, its interface, its callers, its rewrite cost, its deletion cost) and gates it against deep-module, information-hiding, and YAGNI rules. Trigger on "design", "architect", "structure", "refactor", "simplify", "extract", "reduce coupling", "how should I split this", or any change that introduces a new boundary. For signature-level API decisions load `interface-contract`; for reviewing an existing design load `design-review`.
---

# Module Design

A module is worth its boundary when it is **deep**: a small interface hiding a large
amount of functionality, decisions, or complexity. Depth is the metric. Everything
below either raises depth or detects a boundary that has none.

Vocabulary is Ousterhout (*A Philosophy of Software Design*) and Parnas (information
hiding). Use these terms in the design record so reviewers share the language.

**Module** means the smallest unit with an enforced boundary in the language: a Rust
module, a Go package with its subpackages, a TypeScript directory with one entry file,
a class that owns a decision. Name the unit before applying any rule.

## The design record

Write this BEFORE code, in the bead's `--design` field, a PR body, or the message you
send the orchestrator. Five parts, each one to three lines. Unfinished record → do not
start coding.

1. **Hides.** The decision, format, algorithm, protocol, or invariant that callers must
   never see. Written as "callers do not know that ...". If you cannot finish that
   sentence, there is no module; the code is a function or it belongs in an existing
   module. If the sentence needs an "and" between two verbs or decisions, you have two
   modules; a list of nouns the one secret covers does not count.
2. **Interface.** Every exported name with its signature, in the language's own syntax.
   Include the types callers must construct to use it.
3. **Callers.** Every call site that exists TODAY, by file. Zero → do not build it,
   unless the module is a published library surface or a sibling slice of the same
   round owns the caller; name that surface or slice here. One → inline it unless part
   1 names real complexity being hidden.
4. **Rewrite cost.** "If the internals are rewritten from scratch, the files that
   change are: ..." The list must be the module's own files, its tests, and one
   composition root per binary that constructs its concrete types (main, a wiring or
   factory file); name each root. Any other file on the list is a leak; move the
   leaking knowledge inside or redraw the boundary.
5. **Deletion cost.** "If this module is deleted, the callers in part 3 instead do:
   ..." If the answer is one to three lines each and hides no decision, the module is
   shallow; delete it from the design.

## Raise depth

- **Pull complexity downward.** When a hard case can be handled by the module or by
  every caller, the module handles it — when the case is close to what the module
  already hides and handling it simplifies every caller. When neither holds, the case
  belongs to the caller: a module that absorbs unrelated complexity becomes the next
  thing nobody can change.
- **Define errors out of existence.** Before adding an error path, ask whether the
  operation can be defined so the case is not an error: deleting a missing file
  succeeds; a range clamped to bounds; an empty input returns an empty result. Every
  error the interface exposes is interface surface the caller must handle.
- **Somewhat general-purpose.** The interface names the operation, not today's caller.
  Test: name a second plausible caller and check that it can use the signature
  unchanged. If the second caller needs a different parameter, return shape, or flag,
  the interface mirrors the first caller. The implementation stays specific to what is
  needed now.
- **Hide the decision, not the code.** Draw the boundary around the decision being
  made in this diff (storage format, wire protocol, retry policy, external API shape).
  A reviewer must be able to point at that decision in the code.
- **One place per fact.** A constant, a format, a validation rule, or a mapping lives
  in exactly one module. If two modules must agree on it, one owns it and the other
  imports it. When no single artifact can own it (DDL plus code, generated clients, an
  external spec), write one test that fails when the copies diverge.

## Do not build (YAGNI)

Every abstraction is justified by a caller that exists in this diff, or by a named
decision in part 1 that a reviewer can point at in the code. A roadmap, a comment, or
a "when we add X" is not a justification.

- **Interface with one implementation.** Write the concrete type. Extract the interface
  when the second implementation is in the diff. A test double is not a second
  implementation: inject the concrete type's dependency (clock, transport, store), not
  an interface over your own module.
- **Registry, plugin, or strategy for a fixed set.** Two or three known cases are a
  `match`/`switch`. Four or more cases of identical shape may be a table; every entry
  still exists today.
- **Options object with unused keys.** Remove each key that no caller in this diff sets
  to a non-default value.
- **Configuration for a value nobody changes.** Constants are constants. A config key
  exists because a deployment or test sets it differently today.
- **Extensibility hooks.** Remove event emitters, `before`/`after` hooks, and generic
  type parameters with a single instantiation. A callback the module calls inside a
  scope it owns (transaction, lock, retry, iteration) is not a hook: it keeps the
  ordering rule out of the caller's hands. Keep it.
- **Layers that forward.** Delete a layer whose methods each call one method below with
  the same arguments. Point the callers at the layer below.

## Boundary smells

Recognize these in your own draft and fix before review.

- **Temporal decomposition.** Modules named by *when* they run — `init`, `preprocess`,
  `phase2`, `finalize`, `cleanup`. The sequence smears one format or decision across
  every step. Regroup by the thing hidden, not by execution order.
- **Accreted module.** A module whose part-1 sentence needs an "and" between two
  decisions. Split at the "and". Extending the file already in context is the default
  failure; check part 1 before appending.
- **Duplicate beside the original.** `parser_v2`, `EnhancedClient`, `NewFooEx`. Search
  for an existing module with the same secret before creating one; extend or replace
  it.
- **Pass-through.** A method whose body is a call to another method with the same
  signature. Two interfaces, one piece of functionality. Remove one.
- **`utils`, `helpers`, `common`, `misc`.** Names that state no hidden decision. Move
  each function to the module whose secret it touches, or inline it.
- **Manager, Handler, Processor, Service** as the whole name. The noun says what the
  module *is*, not what it *hides*. Rename to the decision it owns, or merge it into
  the module that owns that decision.
- **Shared mutable context.** A `ctx`, `state`, or `env` object passed everywhere so
  any module can read or write any field, or one lock around the whole state. Every
  module is now coupled to every other through it. Pass the fields each caller needs.
- **Importing a sibling's internals.** `from a.internal import ...` or reaching into a
  private field, including from tests. The boundary is fiction; export it deliberately
  (and add it to part 2) or move the code that needs it.
- **Barrel re-export.** A `mod.rs`, `index.ts`, or `__init__.py` that re-exports every
  name. Each file looks clean; the module hides nothing. Re-export part 2 only.
- **Conjoined modules.** Understanding A requires reading B and understanding B
  requires reading A. Merge them, or find the knowledge they share and give it to one.
- **Config that mirrors implementation.** A config field per internal knob. Callers
  now know the internals. Expose the outcome the caller wants; decide the knobs inside.

## Workflow

1. **Read the existing boundaries.** List the modules the change touches and what each
   one hides today. Extend a module whose secret already covers the new knowledge;
   create a new one only when part 1 names a new secret.
2. **Write the record, then cut it.** All five parts. Apply the YAGNI list to part 2
   and the boundary smells to the names and call graph. Parts 4 and 5 exist to kill
   weak boundaries early; answer them honestly.
3. **Then code.** Part 2 is the contract. If implementation forces a change, update the
   record first and say why.
4. **Hand off.** Give the record to the reviewer. A reviewer using `design-review`
   probes parts 1, 4, and 5; a record that lies about them fails the probe.
