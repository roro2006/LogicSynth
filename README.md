# Building LogicSynth: A Small Optimization Pass That Has to Earn Trust

*September 2026*

Logic synthesis has a deceptively simple sales pitch: take a description of a
digital circuit and produce a better one.

“Better” is where the trouble starts.

Fewer gates is usually good, until the rewrite creates a long critical path.
Sharing logic can reduce area, until the shared signal acquires a fanout that
hurts power. A Boolean identity can be true on paper, yet still be applied to
the wrong width or the wrong kind of signal. And even when the optimized
netlist looks reasonable, how do we know it still computes the same circuit?

I built LogicSynth to explore that problem in the open: a small, native C++
optimization pass that runs inside Yosys, makes a limited set of explainable
rewrites, scores them against an explicit objective, and submits the result to
formal equivalence checking.

This is not a claim that a few hundred lines of heuristics have replaced ABC.
It is an attempt to make the entire optimization experiment inspectable:
where the pass sits in the flow, what it considers a candidate, why it accepts
or rejects a rewrite, and what the measured tradeoff actually was.

## The first decision: build an overarching pass

The first version of the project was a JSON-netlist prototype. That was a good
place to test the basic idea. It was also a useful warning.

A Python program that reads a serialized netlist and writes another one is easy
to demonstrate, but it is not quite the tool I wanted an EDA engineer to
adopt. It introduces a representation boundary, a separate runtime, and a
second set of assumptions about how Yosys signals and cells are represented.

So I moved the production path into C++ and made RTLIL the integration
boundary. The pass is loaded as a native Yosys plugin:

```bash
make yosys-plugin
yosys -m ./build/logicsynth.so \
  -p 'read_verilog design.v; prep -top top; logicsynth -profile balanced; write_verilog optimized.v'
```

That choice had an important consequence. The pass could no longer pretend
that a netlist was just a convenient dictionary of nodes. It had to deal with
real signal widths, constants, buses, sequential cells, blackboxes, and the
details of Yosys's RTLIL data model.

The resulting repository is C++-only in the optimization flow. The reusable
core lives under `include/` and `src/cpp/`; the production Yosys entry point is
`passes/logicsynth.cc`.

## What counts as an improvement?

The obvious first objective is area. If two cells compute the same operation,
keep one and redirect the users of the other. That is the first rewrite
LogicSynth learned: duplicate-cone sharing.

It is small, deterministic, and easy to reason about. It is also more
interesting than it sounds, because commutativity matters. These two cones
should match:

```text
a & b
b & a
```

LogicSynth canonicalizes the operands of commutative operations before
comparing them. Once that was in place, the pass could find sharing that a
literal operand-order comparison would miss.

The next step was a handful of Boolean identities:

```text
x & 1     = x
x | 0     = x
x ^ 0     = x
x XNOR 1  = x
x XNOR 0  = NOT x
```

The last line became an unexpectedly valuable test of the development
process. An earlier implementation treated `x XNOR 0` as `x`. That is wrong:
XNOR with zero is inversion. The mistake was not found by looking at a cell
count. It was found by exercising the fixture through formal equivalence.

That changed how I thought about the pass. Correctness was not something to
check after the “real” work. It had to shape the rewrite design from the
beginning.

## Turning a gate counter into an objective

A rewrite that removes a cell is not automatically a good rewrite. LogicSynth
therefore evaluates candidates against a weighted structural objective:

- **area:** logic-cell count;
- **delay:** directed graph depth through combinational logic;
- **power proxy:** fanout pressure, with high fanout penalized more heavily.

The pass has four named profiles:

```text
balanced
area
timing
power
```

The weights can also be supplied explicitly with options such as
`area_weight`, `delay_weight`, `power_weight`, and `max_rewrites`.

The graph analysis builds driver-to-consumer edges from RTLIL connections,
computes topological depth, and accumulates fanout pressure. This is not
signoff timing or switching simulation. It is an intentionally modest model
for making early structural choices consistently.

That distinction matters. A proxy is useful when it is described honestly. It
becomes misleading when it is presented as a timing report or a power number.
LogicSynth reports these metrics as ranking signals, not as a replacement for
STA, library mapping, or activity-based power analysis.

## The safety boundary is part of the design

