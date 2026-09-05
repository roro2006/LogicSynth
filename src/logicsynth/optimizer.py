"""Deterministic, conservative netlist rewrites."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any
import copy
import hashlib

from .metrics import LOGIC_TYPES, analyze


@dataclass(frozen=True)
class Profile:
    area_weight: float
    delay_weight: float
    power_weight: float

    PROFILES = {
        "balanced": (1.0, 1.0, 1.0),
        "area": (2.0, 0.5, 0.5),
        "timing": (0.5, 2.0, 0.5),
        "power": (0.5, 0.5, 2.0),
    }

    @classmethod
    def named(cls, name: str, **overrides: float) -> "Profile":
        if name not in cls.PROFILES:
            raise ValueError(f"unknown profile: {name}")
        values = dict(zip(("area_weight", "delay_weight", "power_weight"),
                          cls.PROFILES[name]))
        values.update({key: value for key, value in overrides.items()
                       if value is not None})
        return cls(**values)


class Optimizer:
    """Apply bounded rewrites while preserving the JSON netlist schema."""

    def __init__(self, profile: Profile, max_rewrites: int = 1000,
                 effort: int = 1) -> None:
        self.profile = profile
        self.max_rewrites = max_rewrites
        self.effort = max(1, effort)

    @staticmethod
    def _signature(cell: dict[str, Any]) -> str:
        payload = (cell.get("type"), sorted(
            (port, tuple(str(bit) for bit in signal))
            for port, signal in cell.get("connections", {}).items()
            if port not in {"Y", "Q", "out"}))
        return hashlib.sha256(repr(payload).encode()).hexdigest()

    def optimize_module(self, module: dict[str, Any]) -> tuple[dict[str, Any], dict[str, Any]]:
        result = copy.deepcopy(module)
        cells = result.get("cells", {})
        rewrites = 0
        seen: dict[str, str] = {}
        replacements: dict[str, str] = {}
        for name in sorted(list(cells)):
            if rewrites >= self.max_rewrites:
                break
            cell = cells[name]
            if cell.get("type") not in LOGIC_TYPES:
                continue
            signature = self._signature(cell)
            if signature in seen:
                original = cells[name].get("connections", {})
                canonical = cells[seen[signature]].get("connections", {})
                output_port = next((p for p in original if p in {"Y", "Q", "out"}), None)
                canonical_port = next((p for p in canonical if p in {"Y", "Q", "out"}), None)
                if output_port and canonical_port:
                    old_bits = original[output_port]
                    new_bits = canonical[canonical_port]
                    if len(old_bits) == len(new_bits):
                        replacements.update(zip(map(str, old_bits), map(str, new_bits)))
                    del cells[name]
                    rewrites += 1
            else:
                seen[signature] = name
        # Sharing is only removed when a direct output wire can be renamed safely.
        if replacements:
            for cell in cells.values():
                for port, signal in cell.get("connections", {}).items():
                    cell["connections"][port] = [
                        int(replacements.get(str(bit), str(bit))) if
                        replacements.get(str(bit), str(bit)).lstrip("-").isdigit()
                        else replacements.get(str(bit), str(bit))
                        for bit in signal
                    ]
            for port in result.get("ports", {}).values():
                port["bits"] = [int(replacements.get(str(bit), str(bit))) if
                                replacements.get(str(bit), str(bit)).lstrip("-").isdigit()
                                else replacements.get(str(bit), str(bit))
                                for bit in port.get("bits", [])]
            for netname in result.get("netnames", {}).values():
                netname["bits"] = [int(replacements.get(str(bit), str(bit))) if
                                   replacements.get(str(bit), str(bit)).lstrip("-").isdigit()
                                   else replacements.get(str(bit), str(bit))
                                   for bit in netname.get("bits", [])]
        return result, {"rewrites": rewrites, "metrics": analyze(result)}

    def optimize(self, design: dict[str, Any]) -> tuple[dict[str, Any], dict[str, Any]]:
        result = copy.deepcopy(design)
        report: dict[str, Any] = {"modules": {}}
        for name in sorted(result.get("modules", {})):
            optimized, module_report = self.optimize_module(result["modules"][name])
            result["modules"][name] = optimized
            report["modules"][name] = module_report
        return result, report
