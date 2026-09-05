"""Command-line interface."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from .optimizer import Optimizer, Profile
from .metrics import analyze


def main() -> int:
    parser = argparse.ArgumentParser(description="Optimize a Yosys JSON netlist")
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--profile", choices=sorted(Profile.PROFILES), default="balanced")
    parser.add_argument("--area-weight", type=float)
    parser.add_argument("--delay-weight", type=float)
    parser.add_argument("--power-weight", type=float)
    parser.add_argument("--effort", type=int, default=1)
    parser.add_argument("--max-rewrites", type=int, default=1000)
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    design = json.loads(args.input.read_text())
    profile = Profile.named(args.profile, area_weight=args.area_weight,
                            delay_weight=args.delay_weight,
                            power_weight=args.power_weight)
    optimized, report = Optimizer(profile, args.max_rewrites, args.effort).optimize(design)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(optimized, indent=2, sort_keys=True) + "\n")
    report["profile"] = profile.__dict__
    report["input"] = {name: analyze(module) for name, module in design.get("modules", {}).items()}
    if args.report:
        args.report.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
