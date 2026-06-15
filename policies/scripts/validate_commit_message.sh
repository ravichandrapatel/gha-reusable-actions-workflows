#!/usr/bin/env bash
# =============================================================================
# FILE_NAME: validate_commit_message.sh
# DESCRIPTION: commit-msg hook — validate ticket prefix and conventional commit type.
# VERSION: 1.0.0
# EXIT_CODES/SIGNALS: 0 valid, 1 invalid subject, 2 usage error
# AUTHORS: DevOps Team
# =============================================================================
set -euo pipefail

PROJECT_PREFIX="[SPVS-COMMIT-MSG]"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=commit_message_lib.sh
source "${SCRIPT_DIR}/commit_message_lib.sh"

_log() {
  printf '%s %s\n' "${PROJECT_PREFIX}" "$*"
}

main() {
  local msg_file="${1:-}"
  local subject=""

  if [[ -z "${msg_file}" ]] || [[ ! -f "${msg_file}" ]]; then
    _log "[DBG-910] Usage: validate_commit_message.sh <commit-msg-file>"
    exit 2
  fi

  # _log("[T-01] Validating commit message")
  _log "[DBG-000] Validating commit message"
  subject="$(grep -Ev '^[[:space:]]*(#|$)' "${msg_file}" | head -n1 || true)"

  if commit_msg_validate_subject "${subject}"; then
    _log "[DBG-001] Commit message valid"
    exit 0
  fi

  _log "[DBG-901] Commit message rejected"
  printf '%s Expected format: %s\n' "${PROJECT_PREFIX}" "$(commit_msg_format_hint)" >&2
  exit 1
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
