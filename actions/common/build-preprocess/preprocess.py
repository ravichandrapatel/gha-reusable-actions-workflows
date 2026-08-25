"""
FILE_NAME: preprocess.py
DESCRIPTION: Branch allowlist, stages, values files, and maven/ng-ui/dotnet metadata.
VERSION: 2.5.0
AUTHORS: DevOps Team
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

PROJECT_KEY = "BUILD-PREPROCESS"

ALLOWED_BRANCHES = (
    "main",
    "master",
    "develop",
    "feature/**",
    "release/**",
    "hotfix/**",
    "bugfix/**",
)

BUILD_STAGES = [
    "build_and_unit_test",
    "owasp",
    "sonar",
    "docker",
]

APP_BUILD_TYPES = ["maven", "ng-ui", "dotnet"]

OUTPUT_LABELS = {
    "branch": "What is the branch name?",
    "approved": "Is the branch approved?",
    "event": "What is the GitHub event?",
    "actor": "Who triggered the workflow?",
    "bot_name": "What is the auto-commit bot name?",
    "auto_commit": "Is this an auto-commit run?",
    "snapshot_artifact": "Should a snapshot artifact be published?",
    "release_artifact": "Should a release artifact be published?",
    "docker": "Should the Docker stage run?",
    "stages": "Which build stages should run?",
    "app_build_type": "What is the app build type?",
    "application_version": "What is the application version?",
    "parent_version": "What is the parent version?",
    "project_version": "What is the project version?",
    "artifact_id": "What is the artifact ID?",
    "name": "What is the project name?",
    "java_version": "What is the Java version?",
    "node_version": "What is the Node.js version?",
    "dotnet_version": "What is the .NET version?",
    "cpgbuild_app_origin": "What is the CPGBUILD app origin?",
    "checks_type_skip": "Should checks type be skipped?",
    "is_library": "Is this a library project?",
    "sonar_inclusions": "What are the Sonar inclusion arguments?",
    "sonar_exclusions": "What are the Sonar exclusion arguments?",
    "sonar_cli_args": "What are the Sonar CLI arguments?",
}


def _log_error(message: str) -> None:
    print(f"[{PROJECT_KEY}] {message}", file=sys.stderr)


def _bool_str(value: bool) -> str:
    return "true" if value else "false"


def _tag_name(element: ET.Element) -> str:
    return element.tag.rsplit("}", 1)[-1]


def xml_child(el: ET.Element | None, name: str) -> ET.Element | None:
    if el is None:
        return None
    for child in el:
        if _tag_name(child) == name:
            return child
    return None


def xml_text(el: ET.Element | None) -> str:
    if el is None or el.text is None:
        return ""
    return el.text.strip()


def xml_property(root: ET.Element, name: str) -> str:
    """Prefer MSBuild PropertyGroup values over nested matches elsewhere in the tree."""
    for el in root.iter():
        if _tag_name(el) != "PropertyGroup":
            continue
        value = xml_text(xml_child(el, name))
        if value:
            return value
    for el in root.iter():
        if _tag_name(el) == name and el.text:
            return el.text.strip()
    return ""


def _parse_xml(path: Path) -> ET.Element:
    try:
        return ET.parse(path).getroot()
    except OSError as exc:
        _log_error(str(exc))
        raise
    except ET.ParseError as exc:
        _log_error(f"could not parse {path}: {exc}")
        raise


def _parse_json_object(path: Path, label: str) -> dict:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except OSError as exc:
        _log_error(str(exc))
        raise
    except json.JSONDecodeError as exc:
        _log_error(f"could not parse {path}: {exc}")
        raise
    if not isinstance(data, dict):
        _log_error(f"{label} must be a JSON object")
        raise ValueError(f"invalid {label}")
    return data


def load_values(path: Path) -> dict[str, str]:
    data: dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        if key:
            data[key] = value.strip()
    return data


def branch_approved(branch: str, pattern: str | None = None) -> bool:
    ref = branch.removeprefix("refs/heads/").strip()
    patterns = (pattern,) if pattern is not None else ALLOWED_BRANCHES
    for pat in patterns:
        if pat.endswith("/**"):
            prefix = pat[:-3]
            if ref == prefix or ref.startswith(prefix + "/"):
                return True
        elif ref == pat:
            return True
    return False


def resolve_branch(raw_branch: str) -> str:
    return (
        raw_branch.strip()
        or os.environ.get("GITHUB_HEAD_REF", "").strip()
        or os.environ.get("GITHUB_REF_NAME", "").strip()
    ).removeprefix("refs/heads/").strip()


def load_project_files(repo_root: Path) -> tuple[dict[str, str], dict[str, str]]:
    project_file = repo_root / "project.values"
    build_file = repo_root / "build.values"
    if not project_file.is_file():
        _log_error(f"missing {project_file}")
        raise FileNotFoundError(str(project_file))
    if not build_file.is_file():
        _log_error(f"missing {build_file}")
        raise FileNotFoundError(str(build_file))
    return load_values(project_file), load_values(build_file)


def is_library_from_template(project_values: dict[str, str]) -> str:
    # TEMPLATE set => generated deployable app (not a shared library).
    return "n" if project_values.get("TEMPLATE", "").strip() else "y"


def load_maven_metadata(repo_root: Path, project_values: dict[str, str]) -> dict[str, str]:
    pom_path = repo_root / "pom.xml"
    if not pom_path.is_file():
        _log_error(f"missing {pom_path}")
        raise FileNotFoundError(str(pom_path))

    root = _parse_xml(pom_path)
    parent_el = xml_child(root, "parent")
    parent_version_el = xml_child(parent_el, "version") if parent_el is not None else None
    parent_version = xml_text(parent_version_el)
    project_version = xml_text(xml_child(root, "version"))
    # Parent POM owns the release version when a parent block is declared.
    application_version = parent_version if parent_version_el is not None else project_version
    properties_el = xml_child(root, "properties")
    java_version = xml_text(xml_child(properties_el, "java.version"))
    artifact_id = xml_text(xml_child(root, "artifactId"))

    if not application_version or not artifact_id or not java_version:
        _log_error("pom.xml must have version, artifactId, and properties/java.version")
        raise ValueError("invalid pom.xml")

    return {
        "application_version": application_version,
        "parent_version": parent_version,
        "project_version": project_version,
        "artifact_id": artifact_id,
        "name": xml_text(xml_child(root, "name")),
        "java_version": java_version,
        "sonar_inclusions": xml_text(xml_child(properties_el, "sonar.inclusions")),
        "sonar_exclusions": xml_text(xml_child(properties_el, "sonar.exclusions")),
        "is_library": is_library_from_template(project_values),
    }


def find_csproj(repo_root: Path, application_name: str) -> Path:
    # Root *.csproj first keeps monorepos with a single top-level project fast and unambiguous.
    candidates = sorted(repo_root.glob("*.csproj")) or sorted(repo_root.rglob("*.csproj"))
    if not candidates:
        _log_error(f"missing *.csproj under {repo_root}")
        raise FileNotFoundError(str(repo_root / "*.csproj"))

    if application_name:
        for path in candidates:
            if path.stem == application_name:
                return path
    if len(candidates) == 1:
        return candidates[0]

    _log_error(
        "multiple csproj files found; set APPLICATION_NAME in project.values "
        "to match the project filename"
    )
    raise ValueError("ambiguous csproj")


def load_dotnet_metadata(repo_root: Path, project_values: dict[str, str]) -> dict[str, str]:
    csproj_path = find_csproj(repo_root, project_values.get("APPLICATION_NAME", "").strip())
    root = _parse_xml(csproj_path)

    parent_version = ""
    props_path = repo_root / "Directory.Build.props"
    props_root = _parse_xml(props_path) if props_path.is_file() else None
    if props_root is not None:
        parent_version = xml_property(props_root, "Version")

    target_framework = xml_property(root, "TargetFramework")
    if not target_framework:
        target_frameworks = xml_property(root, "TargetFrameworks")
        if target_frameworks:
            target_framework = target_frameworks.split(";")[0].strip()

    dotnet_version = ""
    global_json = repo_root / "global.json"
    if global_json.is_file():
        data = _parse_json_object(global_json, "global.json")
        sdk = data.get("sdk")
        if isinstance(sdk, dict):
            dotnet_version = str(sdk.get("version", "")).strip()
    if not dotnet_version:
        dotnet_version = target_framework

    project_version = xml_property(root, "Version")
    application_version = project_version or parent_version
    artifact_id = xml_property(root, "AssemblyName") or csproj_path.stem
    sonar_inclusions = xml_property(root, "sonar.inclusions")
    sonar_exclusions = xml_property(root, "sonar.exclusions")
    if props_root is not None:
        if not sonar_inclusions:
            sonar_inclusions = xml_property(props_root, "sonar.inclusions")
        if not sonar_exclusions:
            sonar_exclusions = xml_property(props_root, "sonar.exclusions")

    if not application_version or not artifact_id or not dotnet_version:
        _log_error(
            f"{csproj_path.name} must have Version, AssemblyName or filename, and "
            "TargetFramework/TargetFrameworks or global.json sdk.version"
        )
        raise ValueError("invalid csproj")

    return {
        "application_version": application_version,
        "parent_version": parent_version,
        "project_version": project_version,
        "artifact_id": artifact_id,
        "name": xml_property(root, "Product"),
        "dotnet_version": dotnet_version,
        "sonar_inclusions": sonar_inclusions,
        "sonar_exclusions": sonar_exclusions,
        "is_library": is_library_from_template(project_values),
    }


def _read_node_version_file(repo_root: Path) -> str:
    # Pin file wins over package.json engines.node when both exist.
    for filename in (".nvmrc", ".node-version"):
        version_file = repo_root / filename
        if not version_file.is_file():
            continue
        for line in version_file.read_text(encoding="utf-8").splitlines():
            candidate = line.strip()
            if candidate and not candidate.startswith("#"):
                return candidate.removeprefix("v")
    return ""


def load_ng_ui_metadata(repo_root: Path) -> dict[str, str]:
    node_version = _read_node_version_file(repo_root)
    pkg_path = repo_root / "package.json"
    if not pkg_path.is_file():
        _log_error(f"missing {pkg_path}")
        raise FileNotFoundError(str(pkg_path))

    pkg = _parse_json_object(pkg_path, "package.json")

    if not node_version:
        engines = pkg.get("engines")
        if isinstance(engines, dict):
            node_version = str(engines.get("node", "")).strip().removeprefix("v")
    if not node_version:
        _log_error(
            "package.json must define engines.node or the repo must provide .nvmrc / .node-version"
        )
        raise ValueError("missing node version")

    dependencies = pkg.get("dependencies")
    deps = dependencies if isinstance(dependencies, dict) else {}
    has_components = "@test/components" in deps
    components_version = str(deps.get("@test/components", "")).strip() if has_components else ""
    project_version = str(pkg.get("version", "")).strip()
    # Same rule as Maven: shared @test/components line owns the version when declared.
    application_version = components_version if has_components else project_version

    if not application_version:
        _log_error(
            "package.json must define version, or dependencies.@test/components when that dependency is declared"
        )
        raise ValueError("missing application version")

    return {
        "application_version": application_version,
        "parent_version": components_version,
        "project_version": project_version,
        "node_version": node_version,
    }


def load_project_metadata(
    app_build_type: str,
    repo_root: Path,
    project_values: dict[str, str],
) -> dict[str, str]:
    if app_build_type == "maven":
        return load_maven_metadata(repo_root, project_values)
    if app_build_type == "dotnet":
        return load_dotnet_metadata(repo_root, project_values)
    if app_build_type == "ng-ui":
        return load_ng_ui_metadata(repo_root)
    raise ValueError(f"unsupported app build type: {app_build_type}")


def resolve_auto_commit(actor: str, bot_name: str) -> tuple[str, bool]:
    actor = actor.strip()
    explicit = bot_name.strip()
    if explicit:
        return explicit, actor == explicit
    if actor.endswith("[bot]"):
        return actor, True
    return "", False


def build_stages(
    *,
    auto_commit: bool,
    branch: str,
    is_pr: bool,
    is_manual: bool,
    is_library: str,
    event: str = "",
) -> list[str]:
    """Decide which pipeline stages/tokens to emit.

    ``is_manual`` is true only for ``workflow_dispatch`` (not push).

    Publish tokens:
    - snapshot_artifact: develop, not PR
    - release_artifact: release/* or hotfix/*, on push or workflow_dispatch, not PR
    - docker: push or workflow_dispatch, not PR, not library

    Auto-commit bot runs emit no stages.
    """
    if auto_commit:
        return []

    stages = [stage for stage in BUILD_STAGES if stage != "docker"]
    if branch == "develop" and not is_pr:
        stages.append("snapshot_artifact")  # publish token; not a BUILD_STAGES job name
    # Release publish: push or workflow_dispatch on release/* / hotfix/* (never PR).
    if not is_pr and (is_manual or event == "push") and (
        branch_approved(branch, "release/**") or branch_approved(branch, "hotfix/**")
    ):
        stages.append("release_artifact")
    # Image publish: push or workflow_dispatch; never PR / library.
    if is_library != "y" and not is_pr and (is_manual or event == "push"):
        stages.append("docker")
    return stages


def sonar_cli_args(build_values: dict[str, str], project_meta: dict[str, str]) -> tuple[str, str, str]:
    inclusion = build_values.get("CPGBUILD_SONAR_INCLUSION_LIST", "").strip()
    exclusion = build_values.get("CPGBUILD_SONAR_EXCLUSION_LIST", "").strip()
    if not inclusion:
        inclusion = project_meta.get("sonar_inclusions", "").strip()
    if not exclusion:
        exclusion = project_meta.get("sonar_exclusions", "").strip()
    inclusions = f"-Dsonar.inclusions={inclusion}" if inclusion else ""
    exclusions = f"-Dsonar.exclusions={exclusion}" if exclusion else ""
    cli_args = " ".join(part for part in (inclusions, exclusions) if part)
    return inclusions, exclusions, cli_args


def build_outputs(
    *,
    branch: str,
    event: str,
    actor: str,
    bot_name: str,
    auto_commit: bool,
    stages: list[str],
    app_build_type: str,
    project_meta: dict[str, str],
    build_values: dict[str, str],
    project_values: dict[str, str],
) -> dict[str, str]:
    cpg_origin = build_values.get("CPGBUILD_APP_ORIGIN", "").strip()
    sonar_inclusions, sonar_exclusions, sonar_cli = sonar_cli_args(build_values, project_meta)

    outputs = {
        "branch": branch,
        # Branch gate already passed in main(); downstream workflows expect this flag.
        "approved": "true",
        "event": event,
        "actor": actor,
        "bot_name": bot_name,
        "auto_commit": _bool_str(auto_commit),
        "snapshot_artifact": _bool_str("snapshot_artifact" in stages),
        "release_artifact": _bool_str("release_artifact" in stages),
        "docker": _bool_str("docker" in stages),
        "stages": ",".join(stages),
        "app_build_type": app_build_type,
        "application_version": project_meta.get("application_version", ""),
        "parent_version": project_meta.get("parent_version", ""),
        "project_version": project_meta.get("project_version", ""),
        "artifact_id": project_meta.get("artifact_id", ""),
        "name": project_meta.get("name", ""),
        "java_version": project_meta.get("java_version", ""),
        "node_version": project_meta.get("node_version", ""),
        "dotnet_version": project_meta.get("dotnet_version", ""),
        "cpgbuild_app_origin": cpg_origin,
        "checks_type_skip": _bool_str(bool(cpg_origin)),
        "is_library": project_meta.get("is_library", ""),
        "sonar_inclusions": sonar_inclusions,
        "sonar_exclusions": sonar_exclusions,
        "sonar_cli_args": sonar_cli,
    }

    reserved = set(outputs)
    for src in (project_values, build_values):
        for key, value in src.items():
            out_key = key.lower()
            if out_key not in reserved:
                outputs[out_key] = value
    return outputs


def emit_outputs(outputs: dict[str, str]) -> None:
    for key, value in outputs.items():
        label = OUTPUT_LABELS.get(key, f"What is the {key.replace('_', ' ')}?")
        print(f"{label} : {value}", file=sys.stdout)


def write_github_output(output_path: str, outputs: dict[str, str]) -> None:
    with open(output_path, "a", encoding="utf-8") as fh:
        fh.writelines(f"{key}={value}\n" for key, value in outputs.items())


def main() -> int:
    parser = argparse.ArgumentParser(description="Check branch against approved globs; emit stages")
    parser.add_argument("--branch", default="")
    parser.add_argument("--app-build-type", required=True, choices=APP_BUILD_TYPES)
    parser.add_argument("--event", default="")
    parser.add_argument("--actor", default="")
    parser.add_argument("--bot-name", default="")
    parser.add_argument("--output", default="")
    args = parser.parse_args()

    branch = resolve_branch(args.branch)
    if not branch:
        _log_error("pass --branch or set GITHUB_HEAD_REF / GITHUB_REF_NAME")
        return 1

    if not branch_approved(branch):
        _log_error(f"The branch '{branch}' is not on the approved allowlist")
        return 1

    repo_root = Path(os.environ.get("GITHUB_WORKSPACE", "").strip() or ".").resolve()

    try:
        project_values, build_values = load_project_files(repo_root)
        project_meta = load_project_metadata(args.app_build_type, repo_root, project_values)
    except (OSError, ValueError, FileNotFoundError, ET.ParseError):
        return 1

    event = args.event.strip() or os.environ.get("GITHUB_EVENT_NAME", "").strip()
    actor = args.actor.strip() or os.environ.get("GITHUB_ACTOR", "").strip()
    bot_name, auto_commit = resolve_auto_commit(actor, args.bot_name.strip())

    outputs = build_outputs(
        branch=branch,
        event=event,
        actor=actor,
        bot_name=bot_name,
        auto_commit=auto_commit,
        stages=build_stages(
            auto_commit=auto_commit,
            branch=branch,
            is_pr=event.startswith("pull_request"),
            is_manual=event == "workflow_dispatch",
            is_library=project_meta.get("is_library", ""),
            event=event,
        ),
        app_build_type=args.app_build_type,
        project_meta=project_meta,
        build_values=build_values,
        project_values=project_values,
    )

    emit_outputs(outputs)

    output_path = args.output.strip()
    if output_path:
        write_github_output(output_path, outputs)
    return 0


if __name__ == "__main__":
    sys.exit(main())
