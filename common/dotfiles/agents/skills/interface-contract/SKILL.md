---
name: interface-contract
description: Use when adding or changing anything a caller depends on — a function signature, exported type, trait/interface, CLI flag, config key, wire format, or error. Governs how narrow the surface is, which states are representable, how errors are classified, and what the caller must know. Trigger on "API", "signature", "public", "export", "contract", or when a review flags a boolean parameter, an ordering requirement, an untyped bag, or a leaked internal type. For module boundaries load `module-design`; for reviewing existing surfaces load `design-review`.
---

# Interface Contract

An interface is the sum of everything a caller must know to use the module correctly.
Signatures are the visible part; call order, valid ranges, ownership, thread rules, and
error handling are the rest. The design goal is the **smallest sum**, not the fewest
functions. One function with four booleans has a larger interface than three functions
with none.

## Signature rules

- **Make invalid states unrepresentable.** If two fields cannot both be set, the type
  is a sum type, not two optionals. If a value has a valid range, the parameter type
  carries the range: a newtype, an enum, a non-empty collection. Not a comment. A check
  the type system enforces is a check nobody forgets.
- **Name identities.** An id, a path, a scope, and a key are four types, not four
  `String`s. A newtype costs one line and removes a class of caller mistakes.
- **No untyped bags across the boundary.** `any`, `interface{}`, `Value`,
  `Record<string, unknown>`, `**kwargs` in a parameter or return move the contract into
  prose. Name the fields, or name the closed set of variants.
- **No unlabeled boolean parameters.** `f(x, true)` says nothing at the call site. In a
  language without argument labels, use an enum with named variants or two functions.
  A labeled field or keyword argument (`IncludeExpired: true`) names itself; two
  booleans in one signature are still a mode enum.
- **No ordering requirements.** If `b()` is only valid after `a()`, either `a()`
  returns the token `b()` needs, one function does both, or the module runs the
  caller's code inside a scope it owns (`with_tx(fn)`). A caller cannot see an
  ordering rule in a signature; therefore it does not belong in the contract.
- **No pass-through parameters.** A parameter a function receives only to hand to
  another function exposes the lower function's needs to the upper caller. Give the
  function what it uses. If several layers forward the same value, it is a field of
  the object or a real dependency of the top layer.
- **Return what the caller needs, not what you have.** Returning an internal struct,
  a database row, or a raw handle exports the implementation. Map to a type the
  interface owns.
- **Ownership and lifetime in the signature.** The type or the name (`take_`, `into_`,
  `borrow`) states whether the callee takes, borrows, copies, or retains the argument.
  Callers do not read the body to find out.
- **Symmetry.** `open`/`close`, `acquire`/`release`, `push`/`pop`. An operation with an
  inverse has one, named as the pair, and the pair lives in the same interface.
- **Defaults at the boundary, not in every caller.** If most callers pass the same
  value, the function has a form that omits it.

## Generality

The interface is **somewhat general-purpose**: it names the operation, not the caller.
The implementation is special-purpose: it does what the current callers need and no
more.

Test each exported name: name a second plausible caller and check that it can use the
signature unchanged. If the second caller needs a different parameter, return shape,
or flag, the interface mirrors the first caller and will be duplicated for the second.
Renaming `getDashboardRows` to `queryRows` does not pass this test; changing the
parameters so both callers fit does.

Do not go further. Remove a parameter, generic, or mode that no caller in the diff
uses. General *interface*, minimal *implementation*.

## Errors

Every error the interface can produce is contract surface. Classify each one.

1. **Defined out of existence.** The operation is specified so the case is a success.
   Delete a missing file: success. Insert a key that exists: overwrite, or return the
   previous value. Empty input: empty output. Substring past the end: clamped. Choose
   this whenever the caller's next line would have been "ignore this error".
2. **Contract errors** the caller can act on. Named, typed, enumerated in the
   signature or the doc. Each variant is distinct because a caller handles it
   differently; two variants every caller handles identically are one variant.
3. **Bugs.** Precondition violations, impossible states, corrupted invariants. Inside
   one trust domain these are assertions or panics, not error values: returning them
   forces every caller to branch on "the program is already wrong". At a process,
   request, plugin, or FFI boundary, convert the bug to an error or a recovered failure
   at that boundary. A library that panics takes down its host.

Rules that follow:

- **Handle at the layer that can decide.** Catch an error where the code knows what
  to do about it. Layers that only wrap and rethrow add surface and lose information.
- **No re-validation.** Validate at the boundary where untrusted data enters; inside,
  trust the types. A second check on an already-typed value means the type is not
  carrying its guarantee. A deliberate second check at a privilege boundary is defense
  in depth, not re-validation; say so in the code.
- **Never mask.** Catching, logging, and continuing is a hidden contract change every
  caller now depends on without knowing. `unwrap_or(default)`, `?? {}`, `|| []`, and
  `except: pass` on a failure path are the same change: they fabricate a result.

## Interface smells

- A doc comment longer than the implementation: the surface is larger than the
  functionality. Deepen or delete.
- Signature has more than four parameters: two or more belong together in a type, or
  the function does two things.
- `Option`/`nullable` on a parameter that every caller passes as `Some`: it is
  required.
- A function that returns `bool` to signal success: the failure carries no
  information. Return the error or define it away. (A predicate returning `bool` as
  data is fine.)
- `*Config`, `*Options`, `*Params` type with a field per internal knob: exposes the
  implementation. Expose the outcome and choose the knobs inside.
- Two functions differing by one suffix (`get`, `get_or_default`, `get_unchecked`,
  `try_get`): one operation with modes. Keep the modes a caller in the diff uses.
- Global or thread-local read inside a pure-looking function: hidden input. Make it a
  parameter or a field of the receiver.
- `async` on a function because one callee is async, or a spawned task with no owner
  that joins or cancels it: the caller inherits a runtime obligation the signature
  does not name.
- Visibility widened for a test (`pub(crate)` → `pub`, `_private` reached from a test
  file): the test is coupled to the implementation. Test through the interface, or the
  interface is missing an operation.
- In a binary or internal package, an exported name with zero callers outside its own
  module: it is not exported. In a published library, plugin ABI, or FFI surface, the
  callers are downstream; name that surface in the design record instead.

## Workflow

1. **List the surface.** Every exported name, parameter, field, error variant, and
   documented rule the caller must obey. That list is the interface.
2. **Apply the rules** in order: signature, generality, errors. Each pass shrinks the
   list or replaces a documented rule with a type.
3. **Write the doc comment last.** It states the contract that survives step 2: what
   the operation does, what it returns, which errors are possible and when. If a
   sentence describes how the implementation works, delete it.
4. **Migrate every caller** in the same change. No aliases, deprecated overloads, or
   compatibility shims unless the user asks for them: a shim is interface surface with
   zero intended callers.
