#!/usr/bin/env bash
set -euo pipefail

if ! command -v yosys >/dev/null 2>&1 || ! command -v yosys-config >/dev/null 2>&1; then
  echo "SKIP: yosys and yosys-config are required"
  exit 0
fi

make yosys-plugin
yosys -q -m ./build/logicsynth.so \
  -p 'read_verilog tests/data/duplicate_cone.v; hierarchy -top top; logicsynth; stat' \
  > build/native-plugin.log
grep -q "1 duplicate cones shared" build/native-plugin.log
