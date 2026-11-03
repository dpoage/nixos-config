---
name: type-driven-design
description: Use when a task or brief asks to design or encode a domain type, state machine, resource handle, or validation boundary so that illegal states cannot be represented and invalid transitions do not compile. Covers algebraic data types and cardinality, parse-don't-validate, exhaustive matching, newtypes and phantom tags, typestate, move-only/affine resources, constraints as propositions, parametricity, compile-time staging, and folds over recursive data, with per-language files for C++, Rust, Go, TypeScript, Python, and Elixir. Trigger on "make invalid states unrepresentable", "parse don't validate", "typestate", "newtype", "phantom type", "sum type", "algebraic data type", "exhaustive match". Not for routine edits to existing types, module boundaries (`module-design`), caller-visible surfaces and error classification (`interface-contract`), or review (`design-review`).
---

# Type-Driven Design

A program is a theory of its domain, and the type checker is the first reviewer of
that theory. Most bugs are failures of representation: two things that should not mix
were allowed to mix, a function ran at the wrong time, a check was forgotten, or the
domain was modeled too loosely. Fix those with better types, not more defensive code.
The goal is not to write better functions. It is to design a world where bad
functions cannot exist.

Source: Ayush Bhat, *Type-Theoretic C++*, 11 parts, starting at
<https://loomblog.com/post/type-theoretic-foundations>. The rules and vocabulary below
come from that series. The enforcement ladder and the type record are this skill's
additions. The language files map the rules onto each type system.

## Where this fits

The design skills split by scale. Each one owns its rules, and the reviewer applies
all of them.

| Skill | Scale | Question |
|---|---|---|
| `module-design` | Module | Where does a boundary go, and what does it hide? |
| `interface-contract` | Surface | What must a caller know, and which errors can it see? |
| `type-driven-design` | Type | Which states can a value represent, and which calls compile? |
| `design-review` | All three, as probes | Does the diff obey the rules above? |

This skill is the mechanism layer. When `interface-contract` says "make invalid
states unrepresentable", "name identities", "no ordering requirements", or "ownership
and lifetime in the signature", this skill gives the techniques and their
per-language encodings. It also governs types that never cross a boundary, which
`interface-contract` does not cover. Error classification (define out of existence,
contract error, or bug) belongs to `interface-contract`.

## Language files

Before writing code, read the file for your target language:

| Language | File | Enforcement ceiling |
|---|---|---|
| C++20/23 | `skill://type-driven-design/cpp.md` | Compile-time proof through templates, concepts, `variant`, NTTPs. Affine at best; use-after-move is UB, not a type error. |
| Rust | `skill://type-driven-design/rust.md` | Compile-time proof, plus use-after-move is a compile error. Affine, not linear. |
| Go | `skill://type-driven-design/go.md` | No sum types, no move, and anyone can construct the zero value. Defined types and unexported fields give compile-time separation; exhaustiveness comes from linters. |
| TypeScript | `skill://type-driven-design/typescript.md` | Compile-time proof under `strict`, but unsound by design (`any`, `as`). Types are erased, so runtime boundaries need schemas. |
| Python | `skill://type-driven-design/python.md` | Proof only from an external checker (pyright/mypy strict). The runtime enforces nothing beyond constructors and `match`. |
| Elixir / Erlang | `skill://type-driven-design/elixir.md` | Structural matching that crashes at runtime, plus gradual type checking and Dialyzer warnings. There is no static proof of totality or ordering. |

**Other languages.** Apply the core rules here and pick the strongest level of the
enforcement ladder the language reaches. Use its native sum type, its newtype or
branded type, and its exhaustiveness check (for example Haskell `data`/`newtype`,
Kotlin `sealed` classes with `when`, Swift `enum` with `switch`). State in the design
which level you reached.

### The enforcement ladder

The principles do not depend on the language. What changes is where a violation is
caught:

1. **Unconstructible.** The illegal value or call does not type-check (Rust, C++, Haskell).
2. **Statically flagged.** An analyzer warns before running (Dialyzer, the Elixir
   type checker, `-Wswitch`, clippy).
3. **Rejected at one boundary.** A single constructor or parser refuses bad input,
   and everything downstream assumes validity.
4. **Crashes at the use site.** A non-matching clause raises immediately (Elixir
   function heads, `FunctionClauseError`).
5. **Defended everywhere.** Scattered `if (!valid)` checks. This is the condition
   being designed away. Never choose it.

