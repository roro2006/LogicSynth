# LogicSynth

LogicSynth is a small, deterministic C++ optimization pass for Yosys RTLIL
netlists. It
is designed as a transparent research baseline: unlike a black-box commercial
optimizer, every rewrite is inspectable, configurable, and measurable.

The pass combines structural simplification, duplicate-cone sharing, and
activity-aware scoring. It does not replace ABC. Instead, it provides a
repeatable pre- or post-ABC experiment that can be inserted into a normal Yosys
flow and checked with formal equivalence.

## Quickstart

```bash
make test
make yosys-test
```

For a Yosys flow, build and invoke the native pass directly:

```bash
make yosys-plugin
yosys -m ./build/logicsynth.so \
  -p 'read_verilog design.v; prep -top top; logicsynth -profile balanced; write_verilog optimized.v'
```

## C++ core

The optimization engine is a C++17 library and native Yosys plugin.

```bash
make test
./build/logicsynth-demo
```

The current C++ core models Yosys-style cells, ports, and bit connections and
implements deterministic duplicate-cone rewrite and structural metrics.

The C++ rewrite loop evaluates each candidate against the selected profile's
weighted area/depth/power objective. A rewrite is committed only when that
objective does not regress; the report exposes before/after objective values.

## Yosys integration test

With Yosys installed, the complete flow can be exercised using the checked-in
fixture:

```bash
make yosys-test
```

This exports a baseline JSON netlist, runs the configured LogicSynth profile,
imports the optimized JSON, emits Verilog, and runs Yosys formal equivalence.
CI installs a pinned Ubuntu-package Yosys dependency and executes this flow on
every push and pull request.

When the Yosys development package is installed, the same rewrite is available
as a native pass:

```bash
make yosys-plugin
yosys -m ./build/logicsynth.so -p 'read_verilog design.v; prep -top top; logicsynth -profile balanced; write_verilog optimized.v'
```

The plugin is intentionally conservative and currently implements duplicate
combinational-cone sharing. It is the first native integration point for
bringing the C++ implementation into the Yosys pass pipeline.

Production Yosys integration is C++ through `passes/logicsynth.cc`.

The optimizer currently targets combinational `$logic` cells and preserves
unknown cells and sequential behavior. Run `scripts/equivalence.sh` with Yosys
installed to compare the original and optimized Verilog.

## Profiles and QoR

`balanced` is the default. `area` rewards fewer nodes, `timing` rewards shorter
logic depth, and `power` rewards lower activity-weighted fanout. The weights and
rewrite budget can be overridden from the command line. Results are intended as
proxies; technology mapping and signoff tools remain authoritative.

See [docs/architecture.md](docs/architecture.md) for the algorithm and
[docs/benchmarking.md](docs/benchmarking.md) for reproducible experiments.

## License

Apache-2.0. See [LICENSE](LICENSE).
