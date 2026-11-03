# Type-Driven Design in TypeScript

TypeScript's checker has discriminated unions, narrowing, literal and template-literal
types, and exhaustiveness through `never`. With `strict` on, most rules reach
level 1. The type system is unsound by design, though: `any`, `as`, non-null `!`,
bivariant method parameters, and unchecked index access all let values escape it,
and types are erased at runtime. Treat every escape hatch as an introduction path
and count the sites.

Required `tsconfig` settings: `strict`, `noUncheckedIndexedAccess`,
`exactOptionalPropertyTypes`, `noFallthroughCasesInSwitch`.

Rule numbers below refer to SKILL.md.

## Contents

- Sums and elimination (rules 1, 2, 5)
- Failure (rule 4)
- Parse, don't validate (rule 3)
- Distinct meanings (rule 6)
- Typestate (rule 7)
- Resources (rule 8)
- Constraints and parametricity (rules 9, 10)
- Compile-time staging (rule 11)
- Recursive data (rule 12)

## Sums and elimination (rules 1, 2, 5)

```ts
type Shape =
  | { kind: "circle"; r: number }
  | { kind: "rect"; w: number; h: number };

function area(s: Shape): number {
  switch (s.kind) {
    case "circle": return Math.PI * s.r ** 2;
    case "rect":   return s.w * s.h;
    default:       return assertNever(s);
  }
}
function assertNever(x: never): never { throw new Error(`unreachable: ${JSON.stringify(x)}`); }
```

- **Discriminated unions are the sum type.** Each member carries only its own
  fields. One interface with a `kind` field and optional fields that depend on it is
  the smell.
- **`default: assertNever(s)` is the exhaustive form, not a wildcard.** Adding a
  member makes it a type error. You can also enable
  `@typescript-eslint/switch-exhaustiveness-check`.
- **Payload-free tags** are string-literal unions, not `enum`. A numeric enum accepts
  any `number`-typed value; since TS 5.0 only out-of-range literals are rejected.
- **`T | undefined` is `T + 1`.** With `exactOptionalPropertyTypes`, a property that
  is absent is distinct from one that is explicitly `undefined`.

## Failure (rule 4)

- Exceptions are untyped (a `catch` binding is `unknown`). For expected failures,
  return a union: `{ ok: true; value: T } | { ok: false; error: E }`. Callers must
  narrow on `ok` before they can reach `value`.

## Parse, don't validate (rule 3)

```ts
declare const EmailBrand: unique symbol;
export type Email = string & { readonly [EmailBrand]: true };

export type EmailResult = { ok: true; value: Email } | { ok: false; error: "invalid-email" };

export function parseEmail(raw: string): EmailResult {
  return isValid(raw)
    ? { ok: true, value: raw as Email } // the one sanctioned cast
    : { ok: false, error: "invalid-email" };
}
```

- A branded type needs a cast to construct, so the guarantee is exactly as strong as
  the number of `as Email` sites. Keep that number at one. Ban other assertions with
  `@typescript-eslint/consistent-type-assertions` (`assertionStyle: "never"`, with an
  override for the parser module).
- A class with a `private` constructor and a `#private` field is nominal as well, and
  its construction is enforced: only the static parser can call it.
- At runtime boundaries (JSON, fetch, env), parse with a schema library (zod,
  valibot) into branded or class types. `JSON.parse(...) as Foo` is a lie, not a
  parse.

## Distinct meanings (rule 6)

- Brand IDs and units (`type UserId = number & { readonly __brand: "UserId" }`).
  Plain type aliases are structural, so `type UserId = number` separates nothing.
- For phantom tags, put an unused type parameter inside a branded wrapper. The brand
  is what makes the types distinct, because TypeScript ignores type parameters that
  do not appear in the structure.

## Typestate (rule 7)

- Give each state its own type, and give each transition a function that returns
  the next state's type. The checker rejects calling a method a state does not have.
- **No consumption.** References alias freely, and the old state object stays
  usable. A builder that mutates itself and returns `this` cast to the next type is
  unsound if the caller keeps the old reference. Prefer returning fresh objects.

## Resources (rule 8)

- `using` / `await using` with `Symbol.dispose` / `Symbol.asyncDispose` (TS 5.2+)
  gives scoped cleanup. Nothing prevents copying a handle, so guard double release
  with an internal "disposed" sentinel.

## Constraints and parametricity (rules 9, 10)

- Interfaces are structural and open-world. Keep generic constraints
  (`T extends ...`) minimal.
- A generic function is parametric only if its body avoids `any`, `as`, `typeof`/
  `instanceof` on `T`, and overloads. A conditional type (`T extends string ? ...`)
  is a type-level peek, the analogue of C++'s `if constexpr`.

## Compile-time staging (rule 11)

- Literal types, template-literal types, `as const`, and `satisfies` let the checker
  see build-time facts. You can type route patterns, config shapes, and event names
  at the type level (`satisfies Record<Route, Handler>`).
- Types are erased, so anything that must also hold at runtime needs a schema
  derived from the same source, for example `z.infer`.

## Recursive data (rule 12)

- Recursive discriminated unions work directly
  (`type Tree = { kind: "leaf"; v: number } | { kind: "node"; l: Tree; r: Tree }`).
  Write one fold over the union. V8 and SpiderMonkey do not implement proper tail
  calls (only JavaScriptCore does), so deep data needs an explicit stack.
