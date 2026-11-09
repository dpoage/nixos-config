# bofors 10-minute all-core load test, 2026-11-09

bofors (Ryzen 9 8945HX, 16c/32t, kernel 6.18.60) held an all-core load for 10 minutes
without thermal throttling. The package hit its ~86 W power limit about 10 s into the
load. All-core clock settled at about 4.3 GHz. Tctl peaked at 93.4 °C, below the
8945HX's 100 °C Tjmax.

## Setup

- `amd-pstate-epp` in active mode. Governor `performance` on all 32 CPUs, EPP
  `performance`, boost on. `bofors/gate-host.nix` sets the governor. The installer
  generation defaulted to `powersave`.
- Load: `stress-ng --cpu 32 --cpu-method matrixprod --timeout 600`. The run passed with
  13,388,127 bogo ops, or 22,314 per second.
- Phases: 60 s idle, 600 s load, 120 s cooldown. The script sampled every 2 s:
  - k10temp Tctl, Tccd1 and Tccd2
  - RAPL package and core power
  - `scaling_cur_freq` on every CPU
- Raw samples: [`bofors-loadtest-2026-11-09.csv`](bofors-loadtest-2026-11-09.csv).
  One load sample has a large negative `pkg_w` because the RAPL counter wrapped.
  Ignore it.

## Results

| Phase | Tctl avg / max (°C) | Package W | All-core MHz avg |
|---|---|---|---|
| Idle | 48.3 / 52.8 | 9.3 | 2483 |
| Load, first 10 s | 73.5 | 111.5 | 4708 |
| Load, steady (t > 200 s) | ~92 / 93.4 | 85.6 | ~4290 |
| Cooldown, 2 min later | 54.4 | 10.4 | 2903 |

Tccd2 ran about 4 °C cooler than Tccd1 throughout: 88.8 °C max against 93.5 °C.

## Why this is a power limit

Package power stayed flat at 85.7–86.1 W from t≈73 s to the end. Tctl was still
climbing from 76 °C to 92 °C during that time. A thermal limit would let power fall as
the die neared Tjmax. Here power stayed fixed while temperature kept rising.

The clock slipped from 4.44 GHz to 4.29 GHz as the die heated. At a fixed power cap,
leakage rises with temperature, so the cores get less power for switching. This is the
expected result of a power limit.

This conclusion is inferred. The firmware's limiter status, i.e. whether PPT or HTC
was active, was not read. RAPL power and k10temp readings are the only evidence.

Gate implication: sustained all-core work runs at about 4.3 GHz and about 92 °C.
Timings from the first ~60 s of a cold start run faster, at about 4.4–4.7 GHz.
Benchmarks should warm up first or compare only like-for-like starts.
