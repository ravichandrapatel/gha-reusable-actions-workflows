#!/usr/bin/env bash
# =============================================================================
# FILE_NAME: pre_commit_spvs_wrapper.sh
# DESCRIPTION: Pre-commit entry wrapper — sources .env so hook PATH includes venv/pipx tools.
# VERSION: 1.0.0
# EXIT_CODES/SIGNALS: Delegates to pre_commit_spvs.sh (0 pass, 1 fail, 2 env error)
# AUTHORS: DevOps Team
# =============================================================================
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
ENV_FILE="${REPO_ROOT}/.env"

if [[ -f "${ENV_FILE}" ]]; then
  # shellcheck disable=SC1091
  source "${ENV_FILE}"
fi

exec bash "${REPO_ROOT}/policies/scripts/pre_commit_spvs.sh" "$@"
