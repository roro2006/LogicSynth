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
grep -q "rewrites=1 rejected=0" build/native-plugin.log
grep -q "profile=area area_weight=3.000" build/native-plugin.log

yosys -m ./build/logicsynth.so \
  -p 'read_verilog tests/data/native_edge_cases.v; hierarchy -top top; proc; logicsynth -profile power; write_verilog build/native-edge.v' \
  > build/native-edge.log
grep -q "rewrites=1 rejected=0" build/native-edge.log

yosys -m ./build/logicsynth.so \
  -p 'read_verilog tests/data/identity_rewrites.v; hierarchy -top top; logicsynth; write_verilog -noattr build/identity.v' \
  > build/identity.log
grep -q "rewrites=4 rejected=0" build/identity.log
scripts/equivalence.sh tests/data/identity_rewrites.v build/identity.v top

yosys -m ./build/logicsynth.so \
  -p 'read_verilog tests/data/commutative_cones.v; hierarchy -top top; logicsynth; write_verilog -noattr build/commutative.v' \
  > build/commutative.log
grep -q "rewrites=1 rejected=0" build/commutative.log
scripts/equivalence.sh tests/data/commutative_cones.v build/commutative.v top

yosys -m ./build/logicsynth.so \
  -p 'read_verilog tests/data/bus_mux.v; hierarchy -top top; proc; logicsynth; write_verilog -noattr build/bus-mux.v' \
  > build/bus-mux.log
grep -q "rewrites=1 rejected=0" build/bus-mux.log
scripts/equivalence.sh tests/data/bus_mux.v build/bus-mux.v top

yosys -m ./build/logicsynth.so \
  -p 'read_verilog tests/data/sequential_unknown.v; hierarchy -top top; proc; logicsynth; stat' \
  > build/sequential-unknown.log
grep -q "rewrites=0 rejected=0" build/sequential-unknown.log
