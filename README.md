# LogicSynth

LogicSynth is a small, deterministic optimization pass for Yosys JSON netlists. It
is designed as a transparent research baseline: unlike a black-box commercial
optimizer, every rewrite is inspectable, configurable, and measurable.

The pass combines structural simplification, duplicate-cone sharing, and
activity-aware scoring. It does not replace ABC. Instead, it provides a
repeatable pre- or post-ABC experiment that can be inserted into a normal Yosys
flow and checked with formal equivalence.

## Quickstart

```bash
python3 -m pip install -e '.[test]'
python3 -m logicsynth.cli --help
python3 scripts/optimize_netlist.py \
  --input tests/data/tiny.json \
  --output /tmp/tiny.optimized.json \
  --profile balanced
python3 -m pytest
```

For a Yosys flow, export a JSON netlist, optimize it, and import it again:

```yosys
read_verilog design.v
hierarchy -top top
proc; opt; abc -g simple
write_json build/baseline.json
```

```bash
python3 scripts/optimize_netlist.py \
  --input build/baseline.json --output build/optimized.json
```

```yosys
read_json build/optimized.json
write_verilog -noattr build/optimized.v
```

## C++ core

The optimization engine is also available as a C++17 library. This is the
preferred path for production integration and eventual native Yosys pass
packaging; the Python implementation remains useful as a reference and
benchmark driver while the interchange layer is expanded.

```bash
make test
./build/logicsynth-demo
```

The current C++ core models Yosys-style cells, ports, and bit connections and
implements the same deterministic duplicate-cone rewrite and structural
metrics. The next integration step is a Yosys JSON adapter or native Yosys
plugin, depending on the target deployment.

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
