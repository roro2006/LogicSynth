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
yosys -q -p "read_verilog $input; hierarchy -top $top; proc; write_json $out_dir/baseline.json"
PYTHONPATH="${PYTHONPATH:-src}" python3 scripts/optimize_netlist.py \
  --input "$out_dir/baseline.json" \
  --output "$out_dir/optimized.json" \
  --report "$out_dir/report.json" \
  --profile "$profile"
yosys -q -p "read_json $out_dir/optimized.json; write_verilog -noattr $out_dir/optimized.v"
"$(dirname "$0")/equivalence.sh" "$input" "$out_dir/optimized.v" "$top"
