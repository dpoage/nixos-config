# Type-Driven Design in Python

The interpreter checks nothing. A static checker (pyright or mypy in strict mode)
checks a lot. With a checker in CI, unions, `match`, `Literal`, `Final`, and
`assert_never` reach level 2: violations are flagged before runtime, almost like
proof. Without a checker, the ceiling is level 3 plus 4: one parsing boundary, and an
exception on impossible shapes. Write every annotation for the checker and every
boundary for the runtime.

Rule numbers below refer to SKILL.md.

## Contents

- Sums and elimination (rules 1, 2, 5)
- Failure (rule 4)
- Parse, don't validate (rule 3)
- Distinct meanings (rule 6)
- Typestate (rule 7)
- Resources (rule 8)
- Protocols as propositions (rule 9)
- Parametricity (rule 10)
- Compile-time staging (rule 11)
- Recursive data (rule 12)
- Tooling

## Sums and elimination (rules 1, 2, 5)

```python
from dataclasses import dataclass
from typing import assert_never  # typing_extensions before 3.11

@dataclass(frozen=True, slots=True)
class Circle:
    r: float

@dataclass(frozen=True, slots=True)
class Rect:
    w: float
    h: float

type Shape = Circle | Rect  # 3.12 syntax; older: Shape: TypeAlias = Circle | Rect

def area(s: Shape) -> float:
    match s:
        case Circle(r=r):
            return math.pi * r * r
        case Rect(w=w, h=h):
            return w * h
        case _:
            assert_never(s)
```

- **Variants.** Make each variant a frozen dataclass carrying only its own fields. A
  single class with a `kind` field and `Optional` fields that depend on it is the
  smell.
- **`case _: assert_never(x)` is the exhaustive form, not a wildcard.** The checker
  narrows `x` to `Never` only when every variant is handled, so adding a variant
  turns that line into a type error. At runtime the same line raises. Pyright's
  `reportMatchNotExhaustive` (on in `strict`) gives the same check without the
  explicit arm.
- **Tag-like values.** Use `Enum` or `Literal["get", "post"]` for payload-free tags,
  never bare strings compared at the use site.
- **Bind and destructure in `case` patterns** instead of chains of
  `isinstance(...)` checks followed by attribute access.

## Failure (rule 4)

- Idiomatic Python reports failure with exceptions, which the checker does not
  track. For expected domain failures that callers must branch on, return a union
  (`Parsed | ParseError`) so the checker forces both branches. Keep exceptions for
  bugs and for failures of the environment.
- `Optional[T]` is `T + 1`. Under strict mode the checker forces the `None` check.
  Do not use `None` to mean both "absent" and "failed".

## Parse, don't validate (rule 3)

```python
@dataclass(frozen=True, slots=True)
class Email:
    value: str

    def __post_init__(self) -> None:
        if not _valid(self.value):
            raise ValueError(f"invalid email: {self.value!r}")
```

- When validation lives in the constructor, the constructor *is* the single
  introduction path. Use `frozen=True` so the invariant cannot be broken after
  construction. To report failure as a value, add a `parse` classmethod that returns
  `Email | EmailError`.
- At external boundaries (JSON, HTTP, config), parse into Pydantic models or
  attrs/dataclasses with validators exactly once. Downstream signatures take the
  model, never `dict[str, Any]`.
- `typing.NewType` is not a validated type. Any code can call `UserId(5)`, and it
  checks nothing at runtime. Use it for distinct meanings, and use a class for
  invariants.

## Distinct meanings (rule 6)

- `UserId = NewType("UserId", int)` is free at runtime, and the checker rejects
  passing a plain `int` or an `OrderId` where a `UserId` is expected.
- For phantom tags, an unused type parameter works:
  `class Id[T]: ...` (3.12), or `Generic[T]` on older versions.
  `Id[User]` and `Id[Order]` are distinct to the checker.
- Mark constants with `Final` and closed sets with `Literal`.

## Typestate (rule 7)

- Give each state its own class, with methods only for that state's legal
  transitions, and make each transition return the next class. The checker flags a
  call to a method the state does not have; at runtime it raises `AttributeError`.
- **No consumption.** The old object stays usable. To make reuse fail loudly, clear
  the resource out of the old object on transition and raise on any later use
  (level 4). For long-lived state, keep it inside one object or task that callers
  message, rather than handing state objects around.
- Mark state classes `@final` so nobody adds states by subclassing.

## Resources (rule 8)

- Scope resources with `with` / `async with`, using context managers or
  `contextlib.ExitStack`. `__del__` is not a cleanup guarantee.
- Nothing prevents copying a reference or dropping a value. Guard against double
  release with an internal sentinel (`self._fd = None` after close) that makes the
  second release a no-op or an error.
- Store mutually exclusive phases as one union-typed attribute that is replaced on
  each transition.

## Protocols as propositions (rule 9)

- `typing.Protocol` gives structural, open-world constraints, the analogue of
  concepts. ABCs give nominal, closed ones. Keep protocols minimal and compose them
  by inheriting one protocol from others.
- `@runtime_checkable` only checks that the methods exist, not their signatures.
  Do not treat it as proof.

## Parametricity (rule 10)

- A function generic over a `TypeVar` (or a 3.12 `def f[T](x: T) -> T`) is
  parametric as long as the body never inspects `T`. `isinstance`, `type(x)`, or
  attribute probing on `x` gives up the free theorem. Route type-specific behavior
  through a Protocol parameter or `functools.singledispatch`, so the dispatch is
  visible.

## Compile-time staging (rule 11)

- The type checker is the only compile-time stage. Use `Literal`, `Final`, and
  overloads keyed on `Literal` arguments to let it see build-time facts.
- Validate configuration and route tables at import time (module level), so a bad
  constant fails at startup and in every test run. Code generation covers the rest.

## Recursive data (rule 12)

- Write recursive aliases with the 3.12 `type` statement
  (`type Tree = Leaf | Node`, with `Node` holding `Tree` children), or with a
  string-quoted forward reference on older versions.
- Write one fold function and pass it the per-variant functions. CPython's
  recursion limit (default 1000) means deep data needs an explicit stack.

## Tooling

- pyright `strict` (or `mypy --strict --warn-unreachable`) in CI as errors. Pyright's
  `standard` mode needs `reportMatchNotExhaustive` set explicitly.
- Ruff for lint. Hypothesis property tests for invariants the checker cannot see.
- Remember that `Any` turns the checker off for everything it touches. Confine it to
  boundary code and parse out of it immediately.
