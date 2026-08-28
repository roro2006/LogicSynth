#!/usr/bin/env bash
set -euo pipefail

if ! command -v yosys >/dev/null 2>&1 || ! command -v yosys-config >/dev/null 2>&1; then
  echo "SKIP: yosys and yosys-config are required"
  exit 0
fi

make yosys-plugin
yosys -m ./build/logicsynth.so \
  -p 'read_verilog tests/data/duplicate_cone.v; hierarchy -top top; logicsynth -profile area -area_weight 3 -max_rewrites 1; stat' \
  > build/native-plugin.log
grep -q "1 duplicate cones shared" build/native-plugin.log
grep -q "profile=area area_weight=3.000" build/native-plugin.log

yosys -m ./build/logicsynth.so \
  -p 'read_verilog tests/data/native_edge_cases.v; hierarchy -top top; proc; logicsynth -profile power; write_verilog build/native-edge.v' \
  > build/native-edge.log
grep -q "1 duplicate cones shared" build/native-edge.log
