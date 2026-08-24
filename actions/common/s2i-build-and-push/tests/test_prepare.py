"""Unit tests for s2i-build-and-push/prepare.sh."""

from __future__ import annotations

import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "prepare.sh"


def run_prepare(
    *,
    artifact: Path,
    app_build_type: str = "maven",
    source: Path,
    workspace: Path | None = None,
    output: Path | None = None,
) -> subprocess.CompletedProcess[str]:
    cmd = [
        "bash",
        str(SCRIPT),
        "--artifact",
        str(artifact),
        "--app-build-type",
        app_build_type,
        "--source",
        str(source),
    ]
    if workspace is not None:
        cmd.extend(["--workspace", str(workspace)])
    if output is not None:
        cmd.extend(["--output", str(output)])
    return subprocess.run(cmd, capture_output=True, text=True, check=False)


class PrepareTests(unittest.TestCase):
    def test_maven_jar_stages_at_source_root(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            jar = root / "app.jar"
            jar.write_bytes(b"jar")
            source = root / "src"
            output = root / "out"
            result = run_prepare(artifact=jar, source=source, output=output)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertTrue((source / "app.jar").is_file())
            self.assertFalse((source / "Dockerfile").exists())
            text = output.read_text(encoding="utf-8")
            self.assertIn(f"source={source}", text)

    def test_dotnet_directory_copies_contents(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            publish = root / "publish"
            publish.mkdir()
            (publish / "App.dll").write_bytes(b"dll")
            (publish / "App.runtimeconfig.json").write_text("{}", encoding="utf-8")
            source = root / "src"
            result = run_prepare(
                artifact=publish,
                app_build_type="dotnet",
                source=source,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertTrue((source / "App.dll").is_file())
            self.assertTrue((source / "App.runtimeconfig.json").is_file())

    def test_rejects_ng_ui(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            jar = root / "app.jar"
            jar.write_bytes(b"jar")
            result = run_prepare(
                artifact=jar,
                app_build_type="ng-ui",
                source=root / "src",
            )
            self.assertEqual(result.returncode, 1)
            self.assertIn("docker-build-and-push", result.stderr)

    def test_rejects_maven_without_jar(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            payload = root / "payload"
            payload.mkdir()
            (payload / "README.txt").write_text("no jar", encoding="utf-8")
            result = run_prepare(artifact=payload, source=root / "src")
            self.assertEqual(result.returncode, 1)
            self.assertIn("maven artifact must include a .jar or .war", result.stderr)

    def test_rejects_missing_artifact(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            result = run_prepare(artifact=root / "missing.jar", source=root / "src")
            self.assertEqual(result.returncode, 1)
            self.assertIn("artifact not found", result.stderr)


if __name__ == "__main__":
    unittest.main()
