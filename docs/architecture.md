# Architecture: a readable optimization loop

LogicSynth sits between Yosys and the technology-specific implementation flow.
Yosys lowers RTL to a JSON netlist, LogicSynth evaluates structural cost, and
the result can return to Yosys for mapping, formal checking, or another ABC
iteration. Keeping the interchange format explicit makes experiments easy to
inspect and keeps the optimizer independent of a particular cell library.

The production-oriented core is C++17 under `include/` and `src/cpp/`, with a
small CMake build and CTest suite. The native plugin and library are the single
implementation path, avoiding semantic drift between wrappers.

## Analysis layer

For every module, the analyzer builds a driver map and a directed cell graph.
It reports cell and edge counts, fanout, maximum topological depth, per-gate
counts, an area proxy, and an activity-weighted power proxy. The depth metric is
deliberately conservative: it counts logic levels rather than claiming a
technology-specific delay.

## Rewrite layer

The first rewrite is structural hashing for identical combinational cones.
Cells are visited in sorted name order, so the canonical representative is
stable across runs. A rewrite budget (`max_rewrites`) bounds runtime and makes
large designs safe to evaluate. Unknown and sequential cells are left intact.

The design leaves room for additional local rules: constant propagation,
Boolean identities, balancing, and don't-care rules can be added as independent
rewrite candidates and scored against the same metrics. A future rule should
only commit when it can provide a proof obligation or be rejected by the
formal gate.

## Objective and tradeoffs

Profiles expose area, delay, and power weights. Area favors fewer logic cells;
timing favors fewer levels; power favors lower activity-weighted fanout. These
are proxies, not signoff numbers. The expected tradeoff is that timing-oriented
rewrites may duplicate logic while area-oriented sharing may increase fanout.
The benchmark report should therefore publish all three dimensions rather than
one composite score. The C++ optimizer now computes the weighted objective for
each candidate rewrite and rejects candidates that regress it. Reports retain
the objective before and after optimization, making profile behavior observable
in tests and benchmark output.

## Correctness boundary

JSON rewriting is conservative and preserves unknown cells. The recommended
flow runs `scripts/equivalence.sh` after re-importing both netlists into Yosys.
Formal equivalence is the acceptance gate; a better proxy score is never enough
to accept a behavior-changing rewrite.
