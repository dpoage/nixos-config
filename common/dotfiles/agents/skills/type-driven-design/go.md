# Type-Driven Design in Go

Go is statically typed but leaves out most of the tools these rules depend on. It
has no sum types and no exhaustive matching. Every type has a zero value that anyone
can construct. There are no move semantics, so a transition cannot consume its
source. And `(T, error)` is a product, not a sum. Defined types and unexported fields
still give you level 1 for distinct meanings and for sealing construction. Linters
get you to level 2 for exhaustiveness. Everything else is level 3 plus 4: one
constructor, and a panic on impossible shapes.

Rule numbers below refer to SKILL.md.

## Contents

- Sums and elimination (rules 1, 2, 5)
- Failure (rule 4)
- Parse, don't validate (rule 3)
- Distinct meanings (rule 6)
- Typestate (rule 7)
- Resources (rule 8)
- Interfaces as propositions (rule 9)
- Parametricity (rule 10)
- Compile-time staging (rule 11)
- Recursive data (rule 12)
- Tooling

## Sums and elimination (rules 1, 2, 5)

```go
// Shape is a closed sum: the unexported method seals it to this package.
//sumtype:decl
type Shape interface{ isShape() }

type Circle struct{ R float64 }
type Rect struct{ W, H float64 }

func (Circle) isShape() {}
func (Rect) isShape()   {}

func Area(s Shape) float64 {
	switch s := s.(type) {
	case Circle:
		return math.Pi * s.R * s.R
	case Rect:
		return s.W * s.H
	default:
		panic(fmt.Sprintf("unreachable shape %T", s))
	}
}
```

- **Sealed interface.** An unexported marker method closes the set of variants to
  the package. Each variant is a struct that carries only its own fields. This
  replaces a struct with a `Kind` field plus fields that only some kinds use.
- **Exhaustiveness is a lint, not a compile error.** `go-check-sumtype` checks type
  switches over interfaces annotated with `//sumtype:decl`, and `exhaustive` checks
  `switch` over iota enums. Run both in CI as errors. The `default` must panic
  unconditionally: go-check-sumtype treats any other `default` as exhaustive
  (`default-signifies-exhaustive`, on by default in golangci-lint), so a `default`
  that logs or returns silences the check. A `default: panic` is the level-4
  backstop, not a wildcard that silently absorbs new variants.
- **A nil interface is an extra inhabitant.** `Shape(nil)` is `Shape + 1`. Reject
  nil at the boundary, or handle `case nil` explicitly.
- **Iota enums.** `type Mode int` with iota constants is open, since any integer
  converts in. Start at `iota + 1` so the zero value is not a valid mode, or make the
  zero value the default mode on purpose. Validate when converting in from outside.

## Failure (rule 4)

- `(T, error)` lets both halves be set at once. The convention is that `T` is the
  zero value whenever `err != nil`. Follow it, and never read `T` before checking the
  error.
- Use typed errors or sentinel `var`s and match them with `errors.Is`/`errors.As`.
  Do not compare error strings.
- When a result has several success shapes, return a sealed-interface sum instead
  of several nilable pointers.

## Parse, don't validate (rule 3)

```go
type Email struct{ v string } // unexported field: only this package sets it

func ParseEmail(raw string) (Email, error) { /* ... */ }
func (e Email) String() string { return e.v }
```

- **Unexported fields block construction with values from other packages.**
  `Email{}` still compiles anywhere, though, and yields the zero value. Either make
  the zero value meaningless and detectable (`func (e Email) Valid() bool` checked
  at the boundary), or design the type so its zero value is valid.
- **Do not export a field, setter, or conversion** that bypasses the parser.
- **Return values, not pointers**, for small validated types, so nil does not become
  an extra inhabitant.

## Distinct meanings (rule 6)

- A defined type (`type UserID int64`) is distinct from `OrderID`, and assigning one
  to the other is a compile error. Two leaks remain: untyped constants convert
  implicitly (`GetUser(5)` compiles), and any package can write `UserID(x)`. When
  construction must be controlled, use a struct wrapper with an unexported field.
- For phantom tags, an unused type parameter works:
  `type ID[T any] struct{ v int64 }`. `ID[User]` and `ID[Order]` are distinct types
  with the same layout.
- Define only meaningful methods. A defined numeric type inherits arithmetic
  operators, so wrap it in a struct when arithmetic is meaningless for it.

## Typestate (rule 7)

- Give each state its own struct type, with methods only for that state's legal
  transitions. A transition returns the next state's type (`func (c *IdleConn) Open()
  (*OpenConn, error)`). Calling a method a state does not have is a compile error.
- **No consumption.** The old value stays usable. A transition on a value receiver
  cannot disable the caller's copy, because it changes only its own copy. To make
  reuse fail loudly (level 4), hold each state behind a pointer. The transition takes
  `*IdleConn`, moves the resource into the new state, and sets the old state's
  resource field to nil. Every method on the old state panics when that field is nil.
  All holders of the pointer then see the old state disabled. Without the pointer,
  reuse is not caught at all; say so in the type record.
- **Long-lived state belongs to one goroutine.** Callers talk to it over channels and
  never hold the state itself, which is the analogue of a process owning the state.

## Resources (rule 8)

- Release with `defer x.Close()` right after acquisition. `io.Closer` is the
  discard-with-cleanup contract.
- To forbid copying, embed a `noCopy` struct (an empty struct with `Lock()`/
  `Unlock()` methods). `go vet`'s copylocks check then flags copies. Hold resource
  types by pointer.
- Nothing forces the caller to use a value; even a discarded error passes `go vet`.
  Add `errcheck` (or golangci-lint's default set) to catch dropped errors.
- Move between mutually exclusive phases by replacing one sealed-interface field,
  not by keeping parallel nilable fields.

## Interfaces as propositions (rule 9)

- Interfaces are satisfied implicitly, which makes them open-world, like concepts.
  Keep them small and define them where they are consumed: accept interfaces, return
  structs.
- Build refinements by embedding (`type ReadCloser interface { Reader; Closer }`).
- Assert conformance at compile time: `var _ io.Closer = (*File)(nil)`.
- In generics, a constraint interface states exactly the operations the body uses.

## Parametricity (rule 10)

- A type parameter constrained by `any` and never inspected is parametric.
- A type switch on `any(x)` inside generic code, or a `reflect` call on it, gives up
  the free theorem. Put type-specific behavior in a method on the constraint or in a
  function parameter.

## Compile-time staging (rule 11)

- Go has no const generics. Array lengths and constants are the only values the
  compiler sees. Stage everything else with `go generate`: `stringer`, generated
  route tables, generated enum validators.
- To reject a bad constant at build time, use a compile-time trick such as an array
  whose length becomes negative when the check fails, or validate in a `go generate`
  step that fails the build. An `init()` panic only fails at startup, which is
  runtime.

## Recursive data (rule 12)

- Recursion goes through pointers, slices, or sealed-interface sums
  (`type Tree interface{ isTree() }` with `Leaf` and `*Node`).
- Write one fold function that takes per-variant callbacks instead of re-writing the
  type switch for every traversal. Goroutine stacks grow, so depth is rarely a
  problem; very deep data still needs an explicit stack.

## Tooling

- `go vet` (copylocks), `staticcheck`, `exhaustive`, `go-check-sumtype`, and
  `errcheck`, all in CI as errors. golangci-lint bundles most of them.
