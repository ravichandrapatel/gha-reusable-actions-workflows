"""
FILE_NAME: preprocess.py
DESCRIPTION: Branch allowlist, stages, values files, and maven/ng-ui/dotnet metadata.
VERSION: 2.9.0
AUTHORS: DevOps Team
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

import defusedxml.ElementTree as ET

PROJECT_KEY = "BUILD-PREPROCESS"
DOTNET_CSPROJ = Path("build") / "Build.csproj"

ALLOWED_BRANCHES = (
    "main",
    "master",
    "develop",
    "feature/**",
    "release/**",
    "hotfix/**",
    "bugfix/**",
)

BUILD_STAGES = ["build_and_unit_test", "owasp", "sonar", "docker"]
APP_BUILD_TYPES = ["maven", "ng-ui", "dotnet"]
OPTIONAL_BUILD_LIBS = ("LIB_01", "LIB_02", "LIB_03")


def _err(message: str) -> None:
    print(f"[{PROJECT_KEY}] {message}", file=sys.stderr)


def _tag(el: ET.Element) -> str:
    return el.tag.rsplit("}", 1)[-1]


def _child(el: ET.Element | None, name: str) -> ET.Element | None:
    if el is None:
        return None
    for child in el:
        if _tag(child) == name:
            return child
    return None


def _children(el: ET.Element | None, name: str) -> list[ET.Element]:
    if el is None:
        return []
    return [child for child in el if _tag(child) == name]


def _text(el: ET.Element | None) -> str:
    return "" if el is None or el.text is None else el.text.strip()


def _pom_module_names(root: ET.Element) -> list[str]:
    """Non-empty <module> entries under root <modules>."""
    modules_el = _child(root, "modules")
    names: list[str] = []
    for module_el in _children(modules_el, "module"):
        name = _text(module_el)
        if name:
            names.append(name)
    return names


def _xml_prop(root: ET.Element, name: str) -> str:
    """MSBuild property: prefer PropertyGroup, else first matching element."""
    for el in root.iter():
        if _tag(el) == "PropertyGroup":
            value = _text(_child(el, name))
            if value:
                return value
    for el in root.iter():
        if _tag(el) == name and el.text:
            return el.text.strip()
    return ""


def _parse_xml(path: Path) -> ET.Element:
    try:
        return ET.parse(path).getroot()
    except (OSError, ET.ParseError) as exc:
        _err(f"could not parse {path}: {exc}" if isinstance(exc, ET.ParseError) else str(exc))
        raise


def _parse_json(path: Path, label: str) -> dict:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        _err(str(exc) if isinstance(exc, OSError) else f"could not parse {path}: {exc}")
        raise
    if not isinstance(data, dict):
        _err(f"{label} must be a JSON object")
        raise ValueError(f"invalid {label}")
    return data


def _strip_value(raw: str) -> str:
    value = raw.strip()
    if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
        value = value[1:-1].strip()
    return value


def load_values(path: Path) -> dict[str, str]:
    data: dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        if key:
            data[key] = _strip_value(value)
    return data


def _resolve_dotnet_csproj(repo_root: Path) -> Path:
    """Fixed layout: build/Build.csproj (APPLICATION_NAME is not used for selection)."""
    preferred = repo_root / DOTNET_CSPROJ
    if preferred.is_file():
        return preferred
    build_dir = repo_root / "build"
    if build_dir.is_dir():
        for path in sorted(build_dir.iterdir()):
            if path.is_file() and path.name.casefold() == "build.csproj":
                return path
    _err(f"missing {preferred}")
    raise FileNotFoundError(str(preferred))


def branch_approved(branch: str, pattern: str | None = None) -> bool:
    ref = branch.removeprefix("refs/heads/").strip()
    for pat in ((pattern,) if pattern is not None else ALLOWED_BRANCHES):
        if pat.endswith("/**"):
            prefix = pat[:-3]
            if ref == prefix or ref.startswith(prefix + "/"):
                return True
        elif ref == pat:
            return True
    return False


def load_maven_metadata(repo_root: Path, project_values: dict[str, str]) -> dict[str, str]:
    pom_path = repo_root / "pom.xml"
    if not pom_path.is_file():
        _err(f"missing {pom_path}")
        raise FileNotFoundError(str(pom_path))

    root = _parse_xml(pom_path)
    parent_el = _child(root, "parent")
    parent_version_el = _child(parent_el, "version") if parent_el is not None else None
    parent_version = _text(parent_version_el)
    project_version = _text(_child(root, "version"))
    application_version = parent_version if parent_version_el is not None else project_version
    properties_el = _child(root, "properties")
    java_version = _text(_child(properties_el, "java.version"))
    artifact_id = _text(_child(root, "artifactId"))

    if not application_version or not artifact_id or not java_version:
        _err("pom.xml must have version, artifactId, and properties/java.version")
        raise ValueError("invalid pom.xml")

    is_library = "n" if project_values.get("TEMPLATE", "").strip() else "y"
    packaging = _text(_child(root, "packaging")).casefold() or "jar"
    is_multimodule_lib = ""
    if is_library == "y":
        module_names = _pom_module_names(root)
        if packaging == "pom" and not module_names:
            _err(
                "library pom.xml with packaging=pom must declare at least one "
                "non-empty <module> under <modules>"
            )
            raise ValueError("invalid multimodule library pom.xml")
        is_multimodule_lib = "y" if module_names else "n"

    return {
        "application_version": application_version,
        "parent_version": parent_version,
        "project_version": project_version,
        "artifact_id": artifact_id,
        "name": _text(_child(root, "name")),
        "java_version": java_version,
        "packaging": packaging,
        "sonar_inclusions": _text(_child(properties_el, "sonar.inclusions")),
        "sonar_exclusions": _text(_child(properties_el, "sonar.exclusions")),
        "is_library": is_library,
        "is_multimodule_lib": is_multimodule_lib,
    }


def load_dotnet_metadata(repo_root: Path, project_values: dict[str, str]) -> dict[str, str]:
    csproj_path = _resolve_dotnet_csproj(repo_root)
    root = _parse_xml(csproj_path)

    props_path = repo_root / "Directory.Build.props"
    if not props_path.is_file():
        _err(f"missing {props_path}")
        raise FileNotFoundError(str(props_path))
    props_root = _parse_xml(props_path)
    parent_version = _xml_prop(props_root, "Version")

    global_json = repo_root / "global.json"
    if not global_json.is_file():
        _err(f"missing {global_json}")
        raise FileNotFoundError(str(global_json))
    sdk = _parse_json(global_json, "global.json").get("sdk")
    dotnet_version = ""
    if isinstance(sdk, dict):
        dotnet_version = str(sdk.get("version", "")).strip()
    if not dotnet_version:
        _err("global.json must define sdk.version")
        raise ValueError("invalid global.json")

    project_version = _xml_prop(root, "Version")
    application_version = project_version or parent_version
    artifact_id = _xml_prop(root, "AssemblyName") or csproj_path.stem
    sonar_inclusions = _xml_prop(root, "sonar.inclusions") or _xml_prop(
        props_root, "sonar.inclusions"
    )
    sonar_exclusions = _xml_prop(root, "sonar.exclusions") or _xml_prop(
        props_root, "sonar.exclusions"
    )

    if not application_version or not artifact_id:
        _err(
            f"{DOTNET_CSPROJ} / Directory.Build.props must provide Version and "
            "AssemblyName (or rely on Build.csproj filename)"
        )
        raise ValueError("invalid dotnet metadata")

    return {
        "application_version": application_version,
        "parent_version": parent_version,
        "project_version": project_version,
        "artifact_id": artifact_id,
        "name": _xml_prop(root, "Product") or _xml_prop(props_root, "Product"),
        "dotnet_version": dotnet_version,
        "sonar_inclusions": sonar_inclusions,
        "sonar_exclusions": sonar_exclusions,
        "is_library": "n" if project_values.get("TEMPLATE", "").strip() else "y",
        "is_multimodule_lib": "",
    }


def _npm_semver(raw: str) -> str:
    """Strip leading npm range markers (^ ~ >= <= > < =) and optional v prefix."""
    ver = raw.strip()
    while ver:
        if ver.startswith((">=", "<=")):
            ver = ver[2:].lstrip()
            continue
        if ver[0] in "^~=<>":
            ver = ver[1:].lstrip()
            continue
        break
    return ver.removeprefix("v")


def load_ng_ui_metadata(repo_root: Path) -> dict[str, str]:
    node_version = ""
    for filename in (".nvmrc", ".node-version"):
        version_file = repo_root / filename
        if not version_file.is_file():
            continue
        for line in version_file.read_text(encoding="utf-8").splitlines():
            candidate = line.strip()
            if candidate and not candidate.startswith("#"):
                node_version = candidate.removeprefix("v")
                break
        if node_version:
            break

    pkg_path = repo_root / "package.json"
    if not pkg_path.is_file():
        _err(f"missing {pkg_path}")
        raise FileNotFoundError(str(pkg_path))

    pkg = _parse_json(pkg_path, "package.json")
    if not node_version:
        engines = pkg.get("engines")
        if isinstance(engines, dict):
            node_version = str(engines.get("node", "")).strip().removeprefix("v")
    if not node_version:
        _err(
            "package.json must define engines.node or the repo must provide .nvmrc / .node-version"
        )
        raise ValueError("missing node version")

    deps = pkg.get("dependencies") if isinstance(pkg.get("dependencies"), dict) else {}
    has_components = "@test/components" in deps
    components_version = (
        _npm_semver(str(deps.get("@test/components", ""))) if has_components else ""
    )
    project_version = str(pkg.get("version", "")).strip()
    application_version = components_version if has_components else project_version

    if not application_version:
        _err(
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


def build_stages(
    *,
    auto_commit: bool,
    branch: str,
    event: str,
    is_library: str,
) -> list[str]:
    """Stage / publish tokens for the pipeline.

    - snapshot_artifact: develop, not PR
    - release_artifact: release/* or hotfix/*, push or workflow_dispatch, not PR
    - docker: push or workflow_dispatch, not PR, not library
    """
    if auto_commit:
        return []

    is_pr = event.startswith("pull_request")
    is_ship_event = event in ("push", "workflow_dispatch")
    stages = [s for s in BUILD_STAGES if s != "docker"]

    if branch == "develop" and not is_pr:
        stages.append("snapshot_artifact")
    if (
        not is_pr
        and is_ship_event
        and (branch_approved(branch, "release/**") or branch_approved(branch, "hotfix/**"))
    ):
        stages.append("release_artifact")
    if is_library != "y" and not is_pr and is_ship_event:
        stages.append("docker")
    return stages


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
    def flag(name: str) -> str:
        return "true" if name in stages else "false"

    inclusion = (
        build_values.get("CPGBUILD_SONAR_INCLUSION_LIST", "").strip()
        or project_meta.get("sonar_inclusions", "").strip()
    )
    exclusion = (
        build_values.get("CPGBUILD_SONAR_EXCLUSION_LIST", "").strip()
        or project_meta.get("sonar_exclusions", "").strip()
    )
    sonar_inclusions = f"-Dsonar.inclusions={inclusion}" if inclusion else ""
    sonar_exclusions = f"-Dsonar.exclusions={exclusion}" if exclusion else ""
    cpg_origin = (
        build_values.get("CPGBUILD_APP_ORIGIN", "").strip()
        or build_values.get("CPGBUILD_APPORIGIN", "").strip()
    )
    lib_outputs = {
        key.lower(): build_values.get(key, "").strip() for key in OPTIONAL_BUILD_LIBS
    }

    outputs = {
        "branch": branch,
        "approved": "true",
        "event": event,
        "actor": actor,
        "bot_name": bot_name,
        "auto_commit": "true" if auto_commit else "false",
        "build_and_unit_test": flag("build_and_unit_test"),
        "owasp": flag("owasp"),
        "sonar": flag("sonar"),
        "snapshot_artifact": flag("snapshot_artifact"),
        "release_artifact": flag("release_artifact"),
        "docker": flag("docker"),
        "stages": ",".join(stages),
        "app_build_type": app_build_type,
        "application_version": project_meta.get("application_version", ""),
        "parent_version": project_meta.get("parent_version", ""),
        "project_version": project_meta.get("project_version", ""),
        "artifact_id": project_meta.get("artifact_id", ""),
        "name": project_meta.get("name", ""),
        "java_version": project_meta.get("java_version", ""),
        "packaging": project_meta.get("packaging", ""),
        "node_version": project_meta.get("node_version", ""),
        "dotnet_version": project_meta.get("dotnet_version", ""),
        "cpgbuild_app_origin": cpg_origin,
        "checkstyle_skip": "true" if cpg_origin else "false",
        **lib_outputs,
        "is_library": project_meta.get("is_library", ""),
        "is_multimodule_lib": project_meta.get("is_multimodule_lib", ""),
        "sonar_inclusions": sonar_inclusions,
        "sonar_exclusions": sonar_exclusions,
        "sonar_cli_args": " ".join(p for p in (sonar_inclusions, sonar_exclusions) if p),
    }

    reserved = set(outputs)
    for src in (project_values, build_values):
        for key, value in src.items():
            out_key = key.lower()
            if out_key not in reserved:
                outputs[out_key] = value
    return outputs


def main() -> int:
    parser = argparse.ArgumentParser(description="Check branch against approved globs; emit stages")
    parser.add_argument("--branch", default="")
    parser.add_argument("--app-build-type", required=True, choices=APP_BUILD_TYPES)
    parser.add_argument(
        "--event",
        default="",
        help="GitHub event name (default: GITHUB_EVENT_NAME, else push for local runs)",
    )
    parser.add_argument("--actor", default="")
    parser.add_argument("--bot-name", default="")
    parser.add_argument("--output", default="")
    args = parser.parse_args()

    branch = (
        args.branch.strip()
        or os.environ.get("GITHUB_HEAD_REF", "").strip()
        or os.environ.get("GITHUB_REF_NAME", "").strip()
    ).removeprefix("refs/heads/").strip()
    if not branch:
        _err("pass --branch or set GITHUB_HEAD_REF / GITHUB_REF_NAME")
        return 1
    if not branch_approved(branch):
        _err(f"The branch '{branch}' is not on the approved allowlist")
        return 1

    repo_root = Path(os.environ.get("GITHUB_WORKSPACE", "").strip() or ".").resolve()
    project_file = repo_root / "project.values"
    build_file = repo_root / "build.values"
    try:
        if not project_file.is_file():
            _err(f"missing {project_file}")
            raise FileNotFoundError(str(project_file))
        if not build_file.is_file():
            _err(f"missing {build_file}")
            raise FileNotFoundError(str(build_file))
        project_values = load_values(project_file)
        build_values = load_values(build_file)
        project_meta = load_project_metadata(args.app_build_type, repo_root, project_values)
    except (OSError, ValueError, FileNotFoundError, ET.ParseError):
        return 1

    event = (
        args.event.strip()
        or os.environ.get("GITHUB_EVENT_NAME", "").strip()
        or "push"
    )
    actor = args.actor.strip() or os.environ.get("GITHUB_ACTOR", "").strip()
    bot_name = args.bot_name.strip()
    if bot_name:
        auto_commit = actor == bot_name
    elif actor.endswith("[bot]"):
        bot_name, auto_commit = actor, True
    else:
        bot_name, auto_commit = "", False

    stages = build_stages(
        auto_commit=auto_commit,
        branch=branch,
        event=event,
        is_library=project_meta.get("is_library", ""),
    )
    outputs = build_outputs(
        branch=branch,
        event=event,
        actor=actor,
        bot_name=bot_name,
        auto_commit=auto_commit,
        stages=stages,
        app_build_type=args.app_build_type,
        project_meta=project_meta,
        build_values=build_values,
        project_values=project_values,
    )

    for key, value in outputs.items():
        print(f"What is the {key.replace('_', ' ')}? : {value}", file=sys.stdout)

    output_path = args.output.strip()
    if output_path:
        with open(output_path, "a", encoding="utf-8") as fh:
            fh.writelines(f"{key}={value}\n" for key, value in outputs.items())
    return 0


if __name__ == "__main__":
    sys.exit(main())
