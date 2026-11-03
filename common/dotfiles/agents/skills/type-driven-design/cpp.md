# Type-Driven Design in C++

C++ has two languages that share one syntax. The **type language** (templates,
concepts, `constexpr`/`consteval`, NTTPs) runs at compile time. The **value language**
runs on the CPU. Put as much reasoning as possible into the type language. Phantom
tags, strong types, and typestate transitions are erased by `-O2` and compile to the
same instructions as the unchecked code; check this with `sizeof` asserts or a look
at the disassembly.

C++ is unsound. `reinterpret_cast`, dangling references, UB, and use-after-move can
all invalidate what the type checker proved. Keep those escape hatches narrow,
explicit, and at the edges of the system.

Rule numbers below refer to SKILL.md.

## Contents

- Sums, products, and elimination (rules 1, 2, 5)
- Failure as a value (rule 4)
- Parse, don't validate (rule 3)
- Strong types and phantom tags (rule 6)
- Typestate (rule 7)
- Resources (rule 8)
- Concepts as propositions (rule 9)
- Parametricity (rule 10)
- Compile-time staging (rule 11)
- Recursive data (rule 12)
- Toolchain

## Sums, products, and elimination (rules 1, 2, 5)

```cpp
template<class... Ts> struct overloaded : Ts... { using Ts::operator()...; };
// C++20: aggregate CTAD; no deduction guide needed.

struct Circle { double r; };
struct Rect   { double w, h; };
using Shape = std::variant<Circle, Rect>;

auto area(const Shape& s) -> double {
    return std::visit(overloaded{
        [](const Circle& c) { return std::numbers::pi * c.r * c.r; },
        [](const Rect& r)   { return r.w * r.h; },
    }, s);
}
```

- `std::visit` is exhaustive because the visitor must be callable for every
  alternative. Never add a generic `[](auto&&)` arm over a variant you own. It is the
  wildcard, and it silently absorbs new alternatives.
- Give every alternative a named struct, even one holding a single field.
  `variant<int, int>` is ambiguous to construct and meaningless to read.
- `std::monostate` is the unit type. Use `void` only as a return type.
- `std::get_if` is for testing one case when a sound fallback exists. A chain of
  `get_if`/`holds_alternative` that does full case analysis is a `visit` without the
  exhaustiveness check.
- In an `if constexpr` chain over types, end with
  `else static_assert(always_false<T>)`. In C++23 a plain `static_assert(false)` in a
  discarded branch is allowed. Without it, an unmatched type compiles to nothing.
- `enum class` + `switch`: leave out `default:`, build with `-Werror=switch`, and
  after the switch put `std::unreachable()` (C++23) or an abort, because any integer
  can be cast into the enum. Prefer a `variant` once any case carries data.
- Use structured bindings (`auto [a, b] = p;`) to take a product apart.

## Failure as a value (rule 4)

- C++23 has `std::expected<T, E>` with `and_then`/`transform`/`or_else`. Before
  C++23, use `std::variant<T, E>` with named alternatives, or `tl::expected`.
- Mark every function returning a result `[[nodiscard]]`.
- Replace `bool parse(std::string_view, Out& out)`, `-1` sentinels, and throws for
  expected failures with an `expected` or `variant` return.

## Parse, don't validate (rule 3)

```cpp
class Email {
    std::string value_;
    explicit Email(std::string s) : value_(std::move(s)) {}
public:
    [[nodiscard]] static auto parse(std::string_view raw)
        -> std::expected<Email, EmailError>;
    auto get() const -> const std::string& { return value_; }
};
```

- Keep the constructor private, with exactly one public parser. Do not give the
  class public fields, since aggregate initialization bypasses the parser. Do not
  give it a default constructor that produces an invalid value.
- Copy and move are fine because they preserve the invariant. Mutators must preserve
  it too or not exist.

## Strong types and phantom tags (rule 6)

