#!/usr/bin/env bash
# =============================================================================
# FILE_NAME: run_checkov_spvs.sh
# DESCRIPTION: Run Checkov SPVS scan with inline skip comment support.
# VERSION: 1.0.0
# EXIT_CODES/SIGNALS: 0 pass, 1 findings, 2 usage/tool error
# AUTHORS: DevOps Team
# =============================================================================
set -euo pipefail

PROJECT_PREFIX="[SPVS-CHECKOV]"
SPVS_HOOK_VERBOSE="${SPVS_HOOK_VERBOSE:-0}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=checkov_inline_skip_lib.sh
source "${SCRIPT_DIR}/checkov_inline_skip_lib.sh"

usage() {
  printf '%s Usage: run_checkov_spvs.sh --staging-root DIR [--repo-root DIR]\n' "${PROJECT_PREFIX}" >&2
  exit 2
}

REPO_ROOT=""
STAGING_ROOT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --staging-root)
      STAGING_ROOT="${2:-}"
      shift 2
      ;;
    --repo-root)
      REPO_ROOT="${2:-}"
      shift 2
      ;;
    -h | --help)
      usage
      ;;
    *)
      printf '%s [DBG-910] Unknown argument: %s\n' "${PROJECT_PREFIX}" "$1" >&2
      usage
      ;;
  esac
done

if [[ -z "${STAGING_ROOT}" ]] || [[ ! -d "${STAGING_ROOT}" ]]; then
  printf '%s [DBG-910] --staging-root must point to an existing directory\n' "${PROJECT_PREFIX}" >&2
  exit 2
fi

if [[ -z "${REPO_ROOT}" ]]; then
  REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
fi

if [[ ! -f "${REPO_ROOT}/.checkov.yaml" ]]; then
  printf '%s [DBG-910] Missing .checkov.yaml under %s\n' "${PROJECT_PREFIX}" "${REPO_ROOT}" >&2
  exit 2
fi

spvs_run_checkov_with_inline_skips "${STAGING_ROOT}" "${REPO_ROOT}" "${SPVS_HOOK_VERBOSE}"
