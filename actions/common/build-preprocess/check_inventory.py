"""
FILE_NAME: main.py
DESCRIPTION: Match a caller repo against a JSON inventory allowlist.
VERSION: 1.1.0
EXIT_CODES: 0 = match (or soft miss); 1 = hard miss, invalid inventory, or I/O error
AUTHORS: Platform / DevOps
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Any

EXIT_CODE_SUCCESS = 0
EXIT_CODE_ERROR = 1

PROJECT_PREFIX = "[BUILD-PREPROCESS]"


def _log(message: str) -> None:
    """INTENT: Print a prefixed breadcrumb. INPUT: message. OUTPUT: None. SIDE_EFFECTS: stdout."""
    print(f"{PROJECT_PREFIX} {message}")


def _default_inventory_path() -> str:
    """INTENT: Resolve inventory path from ACTION_PATH env or script directory.
    INPUT: None. OUTPUT: path string. SIDE_EFFECTS: reads env."""
    action_path = os.environ.get("ACTION_PATH", "").strip()
    if action_path:
        return str(Path(action_path) / "inventory.json")
    return str(Path(__file__).resolve().parent / "inventory.json")


def parse_args() -> argparse.Namespace:
    """INTENT: Parse CLI; defaults from CALLER_REPO, ACTION_PATH, GITHUB_OUTPUT.
    INPUT: argv + env. OUTPUT: Namespace. SIDE_EFFECTS: None."""
    p = argparse.ArgumentParser(
        description="Match caller repo against a JSON inventory allowlist (exact membership)."
    )
    p.add_argument(
        "--repo",
        default=os.environ.get("CALLER_REPO", ""),
        help="Caller repository / app id to match (default: env CALLER_REPO)",
    )
    p.add_argument(
        "--inventory-path",
        default="",
        help="Path to inventory JSON array (default: ${ACTION_PATH}/inventory.json or bundled file)",
    )
    p.add_argument(
        "--output",
        default=os.environ.get("GITHUB_OUTPUT", ""),
        help="GitHub Actions output file path (default: env GITHUB_OUTPUT)",
    )
    p.add_argument(
        "--soft",
        action="store_true",
        help="On miss: write matched=false and exit 0 instead of failing",
    )
    p.add_argument(
        "--dry-run",
        action="store_true",
        help="Print match result to stdout; do not write --output / GITHUB_OUTPUT",
    )
    return p.parse_args()


def load_inventory(path: Path) -> list[str]:
    """INTENT: Load and validate inventory JSON array of strings.
    INPUT: path. OUTPUT: list[str]. SIDE_EFFECTS: reads file. RAISES: ValueError, OSError, json.JSONDecodeError."""
    raw: Any = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(raw, list):
        raise ValueError(f"inventory root must be a JSON array, got {type(raw).__name__}")
    entries: list[str] = []
    for idx, item in enumerate(raw):
        if not isinstance(item, str):
            raise ValueError(f"inventory[{idx}] must be a string, got {type(item).__name__}")
        if not item:
            raise ValueError(f"inventory[{idx}] must be a non-empty string")
        entries.append(item)
    return entries


def write_output(*, matched: bool, matched_id: str, output_path: str) -> None:
    """INTENT: Append matched / matched_id to the output file.
    INPUT: matched, matched_id, path. OUTPUT: None. SIDE_EFFECTS: appends file."""
    with open(output_path, "a", encoding="utf-8") as fh:
        fh.write(f"matched={str(matched).lower()}\n")
        fh.write(f"matched_id={matched_id}\n")


def main() -> int:
    """INTENT: Load inventory, exact-match --repo, write outputs / exit code.
    INPUT: None. OUTPUT: int exit code. SIDE_EFFECTS: stdout/stderr, optional output file."""
    try:
        args = parse_args()
        repo = (args.repo or "").strip()
        if not repo:
            print(
                f"{PROJECT_PREFIX} ERROR: --repo is required (or set env CALLER_REPO)",
                file=sys.stderr,
            )
            return EXIT_CODE_ERROR

        inventory_raw = (args.inventory_path or "").strip() or _default_inventory_path()
        inventory_path = Path(inventory_raw)
        if not inventory_path.is_file():
            print(
                f"{PROJECT_PREFIX} ERROR: inventory file not found: {inventory_path}",
                file=sys.stderr,
            )
            return EXIT_CODE_ERROR

        entries = load_inventory(inventory_path)
        matched = repo in entries
        matched_id = repo if matched else ""

        _log(
            f"inventory={inventory_path} entries={len(entries)} repo={repo} matched={matched}"
        )

        output_path = (args.output or "").strip()
        if args.dry_run:
            print(json.dumps({"matched": matched, "matched_id": matched_id, "repo": repo}))
        elif output_path:
            write_output(matched=matched, matched_id=matched_id, output_path=output_path)
        else:
            _log("no --output / GITHUB_OUTPUT; skipping file-append.")

        if matched:
            return EXIT_CODE_SUCCESS
        if args.soft:
            _log("miss with --soft; exiting 0")
            return EXIT_CODE_SUCCESS

        print(
            f"{PROJECT_PREFIX} ERROR: repo '{repo}' is not in inventory",
            file=sys.stderr,
        )
        return EXIT_CODE_ERROR

    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"{PROJECT_PREFIX} ERROR: {exc}", file=sys.stderr)
        return EXIT_CODE_ERROR


if __name__ == "__main__":
    sys.exit(main())
