"""Unit tests for build-preprocess/preprocess.py."""

from __future__ import annotations

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "preprocess.py"
TEMP = Path(__file__).resolve().parents[4] / "temp"


def run_preprocess(
    workspace: Path,
    *,
    branch: str = "develop",
    app_build_type: str = "dotnet",
    event: str = "push",
    actor: str = "",
    bot_name: str = "",
    output: Path | None = None,
) -> subprocess.CompletedProcess[str]:
    cmd = [
        sys.executable,
        str(SCRIPT),
        "--branch",
        branch,
        "--app-build-type",
        app_build_type,
        "--event",
        event,
    ]
    if actor:
        cmd.extend(["--actor", actor])
    if bot_name:
        cmd.extend(["--bot-name", bot_name])
    if output is not None:
        cmd.extend(["--output", str(output)])
    env = {"GITHUB_WORKSPACE": str(workspace)}
    return subprocess.run(cmd, capture_output=True, text=True, env=env, check=False)


class PreprocessTests(unittest.TestCase):
    def test_temp_maven_develop_snapshot(self) -> None:
        result = run_preprocess(
            TEMP / "ccmo-shippingtools-snapshipadmin-jsb-ui",
            app_build_type="maven",
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("application version? : 2.7.18", result.stdout)
        self.assertIn("Should a snapshot artifact be published? : true", result.stdout)
        self.assertIn("sonar.exclusions=***/target/**", result.stdout)

    def test_temp_dotnet_develop_snapshot(self) -> None:
        result = run_preprocess(
            TEMP / "coo-ams-aim2-dnc-svc",
            app_build_type="dotnet",
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("application version? : 2.1.0", result.stdout)
        self.assertIn("java version? : net8.0", result.stdout.lower())
        self.assertIn("-Dsonar.inclusions=**/*.cs", result.stdout)

    def test_temp_ng_ui_version_from_components(self) -> None:
        result = run_preprocess(
            TEMP / "corp-otccustmgt-aaf-ng-ui",
            app_build_type="ng-ui",
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("application version? : 18.0.0", result.stdout)

    def test_unapproved_branch_fails(self) -> None:
        result = run_preprocess(TEMP / "coo-ams-aim2-dnc-svc", branch="not-allowed")
        self.assertEqual(result.returncode, 1)
        self.assertIn("not on the approved allowlist", result.stderr)

    def test_release_manual_includes_docker(self) -> None:
        result = run_preprocess(
            TEMP / "coo-ams-aim2-dnc-svc",
            branch="release/1.0",
            event="workflow_dispatch",
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("release_artifact,docker", result.stdout)
        self.assertIn("Should the Docker stage run? : true", result.stdout)

    def test_pull_request_skips_snapshot(self) -> None:
        result = run_preprocess(
            TEMP / "coo-ams-aim2-dnc-svc",
            event="pull_request",
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Should a snapshot artifact be published? : false", result.stdout)

    def test_auto_commit_skips_stages(self) -> None:
        result = run_preprocess(
            TEMP / "coo-ams-aim2-dnc-svc",
            actor="bot",
            bot_name="bot",
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Is this an auto-commit run? : true", result.stdout)
        self.assertIn("Which build stages should run? : \n", result.stdout)

    def test_auto_detect_github_actions_bot_without_bot_name(self) -> None:
        result = run_preprocess(
            TEMP / "coo-ams-aim2-dnc-svc",
            actor="github-actions[bot]",
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Is this an auto-commit run? : true", result.stdout)

    def test_library_skips_docker(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "project.values").write_text(
                "APPLICATION_NAME=lib-app\nORGANIZATION=test\n",
                encoding="utf-8",
            )
            (root / "build.values").write_text("BUILDER_BASE_IMAGE=img\n", encoding="utf-8")
            (root / "lib-app.csproj").write_text(
                """<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <AssemblyName>lib-app</AssemblyName>
    <Version>1.0.0</Version>
  </PropertyGroup>
</Project>
""",
                encoding="utf-8",
            )
            result = run_preprocess(
                root,
                branch="release/1.0",
                event="workflow_dispatch",
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("Is this a library project? : y", result.stdout)
            self.assertIn("Should the Docker stage run? : false", result.stdout)
            self.assertIn("Should a release artifact be published? : true", result.stdout)

    def test_build_values_overrides_sonar(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "project.values").write_text(
                "APPLICATION_NAME=ams2-dnc-svc\nTEMPLATE=build-dotnet-core-v1.0\n",
                encoding="utf-8",
            )
            (root / "build.values").write_text(
                "BUILDER_BASE_IMAGE=img\n"
                "CPGBUILD_SONAR_INCLUSION_LIST=src/**\n"
                "CPGBUILD_SONAR_EXCLUSION_LIST=**/tests/**\n",
                encoding="utf-8",
            )
            (root / "ams2-dnc-svc.csproj").write_text(
                (TEMP / "coo-ams-aim2-dnc-svc" / "ams2-dnc-svc.csproj").read_text(
                    encoding="utf-8"
                ),
                encoding="utf-8",
            )
            result = run_preprocess(root, app_build_type="dotnet")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("-Dsonar.inclusions=src/**", result.stdout)
            self.assertIn("-Dsonar.exclusions=**/tests/**", result.stdout)

    def test_github_output_file(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "project.values").write_text("APPLICATION_NAME=ams2-dnc-svc\n", encoding="utf-8")
            (root / "build.values").write_text("BUILDER_BASE_IMAGE=img\n", encoding="utf-8")
            (root / "ams2-dnc-svc.csproj").write_text(
                (TEMP / "coo-ams-aim2-dnc-svc" / "ams2-dnc-svc.csproj").read_text(
                    encoding="utf-8"
                ),
                encoding="utf-8",
            )
            out_file = root / "github-output.txt"
            result = run_preprocess(root, app_build_type="dotnet", output=out_file)
            self.assertEqual(result.returncode, 0, result.stderr)
            content = out_file.read_text(encoding="utf-8")
            self.assertIn("branch=develop\n", content)
            self.assertIn("approved=true\n", content)
            self.assertIn("application_version=2.1.0\n", content)


if __name__ == "__main__":
    unittest.main()
