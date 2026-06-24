#!/usr/bin/env bash
# =============================================================================
# FILE_NAME: run_spvs_gha.sh
# DESCRIPTION: Pre-commit hook — Conftest SPVS scan on changed GHA paths.
# VERSION: 3.1.0
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
POLICY_LIB="${repo_root}/policies/conftest/github_actions/lib"
POLICY_WORKFLOW="${repo_root}/policies/conftest/github_actions/workflow"
POLICY_COMPOSITE="${repo_root}/policies/conftest/github_actions/composite"
RUNNER="${repo_root}/policies/scripts/spvs_conftest_run.sh"

if ! command -v "${CONFTEST_BIN}" &>/dev/null; then
    echo "${PROJECT_PREFIX} ERROR: conftest not found. Run: bash policies/scripts/install_hooks.sh" >&2
    exit 2
fi

if [[ ! -f "${RUNNER}" ]]; then
    echo "${PROJECT_PREFIX} ERROR: missing ${RUNNER}" >&2
    exit 2
fi

# shellcheck disable=SC1090,SC1091
source "${RUNNER}"

declare -A scan_dirs=()
declare -a workflow_files=()
declare -a composite_files=()

spvs_queue_file() {
    local file="$1"
    case "${file}" in
        */action.yml | */action.yaml)
            composite_files+=("${file}")
            ;;
        *)
            workflow_files+=("${file}")
            ;;
    esac
}

for file in "$@"; do
    case "${file}" in
        policies/conftest/*)
            scan_dirs["actions"]=1
            scan_dirs["workflows"]=1
            scan_dirs[".github/workflows"]=1
            scan_dirs[".github/actions"]=1
            ;;
        actions/*/*/action.yml | actions/*/*/action.yaml)
            spvs_queue_file "${file}"
            ;;
        workflows/*/*/workflow.yml | workflows/*/*/workflow.yaml)
            spvs_queue_file "${file}"
            ;;
        .github/workflows/*.yml | .github/workflows/*.yaml)
            spvs_queue_file "${file}"
            ;;
        .github/actions/*/action.yml | .github/actions/*/action.yaml)
            spvs_queue_file "${file}"
            ;;
    esac
done

for dir in "${!scan_dirs[@]}"; do
    [[ -d "${dir}" ]] || continue
    while IFS= read -r -d '' file; do
        rel="${file#./}"
        case "${rel}" in
            actions/*/*/action.y*ml | .github/actions/*/action.y*ml)
                composite_files+=("${file}")
                ;;
            workflows/*/*/workflow.y*ml | .github/workflows/*.y*ml)
                workflow_files+=("${file}")
                ;;
        esac
    done < <(find "${dir}" -type f \( -name '*.yml' -o -name '*.yaml' \) -print0 2>/dev/null)
done

status=0

if [[ ${#workflow_files[@]} -gt 0 ]]; then
    if ! spvs_conftest_test workflow "${POLICY_WORKFLOW}" "${POLICY_LIB}" "${workflow_files[@]}"; then
        status=1
    fi
fi

if [[ ${#composite_files[@]} -gt 0 ]]; then
    if ! spvs_conftest_test composite "${POLICY_COMPOSITE}" "${POLICY_LIB}" "${composite_files[@]}"; then
        status=1
    fi
fi

if [[ ${#workflow_files[@]} -eq 0 && ${#composite_files[@]} -eq 0 ]]; then
    exit 0
fi

exit "${status}"
