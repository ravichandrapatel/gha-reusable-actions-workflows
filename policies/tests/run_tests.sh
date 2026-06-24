#!/usr/bin/env bash
# =============================================================================
# FILE_NAME: run_tests.sh
# DESCRIPTION: Run SPVS Conftest policy tests and repository scan.
# VERSION: 2.0.0
# EXIT_CODES/SIGNALS: 0 pass, 1 failure
# AUTHORS: DevOps Team
# =============================================================================
set -euo pipefail

PROJECT_PREFIX="[POLICY-TESTS]"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT}"

CONFTEST_BIN="${CONFTEST_BIN:-conftest}"
if ! command -v "${CONFTEST_BIN}" &>/dev/null; then
    echo "${PROJECT_PREFIX} ERROR: conftest not found. Run: bash policies/scripts/install_hooks.sh" >&2
    exit 1
fi

export CONFTEST_BIN

echo "${PROJECT_PREFIX} Running conftest verify (workflow policies)..."
"${CONFTEST_BIN}" verify -p "${ROOT}/policies/conftest/github_actions/workflow"

echo "${PROJECT_PREFIX} Running conftest verify (composite policies)..."
"${CONFTEST_BIN}" verify -p "${ROOT}/policies/conftest/github_actions/composite"

echo "${PROJECT_PREFIX} Running repository SPVS scan..."
bash "${ROOT}/policies/scripts/conftest-gha.sh"

if [[ -f "${ROOT}/policies/tests/test_conftest_inline_skip.sh" ]]; then
    bash "${ROOT}/policies/tests/test_conftest_inline_skip.sh"
fi

if [[ -f "${ROOT}/policies/tests/test_commit_message_lib.sh" && -f "${ROOT}/policies/scripts/commit_message_lib.sh" ]]; then
    bash "${ROOT}/policies/tests/test_commit_message_lib.sh"
fi

echo "${PROJECT_PREFIX} All SPVS policy tests passed"
