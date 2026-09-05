# Building LogicSynth

Logic synthesis has a deceptively simple sales pitch: start with a description of a digital circuit and produce a better one.

The uncomfortable word in that sentence is *better*. Fewer cells is usually good, until the rewrite lengthens a critical path. Sharing logic can reduce area, until the shared signal creates enough fanout to be a liability. A Boolean identity can be true on paper and still be wrong to apply to a bus, a sequential element, or a signal form the pass did not account for. And after a transformation seems reasonable, there is still the basic question: does the new netlist compute the same design?

I built LogicSynth to make that whole loop visible. It is a small native C++ optimization pass for Yosys that applies a deliberately limited set of structural rewrites, scores them using an explicit objective, and checks the result with formal equivalence.

This is not an attempt to replace ABC with a few hundred lines of heuristics. The useful part of the project is that the experiment is inspectable: the candidate rewrites are small, the cost model is stated, the boundary conditions are explicit, and the result is checked rather than assumed.

## Starting with the wrong boundary

The first version worked on Yosys JSON netlists. That was a reasonable way to test the basic idea. It was also a good way to discover what I did not want the final project to be.

A program that reads a serialized netlist, changes it, and writes it back has a second representation boundary and a second set of assumptions about signals and cells. It is easy to make a prototype look convincing there, because the awkward parts have been pushed outside the program.

I eventually moved the optimization path into C++ and made RTLIL the boundary instead. The pass is built as a native Yosys plugin:

```bash
make yosys-plugin
yosys -m ./build/logicsynth.so \
  -p 'read_verilog design.v; prep -top top; logicsynth -profile balanced; write_verilog optimized.v'
```

That change made the project less convenient in the short term. It also meant the optimizer had to deal with the objects that occur in an actual Yosys flow: widths, constants, buses, sequential cells, blackboxes, and RTLIL's representation of connections.

The reusable C++ core lives in `include/` and `src/cpp/`. The production Yosys entry point is `passes/logicsynth.cc`.

## The first useful rewrites

The first rewrite LogicSynth learned was duplicate-cone sharing. If two cells compute the same operation on the same inputs, the pass can keep one and redirect users of the other. This is small, deterministic, and easy to test.

It is also a little less trivial than it first appears. Consider:

```text
a & b
b & a
```

Those cones should match, even though their operands arrive in a different order. LogicSynth canonicalizes operands of commutative operations before comparing cones. Without that step, the pass only recognizes sharing when the source happens to use the same ordering.

The next set of rewrites came from basic Boolean identities:

```text
x & 1     = x
x | 0     = x
x ^ 0     = x
x XNOR 1  = x
x XNOR 0  = NOT x
```

The last one was more useful as a debugging lesson than as an optimization. An earlier version handled `x XNOR 0` as `x`. It should have produced the inverse of `x`. Cell counts did not reveal that mistake; formal equivalence did.

That changed how I approached the rest of the pass. Equivalence checking was not a final checkbox after the optimization work. It had to be part of how the rewrites were designed and tested.

## Deciding what “better” means

Removing a cell is not automatically an improvement. LogicSynth ranks candidates with a weighted structural objective that combines:

- **Area:** logic-cell count
- **Delay proxy:** directed depth through combinational logic
- **Power proxy:** fanout pressure, with higher fanout receiving a larger penalty

The pass has four built-in profiles: `balanced`, `area`, `timing`, and `power`. The weights can also be supplied explicitly with options such as `area_weight`, `delay_weight`, `power_weight`, and `max_rewrites`.

The graph analysis builds driver-to-consumer edges from RTLIL connections, computes combinational depth, and accumulates fanout pressure. It is intentionally a rough structural model. It is not static timing analysis, library mapping, switching simulation, or signoff power analysis.

That distinction is important enough to say plainly: these metrics are ranking signals for early decisions. They are not timing or power numbers.

## Being conservative on purpose

The pass does not rewrite every cell that looks vaguely Boolean. It recognizes a narrow set of combinational cells and treats sequential, unknown, and blackbox cells as boundaries.

The fixture set covers:

- AND, OR, XOR, and XNOR constant identities
- Duplicate cones with commuted operands
- Buses and multi-bit signals
- Muxes
- Sequential logic
- Unknown and blackbox cells
- Corner cases in RTLIL signal forms

For the integration flow, Yosys keeps the original design as a gold module, loads the optimized design separately, constructs an equivalence module, and runs:

```text
equiv_make
equiv_simple
equiv_status -assert
```

