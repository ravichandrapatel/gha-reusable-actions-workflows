#!/usr/bin/env bash
# =============================================================================
# FILE_NAME: run_tests.sh
# DESCRIPTION: Run all shell-based policy/pre-commit unit tests.
# VERSION: 1.0.0
# EXIT_CODES/SIGNALS: 0 pass, 1 failure
# AUTHORS: DevOps Team
# =============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT}"

bash policies/tests/test_pre_commit_spvs.sh
bash policies/tests/test_commit_message_lib.sh

echo "All shell policy tests passed"
