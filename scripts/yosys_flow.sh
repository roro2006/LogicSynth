#!/usr/bin/env bash
set -euo pipefail

input=${1:?input Verilog file is required}
top=${2:-top}
out_dir=${3:-build/yosys}
profile=${PROFILE:-balanced}

command -v yosys >/dev/null 2>&1 || {
  echo "yosys is required for the Yosys integration flow" >&2
  exit 2
}
mkdir -p "$out_dir"
make yosys-plugin
yosys -m ./build/logicsynth.so \
  -p "read_verilog $input; hierarchy -top $top; proc; logicsynth -profile $profile; stat; write_verilog -noattr $out_dir/optimized.v" \
  > "$out_dir/optimization.log" 2>&1
"$(dirname "$0")/equivalence.sh" "$input" "$out_dir/optimized.v" "$top"
