#!/usr/bin/env bash
set -euo pipefail

input=${1:?input Verilog file is required}
out_dir=${2:-results/native}
mkdir -p "$out_dir"
make yosys-plugin

extract_json() {
  awk 'BEGIN { depth=0; started=0 }
    /^[[:space:]]*\{/ { started=1 }
    started {
      print
      opens=gsub(/\{/, "{")
      closes=gsub(/\}/, "}")
      depth += opens - closes
      if (depth == 0) exit
    }' "$1" > "$2"
}

run_stat() {
  local name=$1
  local command=$2
  local module_args=""
  if [ "$name" = "logicsynth" ]; then
    module_args="-m ./build/logicsynth.so"
  fi
  yosys $module_args -p "$command; stat -json" > "$out_dir/$name.log" 2>&1
  extract_json "$out_dir/$name.log" "$out_dir/$name.json"
}

run_stat baseline "read_verilog $input; hierarchy -top top; proc"
run_stat abc "read_verilog $input; hierarchy -top top; proc; opt; abc -g simple"
run_stat logicsynth "read_verilog $input; hierarchy -top top; proc; logicsynth -profile balanced"
yosys -m ./build/logicsynth.so \
  -q -p "read_verilog $input; hierarchy -top top; proc; logicsynth -profile balanced; write_verilog -noattr $out_dir/optimized.v" \
  > "$out_dir/optimized.log" 2>&1

yosys_version=$(yosys -V | head -1)
cat > "$out_dir/summary.json" <<EOF
{
  "design": "$(basename "$input")",
  "profile": "balanced",
  "yosys_version": "$yosys_version",
  "baseline": $(cat "$out_dir/baseline.json"),
  "abc": $(cat "$out_dir/abc.json"),
  "logicsynth": $(cat "$out_dir/logicsynth.json")
}
EOF
printf 'design=%s\nprofile=balanced\nyosys=%s\n' "$(basename "$input")" "$yosys_version" > "$out_dir/metadata.txt"
