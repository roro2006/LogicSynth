# Reproducible benchmarking

Benchmarks should be treated like an experiment, not a screenshot. Record the
repository revision, Python version, Yosys/ABC versions, host, profile, weights,
rewrite budget, input checksum, runtime, and raw JSON metrics.

## Method

1. Obtain a public RTL design and record its source URL and license.
2. Run the baseline Yosys script with fixed top-module and ABC options.
3. Export `baseline.json`, run LogicSynth, and re-import the optimized JSON.
4. Run the same mapping and metric collection on both designs.
5. Run formal equivalence and retain the command output.
6. Store one JSON record per design under `results/`; generate tables or plots
   from those records without hand-editing values.

For the checked-in smoke fixture, `make benchmark` writes
`results/latest.json`. The Yosys integration flow is intentionally separate:
`make yosys-test` proves that the optimized interchange file can be re-imported
and remains equivalent, while the benchmark harness measures the structural
proxies.

The supplied harness works on an existing directory of Yosys JSON files, which
keeps CI offline and avoids silently changing a benchmark when an upstream
repository moves. Public benchmark acquisition belongs in a pinned manifest
with checksums when a study is published.

## Interpreting results

`area_proxy` and `power_proxy` are structural indicators. They are useful for
comparing variants under identical lowering and mapping settings, but they are
not a replacement for library area, STA, or switching simulation. Report
runtime and failed equivalence checks alongside QoR so improvements remain
credible and reproducible.
