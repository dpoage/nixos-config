# Type-Driven Design in Rust

Rust gives you most of this series natively. `enum` is the sum type, `match` is
exhaustive, moving out of a value makes the old binding a compile error, and module
privacy makes a single parser enforceable. The main gaps: types are affine but not
linear (dropping a value is always legal), type-level arithmetic on const generics is
unstable, and there is no specialization.

Rule numbers below refer to SKILL.md.

## Contents

- Sums, products, and elimination (rules 1, 2, 5)
- Failure as a value (rule 4)
- Parse, don't validate (rule 3)
- Newtypes and phantom tags (rule 6)
- Typestate (rule 7)
- Resources (rule 8)
- Traits as propositions (rule 9)
- Parametricity (rule 10)
- Compile-time staging (rule 11)
- Recursive data (rule 12)

## Sums, products, and elimination (rules 1, 2, 5)

- Model "or" with an `enum` whose variants carry data; never with a struct plus a
  `kind` field. `Option<T>` is `T + 1` and `Result<T, E>` is `T + E`.
- Do not use `_ =>` over an enum you own. Name every variant, or group variants with
  or-patterns (`A | B =>`). Enforce this with
  `#![deny(clippy::wildcard_enum_match_arm)]`.
- Put `#[non_exhaustive]` on a public enum only when you intend to add variants. It
  forces every downstream crate to add a wildcard, which gives up rule 5 for them.
- Match once and bind payloads with nested patterns, `@` bindings, and `let-else`.
  Do not probe with `matches!`/`is_some()` and then `unwrap()`.
- Guards (`if` in a match arm) fall outside the exhaustiveness check. Keep them few
  and reason about what they leave uncovered.
- Use `clippy::fn_params_excessive_bools` and `clippy::struct_excessive_bools` to
  catch flag soup.

## Failure as a value (rule 4)

- `Result<T, E>` with `?`. When callers branch on the failure, use a typed error
  `enum` (`thiserror` is fine). Use `Box<dyn Error>`/`anyhow` only at the application
  edge, where nobody matches on the error.
- `Result` is already `#[must_use]`. Add `#[must_use]` to other return types that
  must not be dropped.

## Parse, don't validate (rule 3)

```rust
mod email {
    pub struct Email(String);           // private field: Email::parse is the only way in
    impl Email {
        pub fn parse(raw: &str) -> Result<Self, EmailError> { /* ... */ }
        pub fn as_str(&self) -> &str { &self.0 }
    }
    impl TryFrom<String> for Email { /* delegates to parse */ }
}
```

- Field privacy is the boundary, so the module that owns the type is the only place
  that can construct it.
- Leaks to avoid: `pub` fields, `#[derive(Default)]` that yields an invalid value,
  an infallible `From<Raw>`, `DerefMut`, and `&mut` accessors to the inner value.
- At serde boundaries, write `#[serde(try_from = "String")]` so deserializing goes
  through the parser instead of around it.
- Use the standard refinements where they fit: `NonZeroU32`, `NonNull<T>`, `&str`
  rather than `&[u8]` when you mean UTF-8.

## Newtypes and phantom tags (rule 6)

```rust
#[repr(transparent)]
pub struct Meters(f64);

pub struct Id<T> { raw: u64, _t: PhantomData<fn() -> T> }
// manual Clone/Copy/PartialEq/Eq/Hash: derive would add T: Clone etc. bounds
```

- `PhantomData<fn() -> T>` keeps `Id<T>` covariant and `Send + Sync` whatever `T`
  is, and does not make `Id<T>` own a `T` for drop check.
- `#[derive]` on a generic struct adds `T: Trait` bounds even when `T` is only a
  phantom. Implement the traits by hand, or use a derive crate that lets you control
  the bounds.
- Implement `Add` and friends only where the operation is meaningful. Leave out
  `Deref` to the inner type on IDs; the friction is the point.

