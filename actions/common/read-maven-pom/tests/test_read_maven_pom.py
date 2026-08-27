"""
FILE_NAME: test_read_maven_pom.py
DESCRIPTION: Unit tests for read-maven-pom/read_maven_pom.py.
VERSION: 1.2.0
AUTHORS: DevOps Team
"""

from __future__ import annotations

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "read_maven_pom.py"
sys.path.insert(0, str(ROOT))
from read_maven_pom import read_pom  # noqa: E402

NS_POM = """<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0">
  <groupId>com.example</groupId>
  <artifactId>demo-app</artifactId>
  <version>1.2.3-SNAPSHOT</version>
  <packaging>war</packaging>
</project>
"""

PARENT_POM = """<?xml version="1.0" encoding="UTF-8"?>
<project>
  <parent>
    <groupId>com.example.parent</groupId>
    <artifactId>company-parent</artifactId>
    <version>2.4.0</version>
  </parent>
  <artifactId>child-svc</artifactId>
  <version>1.0.0-SNAPSHOT</version>
</project>
"""

CHILD_WITHOUT_VERSION = """<?xml version="1.0" encoding="UTF-8"?>
<project>
  <parent>
    <groupId>com.example.parent</groupId>
    <artifactId>company-parent</artifactId>
    <version>2.4.0</version>
  </parent>
  <artifactId>child-svc</artifactId>
</project>
"""

MINIMAL_POM = """<?xml version="1.0" encoding="UTF-8"?>
<project>
  <groupId>com.example</groupId>
  <artifactId>bare-jar</artifactId>
  <version>1.0.0</version>
</project>
"""

MULTI_MODULE_POM = """<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0">
  <groupId>com.example</groupId>
  <artifactId>demo-parent</artifactId>
  <version>1.0.0-SNAPSHOT</version>
  <packaging>pom</packaging>
  <modules>
    <module>api</module>
    <module>svc</module>
  </modules>
</project>
"""

POM_PACKAGING_NO_MODULES = """<?xml version="1.0" encoding="UTF-8"?>
<project>
  <groupId>com.example</groupId>
  <artifactId>bom</artifactId>
  <version>1.0.0</version>
  <packaging>pom</packaging>
</project>
"""


def run_cli(*, working_directory: Path, pom: str = "pom.xml") -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [
            sys.executable,
            "-u",
            str(SCRIPT),
            "--working-directory",
            str(working_directory),
            "--pom",
            pom,
        ],
        capture_output=True,
        text=True,
        check=False,
    )


class ReadMavenPomTests(unittest.TestCase):
    def test_reads_namespaced_coordinates(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "pom.xml"
            path.write_text(NS_POM, encoding="utf-8")
            coords = read_pom(path)
            self.assertEqual(coords["group_id"], "com.example")
            self.assertEqual(coords["artifact_id"], "demo-app")
            self.assertEqual(coords["packaging"], "war")
            self.assertEqual(coords["version"], "1.2.3")
            self.assertEqual(coords["is_multi_module"], "false")

    def test_uses_project_version_not_parent(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "pom.xml"
            path.write_text(PARENT_POM, encoding="utf-8")
            coords = read_pom(path)
            self.assertEqual(coords["group_id"], "com.example.parent")
            self.assertEqual(coords["artifact_id"], "child-svc")
            self.assertEqual(coords["packaging"], "jar")
            self.assertEqual(coords["version"], "1.0.0")

    def test_missing_project_version_does_not_use_parent(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "pom.xml"
            path.write_text(CHILD_WITHOUT_VERSION, encoding="utf-8")
            result = run_cli(working_directory=Path(tmp))
            self.assertEqual(result.returncode, 1)
            self.assertIn("version", result.stderr)

    def test_defaults_packaging_to_jar(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "pom.xml"
            path.write_text(MINIMAL_POM, encoding="utf-8")
            self.assertEqual(read_pom(path)["packaging"], "jar")
            self.assertEqual(read_pom(path)["is_multi_module"], "false")

    def test_detects_multi_module(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "pom.xml"
            path.write_text(MULTI_MODULE_POM, encoding="utf-8")
            coords = read_pom(path)
            self.assertEqual(coords["packaging"], "pom")
            self.assertEqual(coords["version"], "1.0.0")
            self.assertEqual(coords["is_multi_module"], "true")

    def test_pom_packaging_without_modules_is_not_multi_module(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "pom.xml"
            path.write_text(POM_PACKAGING_NO_MODULES, encoding="utf-8")
            self.assertEqual(read_pom(path)["is_multi_module"], "false")

    def test_cli_writes_stdout(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "pom.xml").write_text(MINIMAL_POM, encoding="utf-8")
            result = run_cli(working_directory=root)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("artifact_id : bare-jar", result.stdout)
            self.assertIn("packaging : jar", result.stdout)

    def test_rejects_parent_path_segments(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            result = run_cli(working_directory=Path(tmp), pom="../pom.xml")
            self.assertEqual(result.returncode, 1)
            self.assertIn("relative path", result.stderr)

    def test_missing_artifact_id_fails(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "pom.xml"
            path.write_text(
                "<project><groupId>g</groupId><version>1</version></project>\n",
                encoding="utf-8",
            )
            result = run_cli(working_directory=Path(tmp))
            self.assertEqual(result.returncode, 1)
            self.assertIn("artifactId", result.stderr)


if __name__ == "__main__":
    unittest.main()
