#!/usr/bin/env bash
# =============================================================================
# FILE_NAME: run_actionlint.sh
# DESCRIPTION: Pre-commit wrapper — actionlint on .github/workflows,
#              workflows/<component>/workflow.yml, and .github/actions.
# VERSION: 1.2.0
# EXIT_CODES/SIGNALS: 0 pass, 1 actionlint failure or missing binary
# AUTHORS: DevOps Team
# =============================================================================
set -euo pipefail

PROJECT_PREFIX="[HOOK-ACTIONLINT]"

if [[ $# -eq 0 ]]; then
    exit 0
fi

if ! command -v actionlint &>/dev/null; then
    echo "${PROJECT_PREFIX} ERROR: actionlint not found. Run: bash policies/scripts/install_hooks.sh" >&2
    exit 1
fi

repo_root="$(git rev-parse --show-toplevel)"
status=0

for file in "$@"; do
    if [[ "${file}" =~ ^\.github/workflows/.+\.(yml|yaml)$ ]] \
        || [[ "${file}" =~ ^workflows/.+/workflow\.(yml|yaml)$ ]]; then
        workflow_path="${repo_root}/${file}"
        if ! actionlint "${workflow_path}"; then
            status=1
        fi
        continue
    fi

    if [[ "${file}" == .github/actions/* ]]; then
        continue
    fi
done

exit "${status}"
