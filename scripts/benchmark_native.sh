#!/usr/bin/env bash
set -euo pipefail

input=${1:?input Verilog file is required}
out_dir=${2:-results/native}
mkdir -p "$out_dir"
make yosys-plugin
yosys -m ./build/logicsynth.so \
  -p "read_verilog $input; hierarchy -top top; proc; stat; logicsynth -profile balanced; stat; write_verilog -noattr $out_dir/optimized.v" \
  > "$out_dir/run.log"
printf 'design=%s\nprofile=balanced\n' "$input" > "$out_dir/metadata.txt"
