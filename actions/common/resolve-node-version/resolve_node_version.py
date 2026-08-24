#!/usr/bin/env python3
"""
FILE_NAME: resolve_node_version.py
DESCRIPTION: Resolve npm-style Node version ranges to a concrete setup-node version.
VERSION: 1.0.0
AUTHORS: DevOps Team
"""

from __future__ import annotations

import argparse
import re
import sys
from dataclasses import dataclass

CONSTRAINT_RE = re.compile(r"(>=|<=|>|<|=)\s*([0-9]+(?:\.[0-9]+)*)")


@dataclass(frozen=True, order=True)
class SemVer:
    major: int
    minor: int = 0
    patch: int = 0

    @classmethod
    def parse(cls, raw: str) -> SemVer:
        parts = [int(part) for part in raw.strip().split(".")]
        while len(parts) < 3:
            parts.append(0)
        return cls(parts[0], parts[1], parts[2])

    def format(self) -> str:
        if self.patch:
            return f"{self.major}.{self.minor}.{self.patch}"
        if self.minor:
            return f"{self.major}.{self.minor}"
        return str(self.major)


def max_strictly_below(version: SemVer) -> SemVer:
    if version.patch > 0:
        return SemVer(version.major, version.minor, version.patch - 1)
    if version.minor > 0:
        return SemVer(version.major, version.minor - 1, 0)
    if version.major > 0:
        return SemVer(version.major - 1, 0, 0)
    return SemVer(0, 0, 0)


def bump_strictly_above(version: SemVer) -> SemVer:
    if version.patch or version.minor:
        return SemVer(version.major, version.minor, version.patch + 1)
    return SemVer(version.major + 1, 0, 0)


def satisfies(candidate: SemVer, operator: str, bound: SemVer) -> bool:
    if operator == ">=":
        return candidate >= bound
    if operator == ">":
        return candidate > bound
    if operator == "<=":
        return candidate <= bound
    if operator == "<":
        return candidate < bound
    if operator == "=":
        return candidate == bound
    raise ValueError(f"unsupported operator: {operator}")


def resolve_node_version(raw: str) -> str:
    value = raw.strip()
    if value.startswith("v"):
        value = value[1:]

    if not value or not re.search(r"[<>=]", value):
        return value

    constraints = CONSTRAINT_RE.findall(value)
    if not constraints:
        return value

    if len(constraints) == 1 and constraints[0][0] == "=":
        return SemVer.parse(constraints[0][1]).format()

    lower: SemVer | None = None
    lower_op = ">="
    upper: SemVer | None = None
    upper_op = "<"

    for operator, bound_raw in constraints:
        bound = SemVer.parse(bound_raw)
        if operator in {">", ">="}:
            lower = bound
            lower_op = operator
        elif operator in {"<", "<="}:
            upper = bound
            upper_op = operator
        elif operator == "=":
            return bound.format()

    candidate: SemVer | None = None
    if upper is not None:
        candidate = upper if upper_op == "<=" else max_strictly_below(upper)

    if lower is not None:
        minimum = lower if lower_op == ">=" else bump_strictly_above(lower)
        if candidate is None or candidate < minimum:
            candidate = minimum

    if candidate is None:
        return value

    if upper is not None and not satisfies(candidate, upper_op, upper):
        raise ValueError(f"resolved Node version {candidate.format()} violates upper bound")
    if lower is not None and not satisfies(candidate, lower_op, lower):
        raise ValueError(f"resolved Node version {candidate.format()} violates lower bound")

    return candidate.format()


def main() -> int:
    parser = argparse.ArgumentParser(description="Resolve Node.js version range for setup-node")
    parser.add_argument("node_version", nargs="?", default="")
    parser.add_argument("--node-version", dest="node_version_flag", default="")
    args = parser.parse_args()

    raw = args.node_version_flag.strip() or args.node_version.strip()
    if not raw:
        print("ERROR: node version is required", file=sys.stderr)
        return 1

    try:
        print(resolve_node_version(raw))
    except ValueError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