## Typestate (rule 7)

```rust
pub struct Socket<S: State> { fd: OwnedFd, _s: PhantomData<S> }
pub struct Unbound; pub struct Bound; pub struct Listening;

mod sealed { pub trait Sealed {} }
pub trait State: sealed::Sealed {}

impl Socket<Unbound> {
    pub fn bind(self, port: u16) -> Result<Socket<Bound>, (Self, io::Error)> { /* ... */ }
}
impl Socket<Bound> {
    pub fn listen(self) -> io::Result<Socket<Listening>> { /* ... */ }
}
impl<S: State> Socket<S> { pub fn local_addr(&self) -> io::Result<SocketAddr> { /* ... */ } }
pub fn serve(sock: Socket<Listening>) { /* ... */ }
```

- `self` by value consumes the state, and reusing the old binding is a compile error.
  Rust is stronger than C++ here.
- Take `&self` for operations that may repeat and `self` for terminal ones (`commit`,
  `rollback`, `close`).
- When a transition can fail, hand the source back in the error (`(Self, E)`) so the
  caller keeps the resource.
- Seal the `State` trait so the set of states is closed.
- Use separate structs per state, not `PhantomData`, when the states carry different
  data.
- A step with several outcomes returns an enum (`enum Auth { Ok(Session), Denied(Conn) }`).
- Builders: `Builder<NoHost>` → `Builder<HasHost>`, with `build` implemented only on
  the complete marker combination.

## Resources (rule 8)

- Types are affine by default. Do not derive `Clone`/`Copy` on handles, and release
  the resource in `Drop`.
- Dropping a value is always legal. When dropping without consuming is a bug, use
  `#[must_use]` (it only warns). A "drop bomb" `Drop` that asserts the value was
  consumed is possible, but a panic in `Drop` during an unwind aborts the process;
  reserve it for debug builds.
- Give `into_inner()` / `into_raw_fd()` as the explicit escape hatch.
- `Arc<T>`/`Rc<T>` is the `!` modality; use it only where sharing is real.
- Store mutually exclusive phases in one enum field and replace it on transition, for
  example with `std::mem::replace` or by consuming `self`.

## Traits as propositions (rule 9)

- A trait bound states a capability. Keep bounds to what the body actually calls,
  and put them in `where` clauses on the impls that need them, not on the struct
  definition.
- Use supertraits (`trait Strong: Weak`) for refinement. Use marker traits (no
  methods) for pure propositions. Seal a trait when the set of implementors must
  stay closed.
- There is no specialization on stable, so you cannot dispatch on "most specific
  bound wins". Use separate traits or explicit marker types.

## Parametricity (rule 10)

- An unbounded `fn f<T>(x: T)` is parametric. Each bound declares, in the signature,
  how much the function may peek at `T`.
- `Any`/`TypeId`/`downcast` on a generic parameter gives up the free theorem. Never
  use them inside generic algorithms.
- Coherence plus no specialization means phantom tags cannot be peeked at later from
  another crate, so the guarantee is stronger than in C++.

## Compile-time staging (rule 11)

- Const generics: `[T; N]`, `struct Vec<T, const N: usize>`. Type-level arithmetic
  (`N + M` in a generic signature) needs the unstable `generic_const_exprs`; on stable,
  use `typenum` or restructure.
- `const fn` for compile-time parsing. An inline `const { assert!(...) }` block, or a
  `const _: () = assert!(...);` item, turns a bad constant into a build error.
- Use `macro_rules!`, proc macros, or `build.rs` to stage route tables and schemas
  into generated `match` arms.

## Recursive data (rule 12)

- Recursion needs `Box`, `Vec`, or `Rc` indirection.
- A fold is a `match` that recurses on its children. For lists use
  `Iterator::fold`. Write one traversal and pass the per-variant algebra as closures
  or a trait.
- There is no guaranteed tail-call optimization, so very deep trees need an explicit
  stack.
