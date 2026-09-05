# Native Yosys pass

`passes/logicsynth.cc` is a Yosys plugin adapter. It uses RTLIL signals
directly, so the pass can share identical `$and`, `$or`, `$xor`, `$xnor`, `$not`,
`$mux`, and mapped AND/OR cells without serializing through JSON.

Build it with:

```bash
sudo apt-get install yosys yosys-dev
make yosys-plugin
```

The CI smoke test runs the pass before Yosys's regular optimization passes so
the fixture contains two duplicate `$and` cells:

```bash
make yosys-plugin-test
```

The plugin accepts `-profile balanced|area|timing|power`, explicit
`-area_weight`, `-delay_weight`, and `-power_weight` overrides, plus
`-max_rewrites N`. It visits selected modules in deterministic cell-map order.
It excludes sequential and unknown cell types. Each module reports area, depth,
fanout-based power proxy, weighted objective before/after, and rejected
candidates. Formal equivalence remains the acceptance gate; use
`scripts/equivalence.sh` for a complete automated check.
