#!/usr/bin/env bash
set -euo pipefail

if ! command -v yosys >/dev/null 2>&1; then
  echo "SKIP: yosys is not installed"
  exit 0
fi

rm -rf build/yosys-test
scripts/yosys_flow.sh tests/data/duplicate_cone.v top build/yosys-test
python3 - <<'PY'
import json
with open("build/yosys-test/report.json") as handle:
    report = json.load(handle)
assert report["modules"]["top"]["rewrites"] >= 1, report
PY
