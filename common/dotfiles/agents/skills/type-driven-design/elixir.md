# Type-Driven Design in Elixir / Erlang

There is no static proof here. Nothing makes an illegal struct unconstructible, a
match total, or a transition ordered at compile time. The discipline still applies;
what changes is the enforcement ladder in SKILL.md. Aim for level 3 (one boundary
rejects bad input) combined with level 4 (any other shape crashes at the use site),
and get level 2 warnings from typespecs, Dialyzer, and the compiler's gradual type
checker. Never fall to level 5, where defensive `if valid?` checks are scattered
through the code.

"Let it crash" is level 4: write only the clauses for valid shapes and let a
`FunctionClauseError` or `CaseClauseError` report the contradiction. A catch-all
clause that logs and returns a default is level 5 dressed up as resilience.

Rule numbers below refer to SKILL.md.

## Contents

- Sums, products, and elimination (rules 1, 2, 5)
- Failure as a value (rule 4)
- Parse, don't validate (rule 3)
- Distinct meanings (rule 6)
- Typestate (rule 7)
- Resources (rule 8)
- Contracts (rule 9)
- Parametricity (rule 10)
- Compile-time staging (rule 11)
- Recursive data (rule 12)
- Tooling

## Sums, products, and elimination (rules 1, 2, 5)

- **Sums.** Use tagged tuples (`{:ok, v} | {:error, reason}`), atoms for payload-free
  enums, and one struct per variant (`%Circle{r: _}`, `%Rect{w: _, h: _}`). Never use
  one struct with a `kind` field and fields that are nil depending on it. Spell the
  union out in a `@type`.
- **Products.** Use structs with `@enforce_keys`. These are enforced by `%S{}`
  literals and `struct!/2`, not by `struct/2` or `Map.put`.
- **Elimination.** Write one function head or `case` clause per tag. Do not add a
  `_ ->` clause over a union you own, because a new tag should crash at every site
  that has not handled it. Match and bind in the function head
  (`def area(%Rect{w: w, h: h})`); do not probe with `is_map`/`Map.has_key?` and
  then fetch.
- **Atom sets.** Keep the set in one module attribute and check it at the boundary
  with a guard (`when status in @statuses`). Do not compare against string literals
  scattered through the code.
- **Coverage.** Neither the compiler nor Dialyzer proves a `case` exhaustive. Cover
  the variants with tests: one per variant, or a StreamData generator over the whole
  union.

## Failure as a value (rule 4)

- Return `{:ok, v} | {:error, reason}` and chain with `with`. Write the `else`
  clauses for the specific errors, or leave `else` out so `{:error, _}` passes
  through. An `else _ ->` swallows the cases you did not expect.
- A bang function (`fetch!`) is for when failure is a bug, not a branch.
- Do not return `nil` to mean failure, and do not let the success value leak into
  the error tuple.

## Parse, don't validate (rule 3)

```elixir
defmodule Email do
  @enforce_keys [:value]
  defstruct [:value]
  @type t :: %__MODULE__{value: String.t()}

  @spec parse(String.t()) :: {:ok, t} | {:error, :invalid_email}
  def parse(raw) when is_binary(raw) do
    if valid?(raw), do: {:ok, %__MODULE__{value: raw}}, else: {:error, :invalid_email}
  end

  @spec to_string(t) :: String.t()
  def to_string(%__MODULE__{value: v}), do: v
end

def send_welcome(%Email{} = to), do: ...   # no re-check downstream
```

- **Introduction is not private.** Any module can write `%Email{value: "junk"}`.
  In review, grep for `%Email{` outside `Email`; that grep is the introduction probe.
  Do not declare the type `@opaque` here: outside the module, Dialyzer treats a
  pattern match on an opaque type as an opacity violation, so `@opaque` and
  function-head matching cannot be used together.
- **External maps** (params, JSON, config) go through one parser module. An Ecto
  embedded schema with a changeset and `apply_action/2` works well. Downstream code
  receives the struct, never the raw map.
- A function head that matches `%Email{}` guarantees the shape, not validity. The
  single introduction path is what makes the shape imply validity.

## Distinct meanings (rule 6)

- A `@type user_id :: pos_integer()` alias is documentation only. Dialyzer types are
  structural, so it cannot tell `user_id` from `order_id`.
