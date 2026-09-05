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