Take the highest level the language allows. When proof is unavailable, combine 3
and 4: one introduction path, and loud failure everywhere else. Never fall through
to 5.

## The design questions

Answer these before writing a type. They are the formation, introduction, and
elimination rules of the domain.

1. **What exists?** The entities themselves, not the operations on them.
2. **Formation.** When is each type valid? What must hold for a value to exist?
3. **Introduction.** How are values created, and what evidence does each constructor
   demand?
4. **Elimination.** How are values used? What must the consumer handle?
5. **What is impossible?** List the contradictions the types must rule out.
6. **What is decidable before runtime?** Anything that depends only on program
   structure: routes, schemas, units, protocol shapes, configuration.
7. **What is left for runtime?** Only what depends on the outside world: input,
   network, files, clocks.

## Rules

1. **Count inhabitants.** A product multiplies the cardinalities of its fields; a sum
   adds them. Compare the count with the number of meaningful domain states. Every
   extra inhabitant is a state some function must later forbid by convention.
   `{kind, radius, width, height}` has `3 × ℝ³` inhabitants where the domain has
   `ℝ + ℝ² + ℝ²`.
2. **Use sums for "or" and products for "and".** A discriminant field next to a bag of
   fields, only some of which are live, is a product pretending to be a sum. Replace
   it with a real sum type whose variants carry only their own data. "Products
   overcommit. Sums commit exactly once." Factor a field out of the sum only when
   every variant uses it the same way (`A × (B + C) ≅ A×B + A×C`).
3. **Parse, don't validate.** Give each invariant a raw type and a validated type,
   with exactly one introduction path (the parser) between them. The parser returns
   either the validated value or an error. Code downstream takes the validated type
   and never checks again. A guarantee is only as strong as its narrowest
   introduction path, so count the construction sites. One exception, owned by
   `interface-contract`: "A deliberate second check at a privilege boundary is
   defense in depth, not re-validation; say so in the code."
4. **Make failures values.** A failure the caller acts on is a sum type
   (`Result`/`expected`/`{:ok, _} | {:error, _}`), never a sentinel value, a `bool`
   plus an out-param, or an undocumented throw. Success data must be unreachable in
   the failure branch. Which cases are failures at all, and which are bugs, is
   decided by `interface-contract`'s error classification, not here.
5. **Eliminate exhaustively.** Pattern matching is the elimination rule, so handle
   every introduction form. Do not use a wildcard or `default` over a sum you own: it
   turns "a new variant breaks the build at every site" into silent wrong behavior.
   Bind and destructure in one match instead of re-testing with
   `is_x`/`get_if`/`holds_alternative`. Guards are outside the exhaustiveness check,
   so reason about the cases they leave by hand.
6. **Give each distinct meaning its own type.** IDs, units, and validated strings get
   a newtype or phantom tag. Make wrapping and unwrapping explicit, with no implicit
   conversion. Expose only the operations that make sense: two lengths may be added,
   two IDs may not. "If two things should not be interchangeable, they should not
   have the same type." A tag like `Validated` is a proof witness, so take it as a
   parameter instead of re-validating.
7. **Put state in the type (typestate).** Give each protocol state its own type
   holding exactly that state's data. A transition consumes the source state and
   returns the target. An illegal transition does not exist as a method; it is never
   a method that throws. A step with several possible outcomes returns a sum.
   Operations that can repeat borrow the state; terminal operations consume it. An
   API that needs setup to have finished takes the final state type
   (`Server(Socket<Listening>)`).
8. **Classify every resource type.** For each type that holds a resource, decide
   whether it can be copied, whether it can be discarded, whether it must be used,
   and whether transitions must consume it. Unique owners forbid copying. Moving out
   leaves a sentinel that the destructor checks. A handle the caller must not drop is
   marked must-use, and the only way out of the obligation is an explicit
   `release`/`into_inner`. Shared ownership is the unrestricted `!` modality; use it
   only when sharing is real. Move between mutually exclusive phases destructively
   (one sum that gets overwritten), never through parallel nullable fields.
9. **Treat constraints as propositions.** A trait, concept, or behaviour states a
   capability. Require only the obligations the consumer actually uses. Build
   stronger constraints by conjoining weaker named ones, and keep orthogonal
   capabilities in separate constraints that are combined at the use site. A
   precondition written in a comment belongs in the signature. Prefer exact
   constraints (`same_as`) to permissive ones (`convertible_to`) when you mean
   exactly that type.