This is how the XNOR bug was caught. It is also a more meaningful claim of safety than saying that the emitted Verilog compiled.

The local checks are deliberately uncomplicated:

```bash
make test
make yosys-test
make yosys-plugin-test
```

The C++ tests cover the reusable optimization core. The Yosys fixtures exercise the plugin boundary. The equivalence flow checks whether the transformed design still behaves like the original.

## The benchmark that made the tradeoff obvious

At some point, a synthesis project needs a result that is less tidy than a hand-built test case. I wanted the benchmark harness to make it hard to keep only the flattering part of a run.

For a given input, it runs three flows:

- Baseline Yosys
- Yosys with ABC
- Native LogicSynth

It records Yosys JSON statistics, runtime, tool version, selected profile, and equivalence status. Public inputs are pinned to an immutable revision in `benchmarks/manifest.tsv`.

The first public design I ran was `random_control/arbiter.v` from the LSILS benchmark repository. With Yosys 0.33, the run produced:

| Flow | Cells | Runtime |
|---|---:|---:|
| Baseline Yosys | 23,873 | 1.6 s |
| Yosys + ABC | 23,233 | 6.2 s |
| LogicSynth | 22,873 | 550.9 s |

LogicSynth removed 1,000 cells relative to baseline, a 4.19% reduction, and 360 relative to the ABC flow, a 1.55% reduction. The equivalence check passed.

The runtime belongs next to those numbers. The current LogicSynth run takes roughly nine minutes while the established flows take seconds. This is a QoR observation, not evidence that the pass is ready to replace a production optimizer. The pass found a measurable structural reduction, but its candidate analysis is still too expensive for that claim.

The checked-in summary is [`results/arbiter.summary.json`](results/arbiter.summary.json). To reproduce the public checkout and run:

```bash
make fetch-benchmarks
scripts/benchmark_native.sh \
  build/public-benchmarks/random_control/arbiter.v \
  build/public-arbiter
```

There is also a commutative-cone smoke result. It reduces a two-cell baseline to one cell and passes equivalence. That example is useful because it is easy to inspect; the arbiter run is useful because it is a public design with a less toy-like cone structure.

## What the implementation taught me

The rewrite rules are usually not the hard part. The surrounding questions are.

- What, precisely, counts as a supported cell?
- What happens when a signal is wider than one bit?
- How should commutativity affect structural comparison?
- What is the safe behavior around sequential and unknown logic?
- Does sharing reduce one cost while creating another?
- Can someone else reproduce both the result and the equivalence check?

Those questions shaped the repository:

```text
include/                 C++ netlist and metric types
src/cpp/                 Reusable optimizer core
passes/logicsynth.cc     Native Yosys RTLIL pass
tests/data/              Formal-equivalence fixtures
scripts/                 Yosys, equivalence, and benchmark workflows
benchmarks/              Pinned public benchmark manifest
results/                 Machine-readable benchmark summaries
docs/                    Architecture and methodology
.github/workflows/       Build and integration CI
```

That is also why the pass is conservative. A smaller collection of transformations that can be explained, tested, and proven is a better starting point than a larger collection of opaque rewrites.

## Scope and next steps

LogicSynth is a deterministic native Yosys optimization pass and a reproducible experiment around it. It is useful for exploring structural rewrites, objective tradeoffs, and equivalence-checked netlist changes.

It is not a replacement for ABC, a technology mapper, a signoff timing tool, or an activity-based power flow. The public benchmark is encouraging on cell count and unacceptable on runtime for many production uses. Both are part of the result.

The next work is fairly concrete:

- Make candidate graph updates exact rather than approximate
- Reduce the cost of cone analysis
- Expand the public benchmark set
- Add rewrite families only when they come with fixture-backed equivalence evidence

The point of keeping the project small is that the full path—from an identity, to an RTLIL mutation, to a formal proof, to a recorded benchmark—is short enough to inspect and improve.

## Quickstart

Build the C++ core and run its regression tests:

```bash
make test
```

Build the native plugin with Yosys development headers installed:

```bash
make yosys-plugin
```

Run the plugin in a normal Yosys flow:

```bash
yosys -m ./build/logicsynth.so \
  -p 'read_verilog design.v; prep -top top; logicsynth -profile balanced; write_verilog optimized.v'
```

Run a direct equivalence comparison:

```bash
scripts/equivalence.sh original.v optimized.v top
```

## License

Apache-2.0. See [LICENSE](LICENSE).