```cpp
template<class Tag, class T>
class Strong {
    T value_;
public:
    explicit Strong(T v) : value_(std::move(v)) {}
    auto get() const -> const T& { return value_; }
    auto operator<=>(const Strong&) const = default;
    auto operator+(const Strong& o) const -> Strong
        requires requires(T a, T b) { a + b; }   // add only when it is meaningful
    { return Strong{value_ + o.value_}; }
};
using PassengerId = Strong<struct PassengerIdTag, std::uint64_t>;
using FlightId    = Strong<struct FlightIdTag,    std::uint64_t>;
static_assert(sizeof(PassengerId) == sizeof(std::uint64_t));
```

- The tag can be declared inline as an incomplete type (`struct XTag`) and never
  needs a body.
- Opt in to each operation. IDs get no arithmetic; quantities get same-unit
  arithmetic and explicit conversion functions.
- Specialize `std::hash` once for the template.
- To block an implicit conversion at a call site, delete the overload:
  `void f(double) = delete;`.
- Never specialize or `if constexpr` on the tag in generic code. That turns the proof
  into a convention (rule 10).

## Typestate (rule 7)

```cpp
struct Unbound{}; struct Bound{}; struct Listening{};

template<class S> class Socket;
template<> class Socket<Unbound> {
    Fd fd_;
public:
    [[nodiscard]] auto bind(int port) && -> std::expected<Socket<Bound>, Errno>;
};
template<> class Socket<Bound> {
    Fd fd_;
public:
    [[nodiscard]] auto listen() && -> Socket<Listening>;
};
class Server { public: explicit Server(Socket<Listening>); };

auto s = Server{make_socket().bind(8080).value().listen()};
```

- An `&&` qualifier makes a transition callable only on an rvalue, so the source
  must be a temporary or explicitly `std::move`d. In C++23 you can instead take the
  explicit object parameter by value: `auto bind(this Socket self, int) -> ...`.
- Templated state with gated members:
  `auto build() && -> Request requires std::same_as<S, Ready>;`. The constraint
  *is* the transition rule.
- A step with several outcomes returns `std::variant<Authenticated, AuthFailed>`.
- To track independent prerequisites, use one phantom axis per prerequisite
  (`Headers<HasHost, HasContentType>`), not a bitset of `bool`s. The irreversible
  step takes the fully proven type.
- **Limit.** A moved-from object is still nameable, and using it is a runtime bug,
  not a type error. Chain transitions in a single expression where possible, and run
  clang-tidy `bugprone-use-after-move`.
- **Cost.** One type per state, with fields duplicated across specializations, and
  generic code over states needs templates or a `variant`.

## Resources (rule 8)

```cpp
class Fd {
    int fd_ = -1;
public:
    explicit Fd(int fd) : fd_(fd) {}
    Fd(const Fd&) = delete;
    auto operator=(const Fd&) -> Fd& = delete;
    Fd(Fd&& o) noexcept : fd_(std::exchange(o.fd_, -1)) {}
    auto operator=(Fd&& o) noexcept -> Fd& {
        if (this != &o) { reset(); fd_ = std::exchange(o.fd_, -1); }
        return *this;
    }
    ~Fd() { reset(); }
    [[nodiscard]] auto release() && -> int { return std::exchange(fd_, -1); }
private:
    void reset() noexcept { if (fd_ >= 0) ::close(fd_); fd_ = -1; }
};
```

- Deleting copy forbids duplication (contraction). The destructor makes discarding
  safe (weakening with cleanup). Move is the linear implication `A ⊸ A` and must
  leave the sentinel behind.
- C++ is affine at best. Nothing makes the caller use a value, and `[[nodiscard]]`
  only warns. Use it on factories and on `release()`.
- Prefer `std::unique_ptr` with a custom deleter when it fits, so you follow the rule
  of zero instead of hand-writing the rule of five.
- `shared_ptr<T>` is `!T`, freely copied and discarded. Use it only where ownership is
  genuinely shared.
