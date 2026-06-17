#!/usr/bin/env bash
# =============================================================================
# FILE_NAME: run_spvs_gha.sh
# DESCRIPTION: Pre-commit hook — Conftest SPVS scan on changed GHA paths.
# VERSION: 2.0.0
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
for file in "$@"; do
    case "${file}" in
        actions/*/*/* | actions/*/*)
            scan_dirs["actions"]=1
            ;;
        workflows/*/*/* | workflows/*/*)
            scan_dirs["workflows"]=1
            ;;
        .github/workflows/*)
            scan_dirs[".github/workflows"]=1
            ;;
        .github/actions/*)
            scan_dirs[".github/actions"]=1
            ;;
        policies/conftest/*)
            scan_dirs["actions"]=1
            scan_dirs["workflows"]=1
            scan_dirs[".github/workflows"]=1
            scan_dirs[".github/actions"]=1
            ;;
    esac
done

if [[ ${#scan_dirs[@]} -eq 0 ]]; then
    exit 0
fi

args=()
for dir in "${!scan_dirs[@]}"; do
    args+=(-d "${dir}")
done

export CONFTEST_BIN
exec bash "${repo_root}/policies/scripts/conftest-gha.sh" "${args[@]}"