- For real separation, wrap the value in a struct (`%UserId{id: 1}`) or a tagged tuple
  (`{:user_id, 1}`) and match on the wrapper in function heads. This costs a word or a
  small map at runtime. There are no zero-cost phantoms on the BEAM.
- Use `@opaque` only for wrappers that callers never match on. Callers then pass the
  value through `@spec`-typed functions, and checks move from function heads
  (level 4) to Dialyzer (level 2).

## Typestate (rule 7)

```elixir
defmodule Conn do
  defmodule Idle, do: defstruct [:host]
  defmodule Open, do: defstruct [:host, :socket]
  defmodule Closed, do: defstruct [:host]

  @spec open(Idle.t()) :: {:ok, Open.t()} | {:error, term}
  def open(%Idle{host: h}), do: ...
  @spec send(Open.t(), iodata) :: :ok | {:error, term}
  def send(%Open{socket: s}, data), do: ...
  @spec close(Open.t()) :: Closed.t()
  def close(%Open{} = c), do: ...
end
```

- Give each state its own struct. Each transition has one head that matches only its
  source state, so calling it in the wrong state raises `FunctionClauseError`.
  Ordering is enforced at runtime, not proven; `@spec`s let Dialyzer catch some
  misuse.
- **Old values stay usable.** Data is immutable, so the `%Open{}` you held before
  `close/1` still exists and still names the same socket. Thread state through a
  pipe or a rebinding instead of holding onto old versions.
- **Unaliasable state lives in a process.** Put it in a GenServer, or in a
  `:gen_statem` in `state_functions` mode, where each state is its own callback
  function. An event that the current state has no clause for crashes, or is
  postponed on purpose. Callers hold a pid, never the state.

## Resources (rule 8)

- **Process ownership is the BEAM's affine discipline.** A port, socket, or ETS table
  belongs to one process and is cleaned up when that process dies. Transfer it
  explicitly (`:gen_tcp.controlling_process/2`, `:ets.give_away/3`), and link or
  monitor the processes that depend on it.
- **Scoped cleanup.** Use `try ... after`, or an API that takes a callback
  (`File.open(path, fn f -> ... end)`) so the resource is released even on crash.
- **Phases.** Use one `phase` field holding a tagged value (`{:reading, buf}` /
  `{:writing, iodata}`) and replace it on each transition. Do not keep parallel
  nullable fields.

## Contracts (rule 9)

- **`@behaviour` with `@callback`** is a closed, named contract. The compiler warns
  when an implementing module is missing a callback.
- **`defprotocol`/`defimpl`** is open-world dispatch on the data type, the analogue
  of a concept or trait.
- **Guards express small propositions** at function heads. Keep them to guard-safe
  checks on the shape and type of the input.

## Parametricity (rule 10)

- Write generic specs with type variables: `@spec map([a], (a -> b)) :: [b] when a: term(), b: term()`.
- A generic function must not branch on its element's type
  (`is_binary`/`is_map`/struct matches). Type-specific behavior goes through a
  protocol or a function argument. The runtime cannot enforce this, so it is a
  review item.

## Compile-time staging (rule 11)

- Module attributes and macros are the compile-time stage. Generate one `def`
  clause per route or schema entry from a compile-time list, with no runtime table
  lookup. `raise` inside the macro or at module level to reject a bad constant at
  build time.
- `Application.compile_env/3` for build-time config. Validate it at compile time,
  in the module body.
- Use `@external_resource` when the compile-time input lives in a file.

## Recursive data (rule 12)

- Recursion is native and needs no boxing. Define the shape as a recursive `@type`
  (`@type tree :: {:leaf, term} | {:node, tree, tree}`) and write one clause per
  constructor.
- Express traversals as `Enum.reduce`/`List.foldl`, or as one recursive fold that
  takes the per-constructor functions. Tail recursion is optimized.

## Tooling

- Run Dialyzer through `dialyxir` in CI and treat contract and opacity warnings as
  errors.
- Elixir 1.17 and later add a gradual, set-theoretic type checker that warns on
  some impossible patterns and type mismatches at compile time. Its coverage grows
  with each release, so check what your version actually reports. Do not count on
  it for exhaustiveness.
- Compile with `--warnings-as-errors`, and use StreamData property tests to cover
  the invariants the types cannot prove.
