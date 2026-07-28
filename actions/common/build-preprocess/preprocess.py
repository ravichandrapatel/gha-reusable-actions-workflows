"""
FILE_NAME: preprocess.py
DESCRIPTION: Load build.values / project.values and resolve APP_BUILD_TYPE metadata (ng-ui first).
VERSION: 1.0.0
EXIT_CODES: 0 = success; 1 = validation / I/O / unsupported build type
AUTHORS: Platform / DevOps
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Any

EXIT_CODE_SUCCESS = 0
EXIT_CODE_ERROR = 1

PROJECT_PREFIX = "[BUILD-PREPROCESS]"

ALLOWED_APP_BUILD_TYPES = ("maven-java", "dotnet", "ng-ui")
IMPLEMENTED_APP_BUILD_TYPES = ("ng-ui",)

# Exact branch names
ALLOWED_BRANCH_EXACT = ("master", "main", "develop")
# Branch families: "feature", "feature/foo", "feature-foo" are allowed
ALLOWED_BRANCH_PREFIXES = ("feature", "release", "hotfix", "bugfix")

# Always-on pipeline stages (boolean outputs)
STAGE_OUTPUTS_ALWAYS = ("build_and_unit_test", "owasp", "sonar")

BUILD_VALUES_REQUIRED = (
    "BUILDER_BASE_IMAGE",
    "LIB_01",
    "LIB_02",
    "LIB_03",
)

PROJECT_VALUES_REQUIRED = (
    "APPLICATION_NAME",
    "ORGANIZATION",
    "PRODUCT",
    "PROJECT_DESCRIPTION",
    "CMDBIDNPD",
    "CMDBIDPRD",
    "TEAMADGROUNPD",
    "TEAMADGROUPPRD",
)


def _log(message: str) -> None:
    """INTENT: Print a prefixed breadcrumb. INPUT: message. OUTPUT: None. SIDE_EFFECTS: stdout."""
    print(f"{PROJECT_PREFIX} {message}")


def parse_args() -> argparse.Namespace:
    """INTENT: Parse CLI; defaults from APP_BUILD_TYPE, GITHUB_WORKSPACE, GITHUB_OUTPUT.
    INPUT: argv + env. OUTPUT: Namespace. SIDE_EFFECTS: None."""
    p = argparse.ArgumentParser(
        description="Resolve app build metadata from values files and type-specific project file."
    )
    p.add_argument(
        "--app-build-type",
        default=os.environ.get("APP_BUILD_TYPE", ""),
        help="Build type: maven-java | dotnet | ng-ui (default: env APP_BUILD_TYPE)",
    )
    p.add_argument(
        "--branch",
        default=os.environ.get("GITHUB_REF_NAME", "") or os.environ.get("BRANCH", ""),
        help="Git branch to validate (default: env GITHUB_REF_NAME or BRANCH)",
    )
    p.add_argument(
        "--event-name",
        default=os.environ.get("GITHUB_EVENT_NAME", "") or os.environ.get("EVENT_NAME", ""),
        help="GitHub event name (default: env GITHUB_EVENT_NAME)",
    )
    p.add_argument(
        "--actor",
        default=os.environ.get("GITHUB_ACTOR", "") or os.environ.get("ACTOR", ""),
        help="GitHub actor (default: env GITHUB_ACTOR); used to detect bot commits",
    )
    p.add_argument(
        "--workspace",
        default=os.environ.get("GITHUB_WORKSPACE", ""),
        help="Caller repo root containing values files (default: env GITHUB_WORKSPACE or cwd)",
    )
    p.add_argument(
        "--output",
        default=os.environ.get("GITHUB_OUTPUT", ""),
        help="GitHub Actions output file path (default: env GITHUB_OUTPUT)",
    )
    p.add_argument(
        "--dry-run",
        action="store_true",
        help="Print resolved outputs as JSON; do not write --output / GITHUB_OUTPUT",
    )
    return p.parse_args()


def load_values_file(path: Path) -> dict[str, str]:
    """INTENT: Load key=value file; ignore blanks and # comments / # keys.
    INPUT: path. OUTPUT: dict. SIDE_EFFECTS: reads file. RAISES: OSError, ValueError."""
    result: dict[str, str] = {}
    text = path.read_text(encoding="utf-8")
    for line_no, raw_line in enumerate(text.splitlines(), start=1):
        line = raw_line.strip()
        if not line:
            continue
        if line.startswith("#"):
            continue
        if "=" not in line:
            raise ValueError(f"{path}:{line_no}: expected key=value, got: {raw_line!r}")
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip()
        if not key:
            raise ValueError(f"{path}:{line_no}: empty key")
        if key.startswith("#"):
            continue
        result[key] = value
    return result


def require_keys(values: dict[str, str], required: tuple[str, ...], label: str) -> None:
    """INTENT: Ensure required keys exist and are non-empty.
    INPUT: values, required, label. OUTPUT: None. RAISES: ValueError."""
    missing = [k for k in required if k not in values]
    empty = [k for k in required if k in values and not values[k].strip()]
    if missing:
        raise ValueError(f"{label} missing required key(s): {', '.join(missing)}")
    if empty:
        raise ValueError(f"{label} empty required key(s): {', '.join(empty)}")


def normalize_branch(branch: str) -> str:
    """INTENT: Strip refs/heads/ prefix from a branch ref.
    INPUT: branch. OUTPUT: short branch name. SIDE_EFFECTS: None."""
    name = branch.strip()
    if name.startswith("refs/heads/"):
        name = name[len("refs/heads/") :]
    return name


def is_allowed_branch(branch: str) -> bool:
    """INTENT: True when branch is master/main/develop or feature|release|hotfix|bugfix family.
    INPUT: branch. OUTPUT: bool. SIDE_EFFECTS: None."""
    name = normalize_branch(branch)
    if not name:
        return False
    if name in ALLOWED_BRANCH_EXACT:
        return True
    for prefix in ALLOWED_BRANCH_PREFIXES:
        if name == prefix or name.startswith(f"{prefix}/") or name.startswith(f"{prefix}-"):
            return True
    return False


def is_branch_family(branch: str, *prefixes: str) -> bool:
    """INTENT: True when branch equals or is prefixed by any of the given families.
    INPUT: branch, prefixes. OUTPUT: bool. SIDE_EFFECTS: None."""
    name = normalize_branch(branch)
    for prefix in prefixes:
        if name == prefix or name.startswith(f"{prefix}/") or name.startswith(f"{prefix}-"):
            return True
    return False


def is_bot_actor(actor: str) -> bool:
    """INTENT: Detect bot / automation actors (GitHub Apps, *-bot names).
    INPUT: actor. OUTPUT: bool. SIDE_EFFECTS: None."""
    name = (actor or "").strip().lower()
    if not name:
        return False
    return name.endswith("[bot]") or name.endswith("-bot") or name.endswith("_bot")


def resolve_stage_outputs(*, branch: str, event_name: str, actor: str) -> dict[str, str]:
    """INTENT: Compute boolean stage/artifact gates from branch + event + actor.
    INPUT: branch, event_name, actor. OUTPUT: dict of true/false strings. SIDE_EFFECTS: None."""
    is_pr = event_name.strip() == "pull_request"
    is_manual = event_name.strip() == "workflow_dispatch"
    bot = is_bot_actor(actor)

    stages: dict[str, str] = {name: "true" for name in STAGE_OUTPUTS_ALWAYS}

    # develop and not PR → snapshot_artifact
    stages["snapshot_artifact"] = (
        "true" if (normalize_branch(branch) == "develop" and not is_pr) else "false"
    )
    # release or hotfix and manual → release_artifact
    stages["release_artifact"] = (
        "true"
        if (is_manual and is_branch_family(branch, "release", "hotfix"))
        else "false"
    )
    # manual, not bot autocommit, not PR → docker_image
    stages["docker_image"] = (
        "true" if (is_manual and not bot and not is_pr) else "false"
    )
    return stages


def resolve_ng_ui(workspace: Path) -> dict[str, str]:
    """INTENT: Read package.json name/version + engines.node for ng-ui.
    INPUT: workspace. OUTPUT: application_version, node_version (+ package_name).
    SIDE_EFFECTS: reads package.json. RAISES: OSError, ValueError, json.JSONDecodeError."""
    pkg_path = workspace / "package.json"
    if not pkg_path.is_file():
        raise ValueError(f"package.json not found at {pkg_path}")

    raw: Any = json.loads(pkg_path.read_text(encoding="utf-8"))
    if not isinstance(raw, dict):
        raise ValueError("package.json root must be a JSON object")

    version = raw.get("version")
    if not isinstance(version, str) or not version.strip():
        raise ValueError("package.json missing non-empty string 'version'")

    engines = raw.get("engines")
    if not isinstance(engines, dict):
        raise ValueError("package.json missing object 'engines'")
    node_version = engines.get("node")
    if not isinstance(node_version, str) or not node_version.strip():
        raise ValueError("package.json missing non-empty string 'engines.node'")

    package_name = raw.get("name")
    out: dict[str, str] = {
        "application_version": version.strip(),
        "node_version": node_version.strip(),
    }
    if isinstance(package_name, str) and package_name.strip():
        out["package_name"] = package_name.strip()
    return out


def write_outputs(outputs: dict[str, str], output_path: str) -> None:
    """INTENT: Append key=value outputs for GitHub Actions.
    INPUT: outputs, path. OUTPUT: None. SIDE_EFFECTS: appends file."""
    with open(output_path, "a", encoding="utf-8") as fh:
        for key, value in outputs.items():
            fh.write(f"{key}={value}\n")


def main() -> int:
    """INTENT: Validate APP_BUILD_TYPE, load values files, resolve type-specific metadata.
    INPUT: None. OUTPUT: exit code. SIDE_EFFECTS: stdout/stderr, optional GITHUB_OUTPUT."""
    try:
        args = parse_args()
        app_build_type = (args.app_build_type or "").strip()
        if not app_build_type:
            print(
                f"{PROJECT_PREFIX} ERROR: --app-build-type is required "
                "(or set env APP_BUILD_TYPE)",
                file=sys.stderr,
            )
            return EXIT_CODE_ERROR
        if app_build_type not in ALLOWED_APP_BUILD_TYPES:
            print(
                f"{PROJECT_PREFIX} ERROR: APP_BUILD_TYPE must be one of "
                f"{', '.join(ALLOWED_APP_BUILD_TYPES)}; got '{app_build_type}'",
                file=sys.stderr,
            )
            return EXIT_CODE_ERROR
        if app_build_type not in IMPLEMENTED_APP_BUILD_TYPES:
            print(
                f"{PROJECT_PREFIX} ERROR: APP_BUILD_TYPE '{app_build_type}' "
                "is not implemented yet (only ng-ui)",
                file=sys.stderr,
            )
            return EXIT_CODE_ERROR

        branch = normalize_branch(args.branch or "")
        if not branch:
            print(
                f"{PROJECT_PREFIX} ERROR: --branch is required "
                "(or set env GITHUB_REF_NAME / BRANCH)",
                file=sys.stderr,
            )
            return EXIT_CODE_ERROR
        if not is_allowed_branch(branch):
            allowed = (
                f"{', '.join(ALLOWED_BRANCH_EXACT)}; "
                f"prefixes: {', '.join(ALLOWED_BRANCH_PREFIXES)}"
            )
            print(
                f"{PROJECT_PREFIX} ERROR: branch '{branch}' is not allowed "
                f"(allowed: {allowed})",
                file=sys.stderr,
            )
            return EXIT_CODE_ERROR

        workspace_raw = (args.workspace or "").strip() or os.getcwd()
        workspace = Path(workspace_raw).resolve()
        if not workspace.is_dir():
            print(
                f"{PROJECT_PREFIX} ERROR: workspace is not a directory: {workspace}",
                file=sys.stderr,
            )
            return EXIT_CODE_ERROR

        build_values_path = workspace / "build.values"
        project_values_path = workspace / "project.values"
        for path in (build_values_path, project_values_path):
            if not path.is_file():
                print(f"{PROJECT_PREFIX} ERROR: file not found: {path}", file=sys.stderr)
                return EXIT_CODE_ERROR

        build_values = load_values_file(build_values_path)
        project_values = load_values_file(project_values_path)
        require_keys(build_values, BUILD_VALUES_REQUIRED, "build.values")
        require_keys(project_values, PROJECT_VALUES_REQUIRED, "project.values")

        type_outputs = resolve_ng_ui(workspace)
        event_name = (args.event_name or "").strip()
        actor = (args.actor or "").strip()
        stage_outputs = resolve_stage_outputs(
            branch=branch, event_name=event_name, actor=actor
        )

        outputs: dict[str, str] = {
            "app_build_type": app_build_type,
            "branch": branch,
            "event_name": event_name,
            "actor": actor,
            **{k: build_values[k] for k in BUILD_VALUES_REQUIRED},
            **{k: project_values[k] for k in PROJECT_VALUES_REQUIRED},
            **type_outputs,
            **stage_outputs,
        }

        _log(
            f"workspace={workspace} app_build_type={app_build_type} branch={branch} "
            f"event={event_name or '-'} actor={actor or '-'} "
            f"application_version={outputs['application_version']} "
            f"node_version={outputs['node_version']} "
            f"stages={{{', '.join(f'{k}={v}' for k, v in stage_outputs.items())}}}"
        )

        output_path = (args.output or "").strip()
        if args.dry_run:
            print(json.dumps(outputs, sort_keys=True))
        elif output_path:
            write_outputs(outputs, output_path)
        else:
            _log("no --output / GITHUB_OUTPUT; skipping file-append.")

        return EXIT_CODE_SUCCESS

    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"{PROJECT_PREFIX} ERROR: {exc}", file=sys.stderr)
        return EXIT_CODE_ERROR


if __name__ == "__main__":
    sys.exit(main())
