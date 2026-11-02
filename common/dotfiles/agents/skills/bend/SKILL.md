---
name: bend
description: Use when writing, checking or proving Bend 2 code (bend-lang, `.bend` files, LAWS.bend / PROOF.bend), or when porting a TLA+ spec to Bend. Covers the checker's traps, proof patterns that work, and how to shape a model so its laws are cheap to prove. Not for Bend 1 (HigherOrderCO/Bend, the HVM2 language).
---

# Bend 2

Bend 2 is a dependently typed, affine language whose checker proves laws.
`LAWS.bend` states claims; `PROOF.bend` proves each one with a def of the
same name; `bend PROOF.bend` prints `ALL PROOFS CHECK` or `SOME PROOFS FAIL`.
The facts below come from Bend 2.0.39 (November 2026). Bend changes fast:
confirm a fact against `bend guide` when behavior differs.

## First steps

1. Run `bend guide` and read it. It is the only full reference.
2. Run `bend base <Name>` to read a Base type or def (`bend base Bool`).
3. Check a file with `bend file.bend`. A `main` that returns a value prints it.
4. Use `bend file.bend --check-only` to check without running `main`.

`--verdict` rechecks the proofs with BendTT, a small kernel proven sound in
Lean. If `$BENDTT` names a built kernel binary, bend runs it. Otherwise bend
builds `bendtt.lean` into `~/.bend/bendtt/` with Lean v4.34.0 from elan or
`PATH`, and fails without it. The binary needs no Lean at runtime.

On machines built from nixos-config, the `bend` wrapper sets `BENDTT` to a
kernel that `overlays/bend.nix` builds with Lean 4.34.0, so `--verdict`
works with no setup. The package build fails if bend pins another Lean
version, or if `--verdict` stops accepting a true law or the kernel stops
rejecting a false one. Treat `--verdict` as the gate for proofs you did not
review.

## Language traps

Each trap below produced a checker error in practice.

- **Use is affine.** A variable is used at most once. Write `+x` to reuse it.
  `+x` needs a `Data` type.
- **A pair is not `Data`.** `+c: Bool & Bool` fails with "its type must be
  Data". Define a record: `type C is Data: C{a: Bool, z: Bool}`.
- **A closure is called at most once.** To call a function argument many
  times, make it a template: `def all_bool(~E: @+c:C -> @+v:Bool -> Bool, +c: C)`.
- **A template argument must be closed.** It may name top-level defs only.
  Carry the context in a `Data` record argument, not in a captured local.
- **A template's type repeats the quantities.** Passing `def leaf(+c: C, +b: Bool)`
  for `~E: C -> Bool -> Bool` fails. Write `@+c:C -> @+v:Bool -> Bool`.
- **`match` takes a parameter or a pattern variable, never a computed value.**
  Pass a computed value to a helper that matches its parameter.
- **Match order follows binder order.** `Per{a, b} = m` then `match g:` fails
  with "can't be matched in this position". Match `g` first, destructure in
  each branch.
- **An erased (`-x`) value cannot be matched.** The error is "a live
  scrutinee". A def that returns an equation is live too.
- **A literal constructor in a `let` needs an annotation.** Write
  `+k = {Ctx{q, cfg, a} : Ctx}`; a bare `Ctx{...}` gives "cannot infer".
- **A law-filling def has no parameter quantities.** `def Laws.x(cfg, a, s):`
  cannot mark `+s`. Call a typed helper: `Laws.x(cfg, a, s): helper(cfg, a, s)`.
- **An affine list cannot be reused.** A `List<A>` argument used twice fails.
  Restructure so the list reaches one consumer, for example an induction
  that returns the equation directly.

## Proof patterns

- **Mirror the function's match tree.** Match the same values in the same
  order as the def under proof. At each leaf the claim computes; prove it
  with `{==}`. A field the law fixes to a constructor needs no split.
- **Rewrite direction.** `%e : P` with `e : {a == b : T}` needs the goal to
  be `P` with `b` at `_`. The goal becomes `P` with `a` at `_`.
- **Refute `{True == False}`.** Rewrite into `T(_)`, where `T` maps True to
  `Unit` and False to `Empty`:

  ```python
  def clash(e: {True{} == False{} : Bool}) -> Empty:
    %e : T(_)
    Unit{}
  ```

- **Absorb a disjunct with an erased argument.** A lemma generic in an
  erased `-x` matches any second disjunct:

  ```python
  def unchanged(r: Bool, -x: Bool)
    -> {(Bool.not(r && Bool.not(r)) || x) == True{} : Bool}:
    match r:
      case True{}:
        {==}
      case False{}:
        {==}
  ```

- **Pass a fact as a function.** A hypothesis `ok: {is_commit(d) == True{} : Bool}
  -> {healthy == True{} : Bool}` stays valid while `d` is open. After `match d`
  refines `d` to `Commit`, call `ok({==})`.
- **Make illegal outputs unrepresentable.** If the fixed code returns a type
  with no `Skip` constructor, "never skips" holds by `{==}`.
- **Use `Equal.sym` and `Equal.trans` from Base** to chain equations.

## Checker performance

The checker normalizes types fully. A lemma whose type mentions a large
computed term expands the whole term, and the cost doubles with each level of
nesting. A def whose first `match` is stuck on a variable stays folded.

- If a type must mention a large enumeration, guard each level with a
  `match` on a `Unit` token parameter. Pass a variable token in lemmas and
  `Unit{}` only where the enumeration must compute.
- Avoid proofs by full state enumeration. In practice 165,888 states × 9
  actions took about 25 s per certificate. Structural proofs of the same
  properties check in under 1 s.

## Model for cheap proofs

The shape of the model decides the cost of the proof more than the language.

1. Split the logic into a pure decision kernel and its environment:
   `observe(state) -> Obs`, `decide(config, obs) -> Decision`,
   `apply(decision, state)`. The kernel is code that can ship.
2. State most laws as one-step properties of `decide` over every
   observation, reachable or not. A one-step law needs a short case split,
   not an induction.
3. Drop ghost variables. TLA+ records history so that TLC can check a step
   as a state property; a Bend law states the step directly.
4. Build each transition's result field by field. A field an action leaves
   alone is then the same variable afterwards, and proofs about it need no
   split. A whole-state `Bool.pick(State, guard, x, y)` blocks this.
5. Keep induction for the few genuine run invariants. Induct on the action
   list with the list as the first parameter.

## Port a TLA+ spec

1. Port `Next` as an `Action` type and a `step` function. A disabled action
   returns the state unchanged; that is TLA+ stuttering.
2. Compile the model to JavaScript: `bend model.bend -o model.mjs`. The
   module's default export holds every non-IO def. A `Bool` is a JS boolean;
   a constructor is `{$: "Name", field: value}`.
3. Dump TLC's state graph with the invariants removed from the config:
   `tlc -workers 1 -dump dot,actionlabels out.dot -config Spec_noinv.cfg Spec.tla`.
4. Compare the graphs: BFS the Bend model in JS, project both sides onto the
   non-ghost variables, and compare edges keyed by source, action label and
   target. Drop self-loops on both sides.
5. Write each TLA+ invariant's derivation from the Bend laws in LAWS.bend.
6. Mutate the model once per law and confirm that law's proof fails.

Key edges by action label. Without labels, a mutant whose tick committed a
held trial produced the same unlabeled edges as the explicit commit action,
and the comparison passed.

## Limits

- A failed proof prints expected and observed terms, not a counterexample
  trace. Use TLC to search for counterexamples; keep known
  counterexamples as `{==}` trace laws.
- Bend has no temporal logic. Liveness and fairness properties stay in TLA+.
