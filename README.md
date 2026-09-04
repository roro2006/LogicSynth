# LogicSynth

## A transparent, formally guarded optimization pass for Yosys

Logic optimization is often described as if it were a single number: make the
netlist smaller, make it faster, or make it use less power. Real designs are
less cooperative. A rewrite that removes a gate can increase fanout. A timing
improvement can spend area. A transformation that looks harmless at the RTL
level can become a functional bug once signals are widened, constants are
propagated, or sequential logic is involved.

LogicSynth started from that practical tension. The goal is not to replace
Yosys or ABC with another opaque optimizer. The goal is to build a small,
inspectable C++ pass that can be inserted into an ordinary Yosys flow, explain
why it changed a netlist, and refuse a change when the selected objective says
the change is not worthwhile.

The result is a native Yosys RTLIL pass with deterministic heuristics,
profile-driven scoring, graph-based structural metrics, and a formal
equivalence gate. It is deliberately conservative: the current implementation
focuses on safe combinational rewrites while preserving sequential and unknown
logic. That makes it useful as both an optimization experiment and a credible
starting point for downstream EDA work.

## What was built

The production integration is C++17 from end to end. There is no Python runtime
or adapter in the flow.

At the center is `passes/logicsynth.cc`, a native Yosys plugin that operates
directly on RTLIL. The repository also contains a reusable C++ core under
`include/` and `src/cpp/`, CMake/CTest regression coverage, shell-based Yosys
integration, and a benchmark harness that emits machine-readable results.

The pass currently understands the common combinational forms needed for its
rewrites:

- `$and`, `$or`, `$xor`, `$xnor`, `$not`, and `$mux`;
- Yosys internal `$_AND_` and `$_OR_` cells;
- multi-bit signal connectivity and bus-shaped cones;
- combinational duplicate cones and commutative operand order;
- sequential cells and unknown/blackbox cells as protected boundaries.

The implementation is intentionally not a general-purpose technology mapper.
Technology mapping, library area, static timing analysis, and switching
simulation remain the responsibility of the surrounding flow.

## The design problem

The first prototype was useful for exploring the shape of the idea, but it
also made the boundary of a production-quality pass clear. A JSON round trip
would make the optimizer easier to prototype, yet it would add another
representation boundary to a Yosys flow. Python would make experimentation
quick, but it would complicate installation and weaken the “drop this into a
native EDA build” story.

The project therefore moved to a native pass. The optimizer receives the
RTLIL module that Yosys is already holding, identifies safe candidate rewrites,
scores those candidates, and mutates the module only after the candidate passes
the objective gate. This keeps the integration small and makes the behavior
visible in normal Yosys logs.

That decision also shaped the safety model. LogicSynth does not rewrite every
cell it can parse. It rewrites only known combinational structures, leaves
state-holding logic alone, and relies on formal equivalence as the final
acceptance criterion.

## How the optimization works

### Duplicate-cone sharing

When two supported combinational cells describe the same operation over the
same signals, LogicSynth can redirect one cone's users to the other and remove
the duplicate cell. Commutative operations are canonicalized, so `a & b` and
`b & a` are recognized as the same structural expression.

This is a small transformation, but it is a useful foundation: it reduces
redundant logic without introducing technology-specific assumptions and makes
the resulting QoR impact easy to measure.

### Boolean identity rewrites

The pass handles selected constant identities for one-bit signals:

```text
x & 1     = x
x | 0     = x
x ^ 0     = x
x XNOR 1  = x
x XNOR 0  = NOT x
```

The last rule is worth calling out. An earlier implementation treated `x XNOR
0` as `x`, which is incorrect. The fixture suite caught that mistake, and the
rule was corrected to produce an inverted signal. This is exactly the sort of
edge case that makes formal checking essential: an optimization can look
structurally plausible while being logically wrong.

Identity rewrites are evaluated through the same objective gate as
duplicate-cone sharing. They are not automatically accepted merely because
they reduce a local cell count.

### Objective-aware decisions

Every profile produces a weighted structural objective from three components:

- an area proxy based on logic-cell count;
- a graph-derived depth proxy for critical-path structure;
- a fanout-pressure proxy used as a power-oriented activity indicator.

The default profile is `balanced`. The repository also provides `area`,
`timing`, and `power` profiles, along with explicit
`area_weight`, `delay_weight`, `power_weight`, `effort`, and `max_rewrites`
controls.

A candidate is committed only when its weighted objective is acceptable for the
selected profile. This does not claim to predict signoff power or timing. It
does provide a deterministic way to express a tradeoff and to compare
experiments under the same assumptions.

### Graph-based structural analysis

