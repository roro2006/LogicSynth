"""Structural metrics for Yosys JSON netlists."""

from __future__ import annotations

from collections import defaultdict, deque
from typing import Any

LOGIC_TYPES = {"$and", "$or", "$xor", "$xnor", "$not", "$mux", "$_AND_", "$_OR_"}


def _bits(signal: Any) -> list[str]:
    if isinstance(signal, list):
        return [str(bit) for bit in signal]
    return []


def analyze(module: dict[str, Any]) -> dict[str, Any]:
    """Return deterministic, technology-independent structural QoR proxies."""
    cells = module.get("cells", {})
    edges: dict[str, set[str]] = defaultdict(set)
    indegree: dict[str, int] = {name: 0 for name in cells}
    depth: dict[str, int] = {name: 0 for name in cells}
    drivers: dict[str, str] = {}
    for name, cell in cells.items():
        for signal in cell.get("connections", {}).values():
            for bit in _bits(signal):
                drivers.setdefault(bit, name)
    for name, cell in cells.items():
        for signal in cell.get("connections", {}).values():
            for bit in _bits(signal):
                source = drivers.get(bit)
                if source and source != name and name not in edges[source]:
                    edges[source].add(name)
                    indegree[name] += 1
    queue = deque(name for name, count in indegree.items() if count == 0)
    while queue:
        source = queue.popleft()
        for target in sorted(edges[source]):
            depth[target] = max(depth[target], depth[source] + 1)
            indegree[target] -= 1
            if indegree[target] == 0:
                queue.append(target)
    logic = [cell for cell in cells.values() if cell.get("type") in LOGIC_TYPES]
    counts: dict[str, int] = defaultdict(int)
    for cell in logic:
        counts[cell["type"]] += 1
    fanout = {name: len(targets) for name, targets in edges.items()}
    activity_power = sum((fanout.get(name, 0) + 1) * (depth.get(name, 0) + 1)
                         for name in cells)
    return {
        "cells": len(cells),
        "logic_cells": len(logic),
        "edges": sum(len(targets) for targets in edges.values()),
        "max_depth": max(depth.values(), default=0),
        "area_proxy": len(logic),
        "power_proxy": activity_power,
        "fanout_max": max(fanout.values(), default=0),
        "gate_counts": dict(sorted(counts.items())),
    }
