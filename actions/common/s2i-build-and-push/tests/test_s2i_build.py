"""Unit tests for s2i-build-and-push/s2i-build.sh validation."""

from __future__ import annotations

import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "s2i-build.sh"


def run_s2i_build(
    *,
    source: Path,
    builder_image: str = "nexus.example.com/ubi8/openjdk-11:1.14",
    image: str = "nexus.example.com/org/product/app:tag",
    tls_verify: str = "true",
    pull_policy: str = "if-not-present",
) -> subprocess.CompletedProcess[str]:
    cmd = [
        "bash",
        str(SCRIPT),
        "--source",
        str(source),
        "--builder-image",
        builder_image,
        "--image",
        image,
        "--tls-verify",
        tls_verify,
        "--pull-policy",
        pull_policy,
    ]
    return subprocess.run(cmd, capture_output=True, text=True, check=False)


class S2iBuildTests(unittest.TestCase):
    def test_rejects_empty_source(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            source = Path(tmp) / "empty"
            source.mkdir()
            result = run_s2i_build(source=source)
            self.assertEqual(result.returncode, 1)
            self.assertIn("source directory is empty", result.stderr)

    def test_rejects_bad_builder_image(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            source = Path(tmp) / "src"
            source.mkdir()
            (source / "app.jar").write_bytes(b"jar")
            result = run_s2i_build(
                source=source,
                builder_image="bad image; rm -rf /",
            )
            self.assertEqual(result.returncode, 1)
            self.assertIn("builder_image is not a valid image reference", result.stderr)

    def test_rejects_bad_pull_policy(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            source = Path(tmp) / "src"
            source.mkdir()
            (source / "app.jar").write_bytes(b"jar")
            result = run_s2i_build(source=source, pull_policy="sometimes")
            self.assertEqual(result.returncode, 1)
            self.assertIn("pull_policy must be always, if-not-present, or never", result.stderr)


if __name__ == "__main__":
    unittest.main()
