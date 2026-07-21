#!/usr/bin/env bash
# =============================================================================
# FILE_NAME: run_tests.sh
# DESCRIPTION: Run SPVS Conftest policy tests and repository scan.
# VERSION: 2.2.0
# EXIT_CODES/SIGNALS: 0 pass, 1 failure
# AUTHORS: DevOps Team
# =============================================================================
set -euo pipefail

PROJECT_PREFIX="[POLICY-TESTS]"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT}"

CONFTEST_BIN="${CONFTEST_BIN:-conftest}"
POLICY_LIB="${ROOT}/policies/conftest/github_actions/lib"
POLICY_WORKFLOW="${ROOT}/policies/conftest/github_actions/workflow"
POLICY_COMPOSITE="${ROOT}/policies/conftest/github_actions/composite"
RUNNER="${ROOT}/policies/scripts/spvs_conftest_run.sh"

if ! command -v "${CONFTEST_BIN}" &>/dev/null; then
    echo "${PROJECT_PREFIX} ERROR: conftest not found. Run: bash policies/scripts/install_hooks.sh" >&2
    exit 1
fi

if [[ ! -f "${RUNNER}" ]]; then
    echo "${PROJECT_PREFIX} ERROR: missing ${RUNNER}" >&2
    exit 1
fi

# shellcheck disable=SC1090,SC1091
source "${RUNNER}"

export CONFTEST_BIN

echo "${PROJECT_PREFIX} Running conftest verify (workflow policies)..."
"${CONFTEST_BIN}" verify -p "${POLICY_WORKFLOW}" -p "${POLICY_LIB}"

echo "${PROJECT_PREFIX} Running conftest verify (composite policies)..."
"${CONFTEST_BIN}" verify -p "${POLICY_COMPOSITE}" -p "${POLICY_LIB}"

WORKFLOW_FILES=()
COMPOSITE_FILES=()

while IFS= read -r -d '' file; do
    rel="${file#./}"
    case "${rel}" in
        actions/*/*/action.yml | actions/*/*/action.yaml | .github/actions/*/action.yml | .github/actions/*/action.yaml)
            COMPOSITE_FILES+=("${file}")
            ;;
        workflows/*/*/workflow.yml | workflows/*/*/workflow.yaml | .github/workflows/*.yml | .github/workflows/*.yaml)
            WORKFLOW_FILES+=("${file}")
            ;;
    esac
done < <(find actions workflows .github/workflows .github/actions -type f \( -name '*.yml' -o -name '*.yaml' \) -print0 2>/dev/null)

echo "${PROJECT_PREFIX} Running repository SPVS scan (${#WORKFLOW_FILES[@]} workflow, ${#COMPOSITE_FILES[@]} composite)..."
if [[ ${#WORKFLOW_FILES[@]} -gt 0 ]]; then
    echo "${PROJECT_PREFIX} Workflow files:"
    printf '  - %s\n' "${WORKFLOW_FILES[@]}"
    spvs_conftest_test workflow "${POLICY_WORKFLOW}" "${POLICY_LIB}" "${WORKFLOW_FILES[@]}"
fi
if [[ ${#COMPOSITE_FILES[@]} -gt 0 ]]; then
    echo "${PROJECT_PREFIX} Composite action files:"
    printf '  - %s\n' "${COMPOSITE_FILES[@]}"
    spvs_conftest_test composite "${POLICY_COMPOSITE}" "${POLICY_LIB}" "${COMPOSITE_FILES[@]}"
fi

if [[ -f "${ROOT}/policies/tests/test_conftest_env_skip.sh" ]]; then
    bash "${ROOT}/policies/tests/test_conftest_env_skip.sh"
fi

if [[ -f "${ROOT}/policies/tests/test_commit_message_lib.sh" && -f "${ROOT}/policies/scripts/commit_message_lib.sh" ]]; then
    bash "${ROOT}/policies/tests/test_commit_message_lib.sh"
fi

echo "${PROJECT_PREFIX} All SPVS policy tests passed"
