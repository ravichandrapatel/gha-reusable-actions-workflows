"""
FILE_NAME: checkInventory.py
DESCRIPTION: Match caller repo against inventory.json under ACTION_PATH.
VERSION: 1.7.0
AUTHORS: DevOps Team
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser(description="Match caller repo against inventory.json")
    parser.add_argument("--action-path", default="")
    parser.add_argument("--inventory-file", default="inventory.json")
    parser.add_argument("--repo", default="")
    parser.add_argument("--output", default="")
    args = parser.parse_args()

    action_dir = (
        args.action_path.strip()
        or os.environ.get("ACTION_PATH", "").strip()
        or os.environ.get("GITHUB_ACTION_PATH", "").strip()
        or str(Path(__file__).resolve().parent)
    )
    basename = args.inventory_file.strip() or "inventory.json"
    if "/" in basename or "\\" in basename or ".." in basename:
        print("ERROR: --inventory-file must be a basename", file=sys.stderr)
        return 1

    path = Path(action_dir) / basename
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1
    if not isinstance(payload, list):
        print("ERROR: inventory must be a JSON array of repo names", file=sys.stderr)
        return 1

    caller = args.repo.strip() or os.environ.get("GITHUB_REPOSITORY", "").strip()
    if not caller:
        print("ERROR: pass --repo or set GITHUB_REPOSITORY", file=sys.stderr)
        return 1

    names = {str(item) for item in payload}
    names |= {item.rsplit("/", 1)[-1] for item in names}
    matched = caller in names or caller.rsplit("/", 1)[-1] in names

    outputs = {
        "repos": json.dumps(payload, separators=(",", ":"), ensure_ascii=False),
        "matched": "true" if matched else "false",
        "repo": caller
    }
    if not matched:
        print(f"ERROR: '{caller}' not in {path.name}: {outputs['repos']}", file=sys.stderr)
        return 1

    for key, value in outputs.items():
        print(f"{key} : {value}")
    if args.output.strip():
        with open(args.output.strip(), "a", encoding="utf-8") as fh:
            fh.writelines(f"{key}={value}\n" for key, value in outputs.items())
    return 0


if __name__ == "__main__":
    sys.exit(main())
