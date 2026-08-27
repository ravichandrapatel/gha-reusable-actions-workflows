"""
FILE_NAME: test_check_inventory.py
DESCRIPTION: Unit tests for check-inventory/checkInventory.py.
VERSION: 1.0.0
AUTHORS: DevOps Team
"""

from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "checkInventory.py"


def run_inventory(
    action_path: Path,
    *,
    repo: str,
    inventory_file: str = "inventory.json",
    output: Path | None = None,
) -> subprocess.CompletedProcess[str]:
    args = [
        sys.executable,
        "-u",
        str(SCRIPT),
        "--action-path",
        str(action_path),
        "--inventory-file",
        inventory_file,
        "--repo",
        repo,
    ]
    if output is not None:
        args.extend(["--output", str(output)])
    return subprocess.run(args, capture_output=True, text=True, check=False)


class CheckInventoryTests(unittest.TestCase):
    def test_match_by_repo_name(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "inventory.json").write_text('["my-app","other"]\n', encoding="utf-8")
            result = run_inventory(root, repo="org/my-app")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("matched : true", result.stdout)

    def test_hard_miss_exits_1(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "inventory.json").write_text('["allowed"]\n', encoding="utf-8")
            result = run_inventory(root, repo="missing")
            self.assertEqual(result.returncode, 1)
            self.assertIn("not in inventory.json", result.stderr)

    def test_rejects_inventory_path_segments(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "inventory.json").write_text("[]\n", encoding="utf-8")
            result = run_inventory(root, repo="my-app", inventory_file="../inventory.json")
            self.assertEqual(result.returncode, 1)
            self.assertIn("must be a basename", result.stderr)

    def test_rejects_object_payload(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "inventory.json").write_text(json.dumps({"repos": ["my-app"]}), encoding="utf-8")
            result = run_inventory(root, repo="my-app")
            self.assertEqual(result.returncode, 1)
            self.assertIn("JSON array of repo names", result.stderr)


if __name__ == "__main__":
    unittest.main()
