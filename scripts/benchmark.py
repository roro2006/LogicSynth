#!/usr/bin/env python3
"""Run LogicSynth over a directory of JSON netlists and emit raw results."""

import argparse
import json
import platform
import sys
import time
from pathlib import Path

from logicsynth.metrics import analyze
from logicsynth.optimizer import Optimizer, Profile


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("input_dir", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--profile", choices=sorted(Profile.PROFILES), default="balanced")
    parser.add_argument("--max-rewrites", type=int, default=1000)
    args = parser.parse_args()
    profile = Profile.named(args.profile)
    records = []
    for source in sorted(args.input_dir.glob("*.json")):
        design = json.loads(source.read_text())
        before = {name: analyze(module) for name, module in design.get("modules", {}).items()}
        started = time.perf_counter()
        _, report = Optimizer(profile, args.max_rewrites).optimize(design)
        elapsed_ms = (time.perf_counter() - started) * 1000
        records.append({
            "design": source.name,
            "before": before,
            "after": {name: data["metrics"] for name, data in report["modules"].items()},
            "rewrites": sum(data["rewrites"] for data in report["modules"].values()),
            "runtime_ms": round(elapsed_ms, 3),
        })
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps({
        "tool": "LogicSynth",
        "profile": profile.__dict__,
        "python": sys.version,
        "platform": platform.platform(),
        "records": records,
    }, indent=2, sort_keys=True) + "\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
