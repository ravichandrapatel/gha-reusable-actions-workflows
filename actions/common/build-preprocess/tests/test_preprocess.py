"""Unit tests for build-preprocess/preprocess.py."""

from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "preprocess.py"
TEMP = Path(__file__).resolve().parents[4] / "temp"

sys.path.insert(0, str(SCRIPT.parent))
from preprocess import branch_approved, build_stages  # noqa: E402


def stages_from_stdout(stdout: str) -> list[str]:
    for line in stdout.splitlines():
        if line.startswith("What is the build stages? : "):
            return json.loads(line.split(" : ", 1)[1])
    raise AssertionError("build_stages output line not found")



def write_dotnet_layout(
    root: Path,
    *,
    project_values: str = "APPLICATION_NAME=ams2-dnc-svc\n",
    build_values: str = "BUILDER_BASE_IMAGE=img\n",
    version: str = "1.0.0",
    sdk_version: str = "8.0.401",
    assembly_name: str = "ams2-dnc-svc",
    sonar_inclusions: str = "",
    sonar_exclusions: str = "",
    product: str = "",
) -> None:
    (root / "project.values").write_text(project_values, encoding="utf-8")
    (root / "build.values").write_text(build_values, encoding="utf-8")
    props_bits = [f"<Version>{version}</Version>"]
    if product:
        props_bits.append(f"<Product>{product}</Product>")
    if sonar_inclusions:
        props_bits.append(f"<sonar.inclusions>{sonar_inclusions}</sonar.inclusions>")
    if sonar_exclusions:
        props_bits.append(f"<sonar.exclusions>{sonar_exclusions}</sonar.exclusions>")
    (root / "Directory.Build.props").write_text(
        "<Project>\n  <PropertyGroup>\n    "
        + "\n    ".join(props_bits)
        + "\n  </PropertyGroup>\n</Project>\n",
        encoding="utf-8",
    )
    (root / "global.json").write_text(
        json.dumps({"sdk": {"version": sdk_version}}) + "\n",
        encoding="utf-8",
    )
    (root / "build").mkdir(exist_ok=True)
    (root / "build" / "Build.csproj").write_text(
        f"""<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <AssemblyName>{assembly_name}</AssemblyName>
  </PropertyGroup>
</Project>
""",
        encoding="utf-8",
    )


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
        self.assertIn("What is the application version? : 2.7.18", result.stdout)
        self.assertIn("snapshot_artifact", stages_from_stdout(result.stdout))
        self.assertIn("docker", stages_from_stdout(result.stdout))
        self.assertIn("sonar.exclusions=***/target/**", result.stdout)

    def test_develop_push_includes_docker(self) -> None:
        result = run_preprocess(
            TEMP / "coo-ams-aim2-dnc-svc",
            event="push",
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("docker", stages_from_stdout(result.stdout))

    def test_develop_defaults_event_to_push_when_unset(self) -> None:
        """Local CLI without --event should behave like push (docker on)."""
        result = run_preprocess(
            TEMP / "coo-ams-aim2-dnc-svc",
            event="",
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("What is the event? : push", result.stdout)
        self.assertIn("docker", stages_from_stdout(result.stdout))

    def test_pull_request_skips_docker(self) -> None:
        result = run_preprocess(
            TEMP / "coo-ams-aim2-dnc-svc",
            event="pull_request",
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("docker", stages_from_stdout(result.stdout))

    def test_temp_dotnet_develop_snapshot(self) -> None:
        result = run_preprocess(
            TEMP / "coo-ams-aim2-dnc-svc",
            app_build_type="dotnet",
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("What is the application version? : 2.1.0", result.stdout)
        self.assertIn("What is the dotnet version? : 8.0.401", result.stdout)
        self.assertIn("-Dsonar.inclusions=**/*.cs", result.stdout)

    def test_ng_ui_version_from_package_json_when_no_components(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "project.values").write_text("APPLICATION_NAME=ng-ui\n", encoding="utf-8")
            (root / "build.values").write_text("BUILDER_BASE_IMAGE=img\n", encoding="utf-8")
            (root / "package.json").write_text(
                json.dumps(
                    {
                        "version": "2.4.1",
                        "engines": {"node": "20"},
                        "dependencies": {"@angular/core": "^12.0.0"},
                    }
                ),
                encoding="utf-8",
            )
            result = run_preprocess(root, app_build_type="ng-ui")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("What is the application version? : 2.4.1", result.stdout)
        self.assertIn("What is the project version? : 2.4.1", result.stdout)

    def test_ng_ui_strips_caret_from_components_version(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "project.values").write_text("APPLICATION_NAME=ng-ui\n", encoding="utf-8")
            (root / "build.values").write_text("BUILDER_BASE_IMAGE=img\n", encoding="utf-8")
            (root / "package.json").write_text(
                json.dumps(
                    {
                        "version": "1.0.0",
                        "engines": {"node": "20"},
                        "dependencies": {"@test/components": "^18.0.0"},
                    }
                ),
                encoding="utf-8",
            )
            result = run_preprocess(root, app_build_type="ng-ui")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("What is the application version? : 18.0.0", result.stdout)
        self.assertIn("What is the parent version? : 18.0.0", result.stdout)
        self.assertNotIn("^18.0.0", result.stdout)

    def test_temp_ng_ui_version_from_components(self) -> None:
        result = run_preprocess(
            TEMP / "corp-otccustmgt-aaf-ng-ui",
            app_build_type="ng-ui",
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("What is the application version? : 18.0.0", result.stdout)
        self.assertIn("What is the parent version? : 18.0.0", result.stdout)
        self.assertIn("What is the project version? : 1.0.0", result.stdout)
        self.assertIn("What is the node version? : >=18.20.0 <22.0.0", result.stdout)

    def test_ng_ui_main_push_includes_release_artifact(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "project.values").write_text(
                "TEMPLATE=build-ng-ui\nAPPLICATION_NAME=ng-ui\n",
                encoding="utf-8",
            )
            (root / "build.values").write_text("BUILDER_BASE_IMAGE=img\n", encoding="utf-8")
            (root / "package.json").write_text(
                json.dumps({"version": "1.0.0", "engines": {"node": "20"}}),
                encoding="utf-8",
            )
            result = run_preprocess(
                root,
                app_build_type="ng-ui",
                branch="main",
                event="push",
            )
        self.assertEqual(result.returncode, 0, result.stderr)
        stages = stages_from_stdout(result.stdout)
        self.assertIn("release_artifact", stages)
        self.assertIn("docker", stages)
        self.assertNotIn("snapshot_artifact", stages)

    def test_maven_main_push_skips_release_artifact(self) -> None:
        result = run_preprocess(
            TEMP / "ccmo-shippingtools-snapshipadmin-jsb-ui",
            app_build_type="maven",
            branch="main",
            event="push",
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("release_artifact", stages_from_stdout(result.stdout))

    def test_ng_ui_node_version_from_nvmrc(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "project.values").write_text("APPLICATION_NAME=ng-ui\n", encoding="utf-8")
            (root / "build.values").write_text("BUILDER_BASE_IMAGE=img\n", encoding="utf-8")
            (root / ".nvmrc").write_text("20.11.1\n", encoding="utf-8")
            (root / "package.json").write_text(
                json.dumps(
                    {
                        "dependencies": {"@test/components": "1.0.0"},
                        "engines": {"node": ">=18.0.0"},
                    }
                ),
                encoding="utf-8",
            )
            result = run_preprocess(root, app_build_type="ng-ui")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("What is the node version? : 20.11.1", result.stdout)

    def test_dotnet_version_from_global_json(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            write_dotnet_layout(root, sdk_version="8.0.401", version="1.0.0")
            result = run_preprocess(root, app_build_type="dotnet")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("What is the dotnet version? : 8.0.401", result.stdout)

    def test_dotnet_uses_build_csproj_ignoring_other_projects(self) -> None:
        """Fixed layout: always build/Build.csproj; APPLICATION_NAME does not select."""
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            write_dotnet_layout(
                root,
                project_values=(
                    "APPLICATION_NAME=does-not-match-any-csproj\n"
                    "TEMPLATE=build-dotnet-core-v1.0\n"
                ),
                version="2.1.0",
                sdk_version="8.0.401",
                assembly_name="ams2-dnc-svc",
            )
            other = root / "ams2-dnc-svc"
            other.mkdir()
            (other / "ams2-dnc-svc.csproj").write_text(
                """<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <AssemblyName>ignored</AssemblyName>
  </PropertyGroup>
</Project>
""",
                encoding="utf-8",
            )
            result = run_preprocess(root, app_build_type="dotnet")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("What is the application version? : 2.1.0", result.stdout)
        self.assertIn("What is the parent version? : 2.1.0", result.stdout)
        self.assertIn("What is the dotnet version? : 8.0.401", result.stdout)

    def test_dotnet_requires_build_csproj(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "project.values").write_text("APPLICATION_NAME=svc\n", encoding="utf-8")
            (root / "build.values").write_text("BUILDER_BASE_IMAGE=img\n", encoding="utf-8")
            (root / "Directory.Build.props").write_text(
                "<Project><PropertyGroup><Version>1.0.0</Version></PropertyGroup></Project>\n",
                encoding="utf-8",
            )
            (root / "global.json").write_text(
                '{"sdk": {"version": "8.0.401"}}\n',
                encoding="utf-8",
            )
            result = run_preprocess(root, app_build_type="dotnet")
        self.assertEqual(result.returncode, 1)
        self.assertIn("build/Build.csproj", result.stderr)

    def test_dotnet_accepts_lowercase_build_csproj(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            write_dotnet_layout(root, version="9.9.9", sdk_version="8.0.100", assembly_name="build")
            # Rename to lowercase to exercise case-insensitive fallback
            (root / "build" / "Build.csproj").rename(root / "build" / "build.csproj")
            result = run_preprocess(root, app_build_type="dotnet")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("What is the application version? : 9.9.9", result.stdout)
        self.assertIn("What is the dotnet version? : 8.0.100", result.stdout)

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
        stages = stages_from_stdout(result.stdout)
        self.assertIn("release_artifact", stages)
        self.assertIn("docker", stages)

    def test_release_push_includes_release_artifact_and_docker(self) -> None:
        result = run_preprocess(
            TEMP / "coo-ams-aim2-dnc-svc",
            branch="release/1.0",
            event="push",
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        stages = stages_from_stdout(result.stdout)
        self.assertIn("release_artifact", stages)
        self.assertIn("docker", stages)
        self.assertIn("build_and_unit_test", stages)

    def test_pull_request_skips_snapshot(self) -> None:
        result = run_preprocess(
            TEMP / "coo-ams-aim2-dnc-svc",
            event="pull_request",
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("snapshot_artifact", stages_from_stdout(result.stdout))

    def test_auto_commit_skips_stages(self) -> None:
        result = run_preprocess(
            TEMP / "coo-ams-aim2-dnc-svc",
            actor="bot",
            bot_name="bot",
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("What is the auto commit? : true", result.stdout)
        stages = stages_from_stdout(result.stdout)
        self.assertNotIn("build_and_unit_test", stages)
        self.assertNotIn("owasp", stages)
        self.assertNotIn("sonar", stages)
        self.assertEqual(stages, [])

    def test_auto_detect_github_actions_bot_without_bot_name(self) -> None:
        result = run_preprocess(
            TEMP / "coo-ams-aim2-dnc-svc",
            actor="github-actions[bot]",
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("What is the auto commit? : true", result.stdout)

    def test_library_skips_docker(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            write_dotnet_layout(
                root,
                project_values="APPLICATION_NAME=lib-app\nORGANIZATION=test\n",
                assembly_name="lib-app",
            )
            result = run_preprocess(
                root,
                branch="release/1.0",
                event="workflow_dispatch",
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("What is the is library? : y", result.stdout)
            self.assertNotIn("docker", stages_from_stdout(result.stdout))
            self.assertIn("release_artifact", stages_from_stdout(result.stdout))

    def _write_maven_lib(
        self,
        root: Path,
        *,
        project_values: str,
    ) -> None:
        (root / "project.values").write_text(project_values, encoding="utf-8")
        (root / "build.values").write_text("BUILDER_BASE_IMAGE=img\n", encoding="utf-8")
        (root / "pom.xml").write_text(
            """<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0">
  <modelVersion>4.0.0</modelVersion>
  <groupId>com.example</groupId>
  <artifactId>demo-lib</artifactId>
  <version>1.0.0</version>
  <packaging>jar</packaging>
  <name>Demo Lib</name>
  <properties>
    <java.version>21</java.version>
  </properties>
</project>
""",
            encoding="utf-8",
        )

    def test_maven_library_skips_docker(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            self._write_maven_lib(
                root,
                project_values="APPLICATION_NAME=demo-lib\n",
            )
            result = run_preprocess(root, app_build_type="maven")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("What is the is library? : y", result.stdout)
        self.assertNotIn("docker", stages_from_stdout(result.stdout))

    def test_build_values_overrides_sonar(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            write_dotnet_layout(
                root,
                project_values=(
                    "APPLICATION_NAME=ams2-dnc-svc\nTEMPLATE=build-dotnet-core-v1.0\n"
                ),
                build_values=(
                    "BUILDER_BASE_IMAGE=img\n"
                    "CPGBUILD_SONAR_INCLUSION_LIST=src/**\n"
                    "CPGBUILD_SONAR_EXCLUSION_LIST=**/tests/**\n"
                ),
                sonar_inclusions="**/*.cs",
                sonar_exclusions="**/bin/**,**/obj/**",
            )
            result = run_preprocess(root, app_build_type="dotnet")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("-Dsonar.inclusions=src/**", result.stdout)
            self.assertIn("-Dsonar.exclusions=**/tests/**", result.stdout)

    def test_github_output_file(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            write_dotnet_layout(root, version="2.1.0")
            out_file = root / "github-output.txt"
            result = run_preprocess(root, app_build_type="dotnet", output=out_file)
            self.assertEqual(result.returncode, 0, result.stderr)
            content = out_file.read_text(encoding="utf-8")
            self.assertIn("branch=develop\n", content)
            self.assertIn("approved=true\n", content)
            self.assertIn("application_version=2.1.0\n", content)
            self.assertIn("checkstyle_skip=false\n", content)
            self.assertIn("lib_01=\n", content)
            self.assertIn("lib_02=\n", content)
            self.assertIn("lib_03=\n", content)

    def test_optional_libs_from_build_values(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            write_dotnet_layout(
                root,
                build_values=(
                    "BUILDER_BASE_IMAGE=img\n"
                    "LIB_01=https://lib1.example\n"
                    "#LIB_02=https://commented.example\n"
                    "LIB_03=https://lib3.example\n"
                ),
            )
            result = run_preprocess(root, app_build_type="dotnet")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("What is the lib 01? : https://lib1.example", result.stdout)
        self.assertIn("What is the lib 02? : \n", result.stdout)
        self.assertIn("What is the lib 03? : https://lib3.example", result.stdout)

    def test_checkstyle_skip_true_when_app_origin_set(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            write_dotnet_layout(
                root,
                build_values="BUILDER_BASE_IMAGE=img\nCPGBUILD_APP_ORIGIN=https://origin.example\n",
            )
            result = run_preprocess(root, app_build_type="dotnet")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("What is the cpgbuild app origin? : https://origin.example", result.stdout)
        self.assertIn("What is the checkstyle skip? : true", result.stdout)

    def test_checkstyle_skip_accepts_cpgbuild_apporigin_alias(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            write_dotnet_layout(
                root,
                build_values="BUILDER_BASE_IMAGE=img\nCPGBUILD_APPORIGIN=legacy-origin\n",
            )
            result = run_preprocess(root, app_build_type="dotnet")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("What is the cpgbuild app origin? : legacy-origin", result.stdout)
        self.assertIn("What is the checkstyle skip? : true", result.stdout)

    def test_normalize_refs_heads_for_snapshot_and_ng_ui_release(self) -> None:
        develop = build_stages(
            auto_commit=False,
            branch="refs/heads/develop",
            event="push",
            is_library="n",
            app_build_type="maven",
        )
        self.assertIn("snapshot_artifact", develop)
        self.assertIn("docker", develop)

        ng_main = build_stages(
            auto_commit=False,
            branch="refs/heads/main",
            event="push",
            is_library="n",
            app_build_type="ng-ui",
        )
        self.assertIn("release_artifact", ng_main)
        self.assertIn("docker", ng_main)

        spaced = build_stages(
            auto_commit=False,
            branch=" develop ",
            event="push",
            is_library="n",
            app_build_type="maven",
        )
        self.assertIn("snapshot_artifact", spaced)

    def test_casefold_well_known_branches(self) -> None:
        stages = build_stages(
            auto_commit=False,
            branch="Main",
            event="push",
            is_library="n",
            app_build_type="ng-ui",
        )
        self.assertIn("release_artifact", stages)
        self.assertTrue(branch_approved("MAIN"))
        self.assertTrue(branch_approved("Develop"))

    def test_is_library_casefold_skips_docker(self) -> None:
        stages = build_stages(
            auto_commit=False,
            branch="main",
            event="push",
            is_library="Y",
            app_build_type="maven",
        )
        self.assertNotIn("docker", stages)

    def test_bare_release_hotfix_not_approved(self) -> None:
        self.assertFalse(branch_approved("release"))
        self.assertFalse(branch_approved("hotfix"))
        self.assertFalse(branch_approved("feature"))
        self.assertTrue(branch_approved("release/1.0"))
        self.assertTrue(branch_approved("hotfix/x"))
        bare = build_stages(
            auto_commit=False,
            branch="release",
            event="push",
            is_library="n",
            app_build_type="maven",
        )
        self.assertNotIn("release_artifact", bare)


if __name__ == "__main__":
    unittest.main()
