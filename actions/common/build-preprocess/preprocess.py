"""
FILE_NAME: preprocess.py
DESCRIPTION: Branch allowlist, stages, values files, and maven/ng-ui/dotnet metadata.
VERSION: 2.0.0
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

APPROVED_BRANCHES = (
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

APP_BUILD_TYPES = [
    "maven",
    "ng-ui",
    "dotnet",
]


def _log_error(message: str) -> None:
    """Write a prefixed error message to stderr."""
    print(f"[{PROJECT_KEY}] {message}", file=sys.stderr)


def _bool_str(value: bool) -> str:
    """Return GitHub Actions-compatible true/false strings."""
    return "true" if value else "false"


def xml_child(el: ET.Element | None, name: str) -> ET.Element | None:
    """Return the first direct child element matching a local tag name."""
    if el is None:
        return None
    for child in el:
        if child.tag.rsplit("}", 1)[-1] == name:
            return child
    return None


def xml_find(el: ET.Element | None, name: str) -> ET.Element | None:
    """Return the first descendant element matching a local tag name."""
    if el is None:
        return None
    for child in el.iter():
        if child.tag.rsplit("}", 1)[-1] == name:
            return child
    return None


def xml_text(el: ET.Element | None) -> str:
    """Return stripped text from an XML element, or an empty string."""
    if el is None or el.text is None:
        return ""
    return el.text.strip()


def load_values(path: Path) -> dict[str, str]:
    """Parse a key=value values file into a dictionary."""
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
    """Return True when the branch matches an approved glob or pattern."""
    ref = branch.removeprefix("refs/heads/").strip()
    patterns = (pattern,) if pattern is not None else APPROVED_BRANCHES
    for pat in patterns:
        if pat.endswith("/**"):
            prefix = pat[:-3]
            if ref == prefix or ref.startswith(prefix + "/"):
                return True
        elif ref == pat:
            return True
    return False


def resolve_branch(raw_branch: str) -> str:
    """Resolve and normalize the branch from CLI args or GitHub env vars."""
    return (
        raw_branch.strip()
        or os.environ.get("GITHUB_HEAD_REF", "").strip()
        or os.environ.get("GITHUB_REF_NAME", "").strip()
    ).removeprefix("refs/heads/").strip()


def load_project_files(repo_root: Path) -> tuple[dict[str, str], dict[str, str]]:
    """Load project.values and build.values from the caller repo root."""
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
    """Return n for template apps and y for libraries."""
    return "n" if project_values.get("TEMPLATE", "").strip() else "y"


def load_maven_metadata(
    repo_root: Path,
    project_values: dict[str, str],
) -> dict[str, str]:
    """Read Maven metadata and library flag from pom.xml."""
    pom_path = repo_root / "pom.xml"
    if not pom_path.is_file():
        _log_error(f"missing {pom_path}")
        raise FileNotFoundError(str(pom_path))

    try:
        root = ET.parse(pom_path).getroot()
    except (OSError, ET.ParseError) as exc:
        _log_error(str(exc))
        raise

    parent_version_el = xml_child(xml_child(root, "parent"), "version")
    parent_version = xml_text(parent_version_el)
    project_version = xml_text(xml_child(root, "version"))
    application_version = parent_version if parent_version_el is not None else project_version
    artifact_id = xml_text(xml_child(root, "artifactId"))
    pom_name = xml_text(xml_child(root, "name"))
    properties_el = xml_child(root, "properties")
    java_version = xml_text(xml_child(properties_el, "java.version"))
    sonar_inclusions = xml_text(xml_child(properties_el, "sonar.inclusions"))
    sonar_exclusions = xml_text(xml_child(properties_el, "sonar.exclusions"))

    if not application_version or not artifact_id or not java_version:
        _log_error("pom.xml must have version, artifactId, and properties/java.version")
        raise ValueError("invalid pom.xml")

    return {
        "application_version": application_version,
        "parent_version": parent_version,
        "project_version": project_version,
        "artifact_id": artifact_id,
        "name": pom_name,
        "java_version": java_version,
        "sonar_inclusions": sonar_inclusions,
        "sonar_exclusions": sonar_exclusions,
        "is_library": is_library_from_template(project_values),
    }


def find_csproj(repo_root: Path, application_name: str) -> Path:
    """Return the best-matching csproj for the caller repo."""
    candidates = sorted(repo_root.glob("*.csproj"))
    if not candidates:
        candidates = sorted(repo_root.rglob("*.csproj"))
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


def load_dotnet_metadata(
    repo_root: Path,
    project_values: dict[str, str],
) -> dict[str, str]:
    """Read dotnet metadata from Directory.Build.props and a csproj file."""
    application_name = project_values.get("APPLICATION_NAME", "").strip()
    csproj_path = find_csproj(repo_root, application_name)

    props_path = repo_root / "Directory.Build.props"
    props_root = None
    parent_version = ""
    if props_path.is_file():
        try:
            props_root = ET.parse(props_path).getroot()
        except (OSError, ET.ParseError) as exc:
            _log_error(str(exc))
            raise
        parent_version = xml_text(xml_find(props_root, "Version"))

    try:
        root = ET.parse(csproj_path).getroot()
    except (OSError, ET.ParseError) as exc:
        _log_error(str(exc))
        raise

    project_version = xml_text(xml_find(root, "Version"))
    application_version = project_version or parent_version
    artifact_id = xml_text(xml_find(root, "AssemblyName")) or csproj_path.stem
    product_name = xml_text(xml_find(root, "Product"))
    target_framework = xml_text(xml_find(root, "TargetFramework"))
    sonar_inclusions = xml_text(xml_find(root, "sonar.inclusions"))
    sonar_exclusions = xml_text(xml_find(root, "sonar.exclusions"))
    if props_root is not None:
        if not sonar_inclusions:
            sonar_inclusions = xml_text(xml_find(props_root, "sonar.inclusions"))
        if not sonar_exclusions:
            sonar_exclusions = xml_text(xml_find(props_root, "sonar.exclusions"))

    if not application_version or not artifact_id or not target_framework:
        _log_error(
            f"{csproj_path.name} must have Version, AssemblyName or filename, and TargetFramework"
        )
        raise ValueError("invalid csproj")

    return {
        "application_version": application_version,
        "parent_version": parent_version,
        "project_version": project_version,
        "artifact_id": artifact_id,
        "name": product_name,
        "java_version": target_framework,
        "sonar_inclusions": sonar_inclusions,
        "sonar_exclusions": sonar_exclusions,
        "is_library": is_library_from_template(project_values),
    }


def load_ng_ui_version(repo_root: Path) -> str:
    """Read the application version from package.json @test/components."""
    pkg_path = repo_root / "package.json"
    if not pkg_path.is_file():
        _log_error(f"missing {pkg_path}")
        raise FileNotFoundError(str(pkg_path))

    try:
        pkg = json.loads(pkg_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        _log_error(str(exc))
        raise

    if not isinstance(pkg, dict):
        _log_error("package.json must be a JSON object")
        raise ValueError("invalid package.json")

    dependencies = pkg.get("dependencies")
    if not isinstance(dependencies, dict):
        _log_error("package.json must have a dependencies object")
        raise ValueError("missing package.json dependencies")

    application_version = str(dependencies.get("@test/components", "")).strip()
    if not application_version:
        _log_error("package.json dependencies must include @test/components version")
        raise ValueError("missing @test/components version")
    return application_version


def resolve_auto_commit(actor: str, bot_name: str) -> tuple[str, bool]:
    """Resolve bot identity and auto-commit skip when actor is an automation bot."""
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
) -> list[str]:
    """Compute the ordered stage list for this run."""
    if auto_commit:
        return []

    stages = [stage for stage in BUILD_STAGES if stage != "docker"]
    if branch == "develop" and not is_pr:
        stages.append("snapshot_artifact")
    if is_manual and (
        branch_approved(branch, "release/**") or branch_approved(branch, "hotfix/**")
    ):
        stages.append("release_artifact")
    if is_manual and is_library != "y" and not is_pr:
        stages.append("docker")
    return stages


def sonar_cli_from_sources(
    build_values: dict[str, str],
    project_meta: dict[str, str],
) -> tuple[str, str, str]:
    """Build Sonar CLI args from build.values, falling back to project metadata."""
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
    approved: bool,
    event: str,
    actor: str,
    bot_name: str,
    auto_commit: bool,
    stages: list[str],
    app_build_type: str,
    project_meta: dict[str, str],
    application_version: str,
    build_values: dict[str, str],
    project_values: dict[str, str],
) -> dict[str, str]:
    """Assemble GitHub Actions outputs and merge project/build values files."""
    cpg_origin = build_values.get("CPGBUILD_APP_ORIGIN", "").strip()
    sonar_inclusions, sonar_exclusions, sonar_cli_args = sonar_cli_from_sources(
        build_values,
        project_meta,
    )

    outputs = {
        "branch": branch,
        "approved": _bool_str(approved),
        "event": event,
        "actor": actor,
        "bot_name": bot_name,
        "auto_commit": _bool_str(auto_commit),
        "snapshot_artifact": _bool_str("snapshot_artifact" in stages),
        "release_artifact": _bool_str("release_artifact" in stages),
        "docker": _bool_str("docker" in stages),
        "stages": ",".join(stages),
        "app_build_type": app_build_type,
        "application_version": application_version or project_meta.get("application_version", ""),
        "parent_version": project_meta.get("parent_version", ""),
        "project_version": project_meta.get("project_version", ""),
        "artifact_id": project_meta.get("artifact_id", ""),
        "name": project_meta.get("name", ""),
        "java_version": project_meta.get("java_version", ""),
        "cpgbuild_app_origin": cpg_origin,
        "checks_type_skip": _bool_str(bool(cpg_origin)),
        "is_library": project_meta.get("is_library", ""),
        "sonar_inclusions": sonar_inclusions,
        "sonar_exclusions": sonar_exclusions,
        "sonar_cli_args": sonar_cli_args,
    }

    reserved = set(outputs)
    for src in (project_values, build_values):
        for key, value in src.items():
            out_key = key.lower()
            if out_key not in reserved:
                outputs[out_key] = value
    return outputs


def emit_outputs(outputs: dict[str, str]) -> None:
    """Print preprocess outputs as question-and-answer lines."""
    for key, value in outputs.items():
        match key:
            case "branch":
                print(f"What is the branch name? : {value}", file=sys.stdout)
            case "approved":
                print(f"Is the branch approved? : {value}", file=sys.stdout)
            case "event":
                print(f"What is the GitHub event? : {value}", file=sys.stdout)
            case "actor":
                print(f"Who triggered the workflow? : {value}", file=sys.stdout)
            case "bot_name":
                print(f"What is the auto-commit bot name? : {value}", file=sys.stdout)
            case "auto_commit":
                print(f"Is this an auto-commit run? : {value}", file=sys.stdout)
            case "snapshot_artifact":
                print(f"Should a snapshot artifact be published? : {value}", file=sys.stdout)
            case "release_artifact":
                print(f"Should a release artifact be published? : {value}", file=sys.stdout)
            case "docker":
                print(f"Should the Docker stage run? : {value}", file=sys.stdout)
            case "stages":
                print(f"Which build stages should run? : {value}", file=sys.stdout)
            case "app_build_type":
                print(f"What is the app build type? : {value}", file=sys.stdout)
            case "application_version":
                print(f"What is the application version? : {value}", file=sys.stdout)
            case "parent_version":
                print(f"What is the Maven parent version? : {value}", file=sys.stdout)
            case "project_version":
                print(f"What is the Maven project version? : {value}", file=sys.stdout)
            case "artifact_id":
                print(f"What is the Maven artifact ID? : {value}", file=sys.stdout)
            case "name":
                print(f"What is the Maven project name? : {value}", file=sys.stdout)
            case "java_version":
                print(f"What is the Java version? : {value}", file=sys.stdout)
            case "cpgbuild_app_origin":
                print(f"What is the CPGBUILD app origin? : {value}", file=sys.stdout)
            case "checks_type_skip":
                print(f"Should checks type be skipped? : {value}", file=sys.stdout)
            case "is_library":
                print(f"Is this a library project? : {value}", file=sys.stdout)
            case "sonar_inclusions":
                print(f"What are the Sonar inclusion arguments? : {value}", file=sys.stdout)
            case "sonar_exclusions":
                print(f"What are the Sonar exclusion arguments? : {value}", file=sys.stdout)
            case "sonar_cli_args":
                print(f"What are the Sonar CLI arguments? : {value}", file=sys.stdout)
            case _:
                print(f"What is the {key.replace('_', ' ')}? : {value}", file=sys.stdout)


def write_github_output(output_path: str, outputs: dict[str, str]) -> None:
    """Append key=value lines for GitHub Actions output."""
    with open(output_path, "a", encoding="utf-8") as fh:
        fh.writelines(f"{key}={value}\n" for key, value in outputs.items())


def main() -> int:
    """Parse inputs, validate the branch, and emit preprocess outputs."""
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
    except (OSError, FileNotFoundError):
        return 1

    project_meta: dict[str, str] = {}
    application_version = ""
    try:
        if args.app_build_type == "maven":
            project_meta = load_maven_metadata(repo_root, project_values)
        elif args.app_build_type == "dotnet":
            project_meta = load_dotnet_metadata(repo_root, project_values)
        elif args.app_build_type == "ng-ui":
            application_version = load_ng_ui_version(repo_root)
    except (OSError, ValueError, FileNotFoundError, ET.ParseError):
        return 1

    event = args.event.strip() or os.environ.get("GITHUB_EVENT_NAME", "").strip()
    actor = args.actor.strip() or os.environ.get("GITHUB_ACTOR", "").strip()
    bot_name, auto_commit = resolve_auto_commit(actor, args.bot_name.strip())
    is_pr = event.startswith("pull_request")
    is_manual = event == "workflow_dispatch"

    stages = build_stages(
        auto_commit=auto_commit,
        branch=branch,
        is_pr=is_pr,
        is_manual=is_manual,
        is_library=project_meta.get("is_library", ""),
    )

    outputs = build_outputs(
        branch=branch,
        approved=True,
        event=event,
        actor=actor,
        bot_name=bot_name,
        auto_commit=auto_commit,
        stages=stages,
        app_build_type=args.app_build_type,
        project_meta=project_meta,
        application_version=application_version,
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
