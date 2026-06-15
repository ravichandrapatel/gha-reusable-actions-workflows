# =============================================================================
# FILE_NAME: stage_component.py
# DESCRIPTION: Stage component workflows/actions under .github/workflows for Checkov scanning.
# VERSION: 1.0.0
# EXIT_CODES/SIGNALS: 0 on success, 1 on validation or I/O failure
# AUTHORS: DevOps Team
# =============================================================================
from __future__ import annotations

import argparse
import shutil
import sys
from pathlib import Path
from typing import Any

import yaml

PROJECT_PREFIX = "[SPVS-CHECKOV-STAGE]"


def _log(message: str) -> None:
    """
    INTENT: Emit structured operational logs for staging diagnostics.
    INPUT: message - log line without prefix.
    OUTPUT: None.
    SIDE_EFFECTS: writes to stdout.
    """
    print(f"{PROJECT_PREFIX} {message}")


def _load_yaml(path: Path) -> dict[str, Any]:
    """
    INTENT: Parse a YAML file into a dictionary.
    INPUT: path - filesystem path to YAML file.
    OUTPUT: Parsed YAML as dict.
    SIDE_EFFECTS: reads file from disk.
    """
    try:
        with path.open(encoding="utf-8") as handle:
            loaded = yaml.safe_load(handle)
    except OSError as exc:
        _log(f"[DBG-910] Failed to read YAML file {path}: {exc}")
        raise SystemExit(1) from exc
    except yaml.YAMLError as exc:
        _log(f"[DBG-911] Invalid YAML in {path}: {exc}")
        raise SystemExit(1) from exc

    if not isinstance(loaded, dict):
        _log(f"[DBG-912] Expected mapping document in {path}")
        raise SystemExit(1)
    return loaded


def _write_yaml(path: Path, payload: dict[str, Any]) -> None:
    """
    INTENT: Write a dictionary as YAML for Checkov consumption.
    INPUT: path - destination file; payload - workflow document.
    OUTPUT: None.
    SIDE_EFFECTS: writes file to disk.
    """
    try:
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("w", encoding="utf-8") as handle:
            yaml.safe_dump(payload, handle, sort_keys=False)
    except OSError as exc:
        _log(f"[DBG-913] Failed to write staged workflow {path}: {exc}")
        raise SystemExit(1) from exc


def _synthesize_workflow_from_action(action_doc: dict[str, Any], component_name: str) -> dict[str, Any]:
    """
    INTENT: Convert composite action metadata into a scannable workflow document.
    INPUT: action_doc - parsed action.yml; component_name - directory basename.
    OUTPUT: Synthetic workflow dict with jobs/steps mirroring runs.steps.
    SIDE_EFFECTS: none
    """
    runs_block = action_doc.get("runs", {})
    if not isinstance(runs_block, dict):
        _log("[DBG-914] action.yml missing runs block")
        raise SystemExit(1)

    using = runs_block.get("using")
    if using != "composite":
        _log(f"[DBG-915] Unsupported action type '{using}'; only composite actions are staged")
        raise SystemExit(1)

    steps = runs_block.get("steps", [])
    if not isinstance(steps, list):
        _log("[DBG-916] action.yml runs.steps must be a list")
        raise SystemExit(1)

    return {
        "name": f"SPVS Checkov Staging - {component_name}",
        "on": {"workflow_call": {}},
        "permissions": {"contents": "read"},
        "jobs": {
            "spvs_staged_action": {
                "name": "Staged Composite Action Steps",
                "runs-on": "ubuntu-latest",
                "permissions": {"contents": "read"},
                "steps": steps,
            }
        },
    }


def stage_component(component_path: Path, staging_root: Path) -> Path:
    """
    INTENT: Copy or synthesize a workflow under staging_root/.github/workflows/.
    INPUT: component_path - actions/... or workflows/... directory; staging_root - output root.
    OUTPUT: Path to staged workflow YAML file.
    SIDE_EFFECTS: creates/removes files under staging_root.
    """
    # _log("[T-01] Resolving component path")
    if not component_path.is_dir():
        _log(f"[DBG-901] Component path does not exist: {component_path}")
        raise SystemExit(1)

    workflows_dir = staging_root / ".github" / "workflows"
    if workflows_dir.parent.exists():
        shutil.rmtree(workflows_dir.parent)
    workflows_dir.mkdir(parents=True, exist_ok=True)

    component_name = component_path.name
    dest = workflows_dir / f"spvs-staged-{component_name}.yml"
    path_str = str(component_path).replace("\\", "/")

    if path_str.startswith("actions/") or "/actions/" in path_str:
        action_file = component_path / "action.yml"
        if not action_file.is_file():
            action_file = component_path / "action.yaml"
        if not action_file.is_file():
            _log(f"[DBG-902] No action.yml found in {component_path}")
            raise SystemExit(1)
        _log(f"[DBG-002] Synthesizing workflow from {action_file}")
        action_doc = _load_yaml(action_file)
        workflow_doc = _synthesize_workflow_from_action(action_doc, component_name)
        _write_yaml(dest, workflow_doc)
        return dest

    if path_str.startswith("workflows/") or "/workflows/" in path_str:
        candidates = sorted(component_path.glob("*.yml")) + sorted(component_path.glob("*.yaml"))
        if not candidates:
            _log(f"[DBG-903] No workflow YAML found in {component_path}")
            raise SystemExit(1)
        if len(candidates) > 1:
            _log(f"[DBG-904] Multiple workflow files found; using {candidates[0]}")
        source = candidates[0]
        _log(f"[DBG-003] Copying workflow {source} to staging area")
        shutil.copy2(source, dest)
        return dest

    _log("[DBG-905] Component must live under actions/ or workflows/")
    raise SystemExit(1)