10. **Keep generic parameters opaque (parametricity).** A function that never
    inspects `T` must treat every `T` the same way, and that gives you theorems for
    free: `∀T. T → T` is the identity, and a function `[T] → [T]` can only
    rearrange, duplicate, or drop elements. Prefer signatures with few inhabitants.
    Every type-inspecting branch, specialization, or runtime type check on a
    parameter removes a free theorem. When you peek, do it deliberately and say so.
    Test a parametric function at one or two instantiations.
11. **Decide at the earliest stage possible.** Facts known at build time (routes,
    config shapes, dimensions, format strings, ports) belong in the compile-time
    phase: constant generics, `consteval`, macros, module attributes. A rejected
    constant is then a build error. Only facts about the outside world stay at
    runtime.
12. **Give recursive data its shape first.** Write the one-layer shape (`1 + T×X` for
    a list, `T + X×X` for a tree) before writing any recursion. Express each
    traversal as a fold: one skeleton, one algebra per operation. Recursion must go
    through indirection (box, vector) and recurse on structurally smaller parts.
13. **Choose the extension axis on purpose.** A closed sum with open operations makes
    new operations cheap and new variants cross-cutting. Open interfaces with closed
    operations do the reverse. Decide which axis will grow and record the choice.

## Smells

| Smell | Replace with |
|---|---|
| `bool` flags or nullable fields that encode progress (`connected`, `response?`) | A type per state, with consuming transitions |
| `enum kind` + fields that are valid only for some kinds | A sum type whose variants carry their own data |
| `f(x, bool a, bool b)` where some combinations are meaningless | An enum of the meaningful modes |
| Adjacent parameters of the same primitive type (`int passenger, int flight`) | Newtypes or phantom-tagged IDs |
| The same validity check repeated downstream | A validated type produced once at the boundary |
| `bool parse(in, Out& out)`, `-1` sentinel, `nil` meaning failure | A result sum type |
| `default:` / `_ ->` / catch-all over a sum you own | One explicit arm per variant |
| `if state != X { throw }` at the top of methods | The method exists only on state X's type |
| A builder whose `build()` re-checks required fields | Per-step builder types; `build` only on the complete one |
| A transition that takes `&mut self`/`T&` and leaves the old state usable | Take the state by value or move and return the next state |
| A copyable handle that has a destructor | Move-only, sentinel on move, must-use |
| A type-trait branch or specialization inside a generic algorithm | A policy or capability parameter; keep the body uniform |
| Runtime parsing or branching on a build-time constant | A compile-time constant, `if constexpr`, a macro, or a const generic |
| The same recursive walk hand-written five times | One fold plus five algebras |
| "Must not be X" written only in documentation | A type or constructor that makes X unconstructible |

## When not to

- **Plain data.** DTOs, config records, and rows where every field combination is
  meaningful keep public fields. Getters add ceremony and no safety.
- **Distinctions that stay inside one function** need no tag. Tags pay off across
  function boundaries.
- **Typestate** is for cases where a violation would be a serious bug: auth, resource
  lifecycle, wire protocols, and library APIs. Inside a module that owns every call
  site, or for UI and config state, a runtime enum is fine. Ask: would a violation be
  a serious bug?
- **If you need to discriminate at runtime**, use a sum. Phantom tags cannot be
  inspected.
- **Refinements via tags** express boolean properties set once (validated,
  sanitized, encrypted). They cannot express arbitrary predicates. For those, use a
  parser.
- **Never build ceremony that only looks safe.** A branded type with ten cast sites,
  or a typestate the language lets you alias around, guarantees nothing. Either
  narrow the introduction path or drop down the ladder honestly and fail loudly.

## Workflow

**Authoring.**

1. Answer the design questions.
2. Write the types before the functions.
3. For each new domain type, state machine, or resource handle, write a type record.
   Copy this checklist:
   ```
   Type record: <type>
   - [ ] States and inhabitant count (meaningful vs representable)
   - [ ] Introduction paths (the parser, and every other construction site)
   - [ ] Elimination sites (matches, switches, visits over it)
   - [ ] Ladder level reached, and why not higher
   - [ ] Extension axis: new variants or new operations (rule 13)
   ```
4. Put the record where the design record goes (the bead's `--design` field, the PR
   body, or the brief reply), next to the `module-design` record when there is one.
5. Write the functions. If a function body starts with a defensive check, go back to
   step 2 and tighten the type.

**Reviewing** is `design-review`'s job (type probes 9–14), not this skill's.