The pass does not try to rewrite everything that looks like logic. It
recognizes a deliberately limited set of combinational cells and treats
sequential and unknown cells as boundaries.

The test fixtures cover:

- AND, OR, XOR, and XNOR constant identities;
- commutative duplicate cones;
- buses and multi-bit signals;
- muxes;
- sequential logic;
- unknown and blackbox cells;
- corner-case RTLIL signal forms.

For each flow, Yosys keeps the original design as a gold module, loads the
optimized design separately, constructs an equivalence module, and runs:

```text
equiv_make
equiv_simple
equiv_status -assert
```

This caught the XNOR bug. It also gives the project a much stronger safety
story than “the optimized Verilog compiled.”

The local checks are intentionally straightforward:

```bash
make test
make yosys-test
make yosys-plugin-test
```

The C++ unit tests check the reusable core. The Yosys fixtures check the actual
plugin boundary. Formal equivalence checks whether the transformation
preserved behavior.

## The benchmark question

At some point, a synthesis project has to stop describing potential and show
measurements. I wanted the benchmark harness to make it difficult to cherry
pick a flattering result.

The harness runs three flows on the same input:

1. baseline Yosys;
2. Yosys with ABC;
3. native LogicSynth.

It records raw Yosys JSON statistics, runtime, the tool version, the selected
profile, and equivalence status. Public inputs are pinned to an immutable
revision in `benchmarks/manifest.tsv`.

The first public design I ran was
`random_control/arbiter.v` from the LSILS benchmark repository. The completed
run used Yosys 0.33 and produced this comparison:

| Flow | Cells | Runtime |
| --- | ---: | ---: |
| Baseline Yosys | 23,873 | 1.6 s |
| Yosys + ABC | 23,233 | 6.2 s |
| LogicSynth | 22,873 | 550.9 s |

LogicSynth removed 1,000 cells relative to the baseline, a 4.19% reduction.
It also removed 360 cells relative to ABC, a 1.55% reduction. Formal
equivalence passed.

The runtime is the part that is easiest to hide and most important to show.
The current LogicSynth run took about nine minutes, compared with seconds for
the established flows. The result is therefore a useful QoR data point, not a
victory lap. The implementation found a measurable structural improvement,
but its candidate analysis is not yet fast enough for a fair production
replacement claim.

The result is checked in as
[`results/arbiter.summary.json`](results/arbiter.summary.json). Reproduce the
public checkout and run with:

```bash
make fetch-benchmarks
scripts/benchmark_native.sh \
  build/public-benchmarks/random_control/arbiter.v \
  build/public-arbiter
```

There is also a small commutative-cone smoke result. It reduces a two-cell
baseline to one cell and passes equivalence. It is useful because the example
is easy to understand; the arbiter result is useful because it is a public
design with a less toy-like cone structure.

## What I learned from the implementation

The biggest lesson was that an optimization pass is mostly a trust-building
exercise.

The rewrite itself is often the easy part. The difficult questions are:

- What exactly does the pass consider a cell?
- What happens when a signal is wider than one bit?
- What happens when the operation is commutative?
- What happens when the cell is sequential or unknown?
- Does the objective account for the cost created by sharing?
- Can another engineer reproduce the result without reconstructing the
  original environment?

Those questions led directly to the current repository structure:

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

They also explain why the project is conservative. A pass that changes fewer
things but can explain and verify those changes is a better foundation than a
larger collection of clever rewrites that nobody can audit.

## What this project is—and is not

LogicSynth is a native, deterministic Yosys optimization pass and a
reproducible experiment around it. It is useful for exploring structural
rewriting, objective tradeoffs, and formal-equivalence-guarded optimization.

It is not a replacement for ABC, a technology mapper, a signoff timing tool,
or a power analysis tool. The public benchmark demonstrates an encouraging
QoR result and an unacceptable runtime for many production flows. Both facts
belong in the README.

The next technical steps are clear: make candidate graph updates exact rather
than approximate, reduce the cost of cone analysis, expand the public
benchmark set, and add more rewrite families only when they come with
fixture-backed equivalence evidence.

That is the point of building this in the open. The interesting result is not
that one heuristic happened to remove some cells. It is that the entire chain
from idea to RTLIL mutation to formal proof to published JSON can be inspected,
run, criticized, and improved.

## Quickstart

Build the C++ core and run its regression test:

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