def include_repo_workflows(staging_root: Path) -> None:
    """
    INTENT: Copy .github/workflows/*.yml into staging so repo pipelines are policy-checked.
    INPUT: staging_root - Checkov scan root directory.
    OUTPUT: None.
    SIDE_EFFECTS: copies workflow files into staging_root/.github/workflows/.
    """
    repo_wf_dir = Path(".github/workflows")
    if not repo_wf_dir.is_dir():
        _log("[DBG-906] No .github/workflows directory; skipping repo workflow staging")
        return

    dest_dir = staging_root / ".github" / "workflows"
    dest_dir.mkdir(parents=True, exist_ok=True)
    copied = 0
    for pattern in ("*.yml", "*.yaml"):
        for wf_file in sorted(repo_wf_dir.glob(pattern)):
            dest = dest_dir / f"spvs-repo-{wf_file.name}"
            shutil.copy2(wf_file, dest)
            copied += 1
            _log(f"[DBG-005] Staged repo workflow {wf_file} -> {dest}")
    if copied == 0:
        _log("[DBG-907] No repo workflow files found to stage")


def stage_repo_workflows_only(staging_root: Path) -> Path:
    """
    INTENT: Stage only .github/workflows for Checkov when no component changed.
    INPUT: staging_root - Checkov scan root directory.
    OUTPUT: Path to staging workflows directory.
    SIDE_EFFECTS: creates staging_root/.github/workflows/ with copied repo workflows.
    """
    github_dir = staging_root / ".github"
    if github_dir.exists():
        shutil.rmtree(github_dir)
    include_repo_workflows(staging_root)
    dest_dir = staging_root / ".github" / "workflows"
    if not dest_dir.is_dir() or not any(dest_dir.iterdir()):
        _log("[DBG-908] No repo workflows staged for repo-workflows-only scan")
        raise SystemExit(1)
    return dest_dir


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    """
    INTENT: Parse CLI arguments for staging script.
    INPUT: argv - optional argument vector override.
    OUTPUT: argparse.Namespace with parsed values.
    SIDE_EFFECTS: none
    """
    parser = argparse.ArgumentParser(description="Stage component YAML for Checkov github_actions scans")
    parser.add_argument("--component-path", help="Path to actions/... or workflows/... component")
    parser.add_argument(
        "--staging-root",
        default=".checkov-staging",
        help="Directory where .github/workflows will be created (default: .checkov-staging)",
    )
    parser.add_argument(
        "--include-repo-workflows",
        action="store_true",
        help="Also stage .github/workflows/*.yml (e.g. release-manager.yml) for policy checks",
    )
    parser.add_argument(
        "--repo-workflows-only",
        action="store_true",
        help="Stage only .github/workflows/*.yml (no component); for pre-commit repo workflow edits",
    )
    args = parser.parse_args(argv)
    if args.repo_workflows_only:
        if args.component_path:
            parser.error("--repo-workflows-only cannot be combined with --component-path")
    elif not args.component_path:
        parser.error("--component-path is required unless --repo-workflows-only is set")
    return args


def main(argv: list[str] | None = None) -> None:
    """
    INTENT: CLI entrypoint for staging components before Checkov execution.
    INPUT: argv - optional argument vector override.
    OUTPUT: None; exits 0 on success.
    SIDE_EFFECTS: writes staged workflow files.
    """
    _log("[DBG-000] Starting component staging for Checkov")
    args = parse_args(argv)
    staging_root = Path(args.staging_root)

    if args.repo_workflows_only:
        staged = stage_repo_workflows_only(staging_root)
        _log(f"[DBG-004] Staged repo workflows ready: {staged}")
        print(staged)
        return

    component_path = Path(args.component_path)
    staged_file = stage_component(component_path, staging_root)
    if args.include_repo_workflows:
        include_repo_workflows(staging_root)
    _log(f"[DBG-004] Staged workflow ready: {staged_file}")
    print(staged_file)


if __name__ == "__main__":
    main(sys.argv[1:])
