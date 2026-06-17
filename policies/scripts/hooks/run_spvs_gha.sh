#!/usr/bin/env bash
# =============================================================================
# FILE_NAME: run_spvs_gha.sh
# DESCRIPTION: Pre-commit hook — Conftest SPVS scan on changed GHA paths.
# VERSION: 2.1.0
# EXIT_CODES/SIGNALS: 0 pass, 1 findings, 2 environment error
# AUTHORS: DevOps Team
# =============================================================================
set -euo pipefail

PROJECT_PREFIX="[HOOK-SPVS-GHA]"

if [[ $# -eq 0 ]]; then
    exit 0
fi

repo_root="$(git rev-parse --show-toplevel)"
cd "${repo_root}"

CONFTEST_BIN="${CONFTEST_BIN:-conftest}"
if ! command -v "${CONFTEST_BIN}" &>/dev/null; then
    echo "${PROJECT_PREFIX} ERROR: conftest not found. Run: bash policies/scripts/install_hooks.sh" >&2
    exit 2
fi

declare -A scan_dirs=()
declare -a scan_files=()

for file in "$@"; do
    case "${file}" in
        policies/conftest/*)
            scan_dirs["actions"]=1
            scan_dirs["workflows"]=1
            scan_dirs[".github/workflows"]=1
            scan_dirs[".github/actions"]=1
            ;;
        actions/*/*/action.yml | actions/*/*/action.yaml)
            scan_files+=("${file}")
            ;;
        workflows/*/*/workflow.yml | workflows/*/*/workflow.yaml)
            scan_files+=("${file}")
            ;;
        .github/workflows/*.yml | .github/workflows/*.yaml)
            scan_files+=("${file}")
            ;;
        .github/actions/*/action.yml | .github/actions/*/action.yaml)
            scan_files+=("${file}")
            ;;
    esac
done

args=()
for dir in "${!scan_dirs[@]}"; do
    args+=(-d "${dir}")
done
for file in "${scan_files[@]}"; do
    args+=(-f "${file}")
done

if [[ ${#args[@]} -eq 0 ]]; then
    exit 0
fi

export CONFTEST_BIN
exec bash "${repo_root}/policies/scripts/conftest-gha.sh" "${args[@]}"
