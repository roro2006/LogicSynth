#!/usr/bin/env bash
set -euo pipefail

if ! command -v yosys >/dev/null 2>&1; then
  echo "yosys is required for equivalence checking" >&2
  exit 2
fi

original=$1
optimized=$2
top=${3:-top}
yosys -qp "read_verilog $original; prep -top $top -flatten; rename -top gold; read_verilog $optimized; prep -top $top -flatten; rename -top gate; equiv_make gold gate equiv; equiv_simple; equiv_status -assert"