- Store mutually exclusive phases as one variant (`variant<ReadPhase, WritePhase>`)
  and overwrite it on each transition.

## Concepts as propositions (rule 9)

```cpp
template<class T>
concept ContentSource = requires(T s) {
    { s.all_posts() } -> std::same_as<std::vector<Post>>;
};
template<class T>
concept Reloadable = requires(T s) { s.reload(); };

template<class S> requires ContentSource<S> && Reloadable<S>
class HotReloader { /* ... */ };
```

- Build refinements by conjoining named concepts:
  `concept Strong = Weak<T> && Extra<T>;`. Subsumption then picks the most
  constrained overload. Subsumption compares atomic constraints by identity, so
  writing the same boolean expression in two concepts does not make one subsume the
  other. Factor it into a named concept and reuse that.
- Use compound requirements (`{ e } -> Concept`) instead of bare `{ e };`.
- Do not build logic on `!C<T>`, because negation does not take part in subsumption.
- Replace `enable_if`/SFINAE with named concepts and `requires`. The error message
  then names the proposition that failed.
- When a type almost satisfies a concept, wrap it in an adapter instead of weakening
  the concept.

## Parametricity (rule 10)

- An unconstrained `typename T` that the body never inspects is parametric. For
  example, `AtomicCache<T>` holding `std::atomic<std::shared_ptr<const T>>` and only
  loading and storing it is provably independent of `T`.
- These moves give up the free theorem for that parameter: `if constexpr
  (std::is_*_v<T>)`, explicit or partial specialization of a generic operation,
  `typeid`, `dynamic_cast`, `reinterpret_cast`. If behavior has to vary by type, make
  it a policy or customization-point parameter so the algorithm body stays uniform.
- Reason one parameter at a time. A class can be parametric in `Cache` and ad hoc in
  `Source`.

## Compile-time staging (rule 11)

```cpp
template<std::size_t N> struct Lit {
    char buf[N]{};
    constexpr Lit(const char (&s)[N]) { std::copy_n(s, N, buf); }
    constexpr auto sv() const { return std::string_view{buf, N - 1}; }
};
template<Lit Path> struct Route { static constexpr auto info = parse_route(Path.sv()); };

consteval auto checked_port(int p) -> std::uint16_t {
    if (p <= 0 || p > 65535) throw "port out of range";   // compile error
    return static_cast<std::uint16_t>(p);
}
```

- NTTPs must be structural: literal type, all public members, no `std::string`.
- Make config a type parameter (`template<ServerConfig C> class Server`) and select
  strategies with `if constexpr (C.tls)`. The unused branch is never instantiated.
- Encode sizes in types: `Vec<T, N>`, `head() requires (N > 0)`,
  `concat -> Vec<T, N + M>`.
- To dispatch over a compile-time route table, fold over a `std::tuple` with
  `std::apply` and a fold expression. This needs no hash map, heap, or vtable.
- **Limit.** NTTPs must be `constexpr`, so there are no types that depend on runtime
  values; use `std::vector` for those. Each distinct value is a separate
  instantiation, which costs compile time and binary size.

## Recursive data (rule 12)

- A variant alternative must be a complete type, so recursion needs indirection.
  Forward-declare the node, alias the variant with `std::unique_ptr<Node>` or
  `std::vector<Node>`, then define the node. Use `vector` when the fan-out is natural
  (one allocation per level, not one per node).
- A fold is `std::visit` that recurses into the child alternatives. For lists use
  `std::accumulate` or C++23 `std::ranges::fold_left`. Pass the algebra as template
  lambdas, not `std::function`, which blocks inlining.
- C++ has no guaranteed tail-call optimization, so recursion depth is stack depth.

## Toolchain

- `-Wall -Wextra -Werror=switch`. Treat `[[nodiscard]]` warnings as errors.
- clang-tidy: `bugprone-use-after-move`, `cppcoreguidelines-pro-type-reinterpret-cast`.
- Template and concept errors are long. Name your concepts so the first line of the
  error states the failed proposition.