The pass constructs a directed driver-to-consumer graph from RTLIL signal
connections. It uses that graph to estimate topological logic depth and
fanout pressure rather than relying only on a raw count of cells or wires.
Fanout pressure grows with the squared fanout of drivers, making heavily shared
signals visible to the power proxy.

These metrics are deliberately labeled proxies. They are useful for ranking
candidate rewrites before technology mapping, but they are not a substitute for
library characterization, STA, clock-aware analysis, or activity simulation.

## Correctness is part of the optimization loop

The pass is designed around a simple rule: a smaller netlist is not an
improvement if it changes the circuit.

The repository includes formal-equivalence flows using Yosys and fixtures for:

- AND, OR, XOR, and XNOR constant identities;
- commutative cones;
- buses and multi-bit signals;
- muxes;
- sequential logic;
- unknown cells and blackbox boundaries;
- duplicate cones and corner-case signal forms.

The optimized design is loaded as a separate library module, compared against
the original with `equiv_make`, and checked with `equiv_simple` and
`equiv_status -assert`. Unsupported cells remain untouched, and the native
smoke suite exercises the plugin before any benchmark result is treated as
evidence.

Run the core and Yosys-backed checks with:

```bash
make test
make yosys-test
make yosys-plugin-test
```

## Benchmarking the claim

The benchmark harness was built to make results reproducible rather than
impressive-looking. Each run records the design, profile, Yosys version,
baseline/ABC/LogicSynth statistics, runtime, and equivalence status. Raw
statistics are emitted as JSON, and public inputs are pinned to an immutable
revision in `benchmarks/manifest.tsv`.

The checked-in public benchmark comes from the LSILS benchmark repository:

```bash
make fetch-benchmarks
scripts/benchmark_native.sh \
  build/public-benchmarks/random_control/arbiter.v \
  build/public-arbiter
```

One completed run on the pinned `random_control/arbiter.v` design produced:

| Flow | Cells | Runtime |
| --- | ---: | ---: |
| Baseline Yosys | 23,873 | 1.6 s |
| Yosys + ABC | 23,233 | 6.2 s |
| LogicSynth | 22,873 | 550.9 s |

LogicSynth reduced the cell count by 1,000 cells, or 4.19%, relative to the
baseline, and by 360 cells, or 1.55%, relative to ABC. Formal equivalence
passed. The result is meaningful precisely because the runtime cost is shown
alongside the QoR result: this version demonstrates a measurable structural
benefit, but it is not yet competitive with ABC on runtime.

A smaller checked-in smoke result on the commutative-cone fixture shows the
same pattern in a compact form: two baseline cells become one LogicSynth cell,
with equivalence passing. These examples are evidence of the current heuristic
behavior, not a claim that LogicSynth wins on every design or every objective.

The public result is stored in
[`results/arbiter.summary.json`](results/arbiter.summary.json), while the
benchmark methodology is described in
[`docs/benchmarking.md`](docs/benchmarking.md).

## Quickstart

Build the C++ library and run its regression test:

```bash
make test
```

With Yosys and its development headers installed, build the native plugin:

```bash
make yosys-plugin
```

Then run it in a normal flow:

```bash
yosys -m ./build/logicsynth.so \
  -p 'read_verilog design.v; prep -top top; logicsynth -profile balanced; write_verilog optimized.v'
```

For a timing-oriented experiment, for example:

```bash
yosys -m ./build/logicsynth.so \
  -p 'read_verilog design.v; prep -top top; logicsynth -profile timing -max_rewrites 1000; write_verilog optimized.v'
```

Use `scripts/equivalence.sh original.v optimized.v top` to run the formal
comparison directly.

## Project structure

```text
include/                 Reusable C++ netlist and metric types
src/cpp/                 C++ optimizer core and demo
passes/logicsynth.cc     Native Yosys RTLIL pass
tests/                   C++ and Yosys integration tests
tests/data/              Correctness and edge-case fixtures
benchmarks/              Pinned public benchmark manifest
scripts/                 Yosys, equivalence, and benchmark workflows
docs/                    Architecture and methodology notes
results/                 Reproducible machine-readable benchmark summaries
.github/workflows/       Build, integration, and benchmark CI
```

## Where this project is going

LogicSynth is now a credible research and engineering baseline, not a claim of
finished industrial synthesis. The next improvements should focus on exact
hypothetical graph updates during candidate scoring, faster cone analysis,
broader benchmark coverage, richer timing/power models, and more rewrite
families with fixture-backed formal proofs.

That scope is intentional. A useful EDA tool needs more than an optimization
idea: it needs a stable integration boundary, deterministic behavior,
reproducible measurements, and a clear statement of where its estimates stop.
LogicSynth is built around those constraints so that future improvements can be
measured against a trustworthy baseline.

## License

Apache-2.0. See [LICENSE](LICENSE).
