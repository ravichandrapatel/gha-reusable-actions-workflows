#!/usr/bin/env python3
# =============================================================================
# FILE_NAME: spvs_conftest_report.py
# DESCRIPTION: Format Conftest JSON results with YAML line numbers for SPVS failures.
# VERSION: 1.0.0
# EXIT_CODES/SIGNALS: 0 when no failures in report, 1 when failures printed
# AUTHORS: DevOps Team
# =============================================================================
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

PROJECT_PREFIX = "[SPVS-CONFTEST]"

LOCATION_RE = re.compile(r"\[([^\]]+)\]")
JOB_RE = re.compile(r"job (\S+)")
USES_REF_RE = re.compile(r"uses (\S+)")


def _log(message: str) -> None:
    print(f"{PROJECT_PREFIX} {message}", file=sys.stderr)


def _find_uses_line(lines: list[str], uses_ref: str) -> int | None:
    for line_no, line in enumerate(lines, start=1):
        if "uses:" in line and uses_ref in line:
            return line_no
    return None


def _find_run_line_for_job(lines: list[str], job_name: str, step_index: int | None) -> int | None:
    job_header = re.compile(rf"^\s+{re.escape(job_name)}:\s*$")
    in_target_job = False
    step_count = -1
    for line_no, line in enumerate(lines, start=1):
        if job_header.match(line):
            in_target_job = True
            step_count = -1
            continue
        if in_target_job and re.match(r"^[^\s]", line):
            in_target_job = False
            continue
        if not in_target_job:
            continue
        if re.match(r"\s+- ", line):
            step_count += 1
        if "run:" in line and (step_index is None or step_count == step_index):
            return line_no
    return None


def _find_top_level_permissions_line(lines: list[str]) -> int | None:
    for line_no, line in enumerate(lines, start=1):
        if re.match(r"^permissions:", line):
            return line_no
    return None


def _find_on_line(lines: list[str]) -> int | None:
    for line_no, line in enumerate(lines, start=1):
        if re.match(r"^on:", line):
            return line_no
    return None


def _parse_step_index(location: str) -> int | None:
    match = re.search(r"steps\[(\d+)\]", location)
    if not match:
        return None
    return int(match.group(1))


def _find_composite_step_line(lines: list[str], step_index: int, field: str, uses_ref: str | None) -> int | None:
    in_steps = False
    step_count = -1
    for line_no, line in enumerate(lines, start=1):
        if re.match(r"^\s+steps:\s*$", line):
            in_steps = True
            continue
        if in_steps and re.match(r"^[^\s]", line):
            in_steps = False
            continue
        if not in_steps:
            continue
        if re.match(r"\s+- ", line):
            step_count += 1
        if step_count != step_index:
            continue
        if field == "uses" and uses_ref and "uses:" in line and uses_ref in line:
            return line_no
        if field == "run" and "run:" in line:
            return line_no
        if field == "env" and "env:" in line:
            return line_no
    return None


def resolve_line(filepath: Path, message: str) -> int | None:
    """INTENT: Map a Conftest failure message to a best-effort YAML line number."""
    try:
        lines = filepath.read_text(encoding="utf-8").splitlines()
    except OSError:
        return None

    location_match = LOCATION_RE.search(message)
    if location_match:
        location = location_match.group(1)
        step_index = _parse_step_index(location)
        if location.startswith("runs.steps") and step_index is not None:
            uses_match = USES_REF_RE.search(message)
            uses_ref = uses_match.group(1) if uses_match else None
            if ".uses" in location:
                line = _find_composite_step_line(lines, step_index, "uses", uses_ref)
                if line:
                    return line
            if ".run" in location:
                line = _find_composite_step_line(lines, step_index, "run", None)
                if line:
                    return line
            if ".env" in location:
                line = _find_composite_step_line(lines, step_index, "env", None)
                if line:
                    return line
        if ".uses" in location:
            uses_match = USES_REF_RE.search(message)
            if uses_match:
                line = _find_uses_line(lines, uses_match.group(1))
                if line:
                    return line
        if ".run" in location or "run block" in message:
            job_match = JOB_RE.search(message)
            if job_match:
                return _find_run_line_for_job(lines, job_match.group(1), step_index)
        if location in {"permissions", "on"} or location.startswith("jobs.") and ".permissions" in location:
            if location == "permissions":
                return _find_top_level_permissions_line(lines)
            if location == "on":
                return _find_on_line(lines)

    uses_match = USES_REF_RE.search(message)
    if uses_match:
        line = _find_uses_line(lines, uses_match.group(1))
        if line:
            return line

    if "run block" in message:
        job_match = JOB_RE.search(message)
        if job_match:
            return _find_run_line_for_job(lines, job_match.group(1), None)

    if "top-level permissions" in message or "workflow must declare explicit top-level permissions" in message:
        return _find_top_level_permissions_line(lines)

    if "pull_request_target" in message:
        return _find_on_line(lines)

    return None


def format_report(payload: list[dict]) -> tuple[int, str]:
    """INTENT: Build human-readable report with file:line prefixes."""
    output_lines: list[str] = []
    failure_count = 0
    success_count = 0

    for item in payload:
        filename = item.get("filename", "")
        namespace = item.get("namespace", "")
        successes = int(item.get("successes", 0))
        failures = item.get("failures") or []

        for failure in failures:
            message = failure.get("msg", "")
            line = resolve_line(Path(filename), message)
            failure_count += 1
            if line is not None:
                output_lines.append(f"FAIL {filename}:{line} ({namespace}) {message}")
            else:
                output_lines.append(f"FAIL {filename} ({namespace}) {message}")

        if not failures:
            success_count += 1

    summary = (
        f"{success_count} file(s) passed, {failure_count} failure(s)"
        if failure_count
        else f"{success_count} file(s) passed, 0 failures ({sum(int(i.get('successes', 0)) for i in payload)} checks)"
    )
    body = "\n".join(output_lines)
    if body:
        body = f"{body}\n"
    body = f"{body}{summary}"
    return failure_count, body


def main() -> int:
    if len(sys.argv) != 2:
        _log("ERROR: usage: spvs_conftest_report.py CONftest.json")
        return 2

    json_path = Path(sys.argv[1])
    try:
        payload = json.loads(json_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        _log(f"ERROR: cannot read Conftest JSON: {exc}")
        return 2

    if not isinstance(payload, list):
        _log("ERROR: expected Conftest JSON array")
        return 2

    failure_count, report = format_report(payload)
    print(report)
    return 1 if failure_count else 0


if __name__ == "__main__":
    sys.exit(main())
