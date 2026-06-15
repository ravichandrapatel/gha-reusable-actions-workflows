#!/usr/bin/env bash
# =============================================================================
# FILE_NAME: update_checkov_cache.sh
# DESCRIPTION: Run Checkov for a component and refresh the repo-local .checkov.cache directory.
# VERSION: 1.0.0
# EXIT_CODES/SIGNALS: 0 success, 1 validation or scan failure
# AUTHORS: DevOps Team
# =============================================================================
set -euo pipefail

PROJECT_PREFIX="[SPVS-CHECKOV-CACHE]"

COMPONENT_PATH=""
INCLUDE_REPO_WORKFLOWS="false"
REPO_ROOT=""
STAGING_ROOT=""

# shellcheck disable=SC2329
_log() {
  # INTENT: Central logger with greppable debug codes.
  # INPUT: message string.
  # OUTPUT: None.
  # SIDE_EFFECTS: writes to stderr.
  printf '%s %s\n' "${PROJECT_PREFIX}" "$*" >&2
}

# shellcheck disable=SC2329
usage() {
  # INTENT: Print CLI usage.
  # INPUT: none.
  # OUTPUT: usage text on stdout.
  # SIDE_EFFECTS: none.
  cat <<'EOF'
Usage: update_checkov_cache.sh --component-path PATH [--include-repo-workflows]

Refreshes .checkov.cache/ after a successful Checkov scan of the staged component.
EOF
}

# shellcheck disable=SC2329
require_command() {
  # INTENT: Fail when a required CLI is missing.
  # INPUT: command name.
  # OUTPUT: None.
  # SIDE_EFFECTS: exits 1 when command is not on PATH.
  local cmd="$1"
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    _log "[DBG-920] Required command not found: ${cmd}"
    exit 1
  fi
}

# shellcheck disable=SC2329
parse_args() {
  # INTENT: Parse CLI arguments into globals.
  # INPUT: script arguments.
  # OUTPUT: None.
  # SIDE_EFFECTS: sets COMPONENT_PATH and INCLUDE_REPO_WORKFLOWS.
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --component-path)
        COMPONENT_PATH="${2:-}"
        shift 2
        ;;
      --include-repo-workflows)
        INCLUDE_REPO_WORKFLOWS="true"
        shift
        ;;
      -h | --help)
        usage
        exit 0
        ;;
      *)
        _log "[DBG-910] Unknown argument: $1"
        usage >&2
        exit 1
        ;;
    esac
  done

  if [[ -z "${COMPONENT_PATH}" ]]; then
    _log "[DBG-910] --component-path is required"
    usage >&2
    exit 1
  fi
}

# shellcheck disable=SC2329
resolve_repo_root() {
  # INTENT: Resolve repository root from script location.
  # INPUT: none.
  # OUTPUT: None.
  # SIDE_EFFECTS: sets REPO_ROOT.
  REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
}

# shellcheck disable=SC2329
write_cache_metadata() {
  # INTENT: Write promote/scan metadata into .checkov.cache.
  # INPUT: none (uses globals).
  # OUTPUT: None.
  # SIDE_EFFECTS: writes metadata.env under .checkov.cache.
  local cache_root="${REPO_ROOT}/.checkov.cache"
  local checkov_version
  checkov_version="$(checkov --version 2>/dev/null | head -n1 || true)"

  mkdir -p "${cache_root}"
  cat > "${cache_root}/metadata.env" <<EOF
CHECKOV_VERSION=${checkov_version}
UPDATED_AT=$(date -u +%Y-%m-%dT%H:%M:%SZ)
COMPONENT_PATH=${COMPONENT_PATH}
INCLUDE_REPO_WORKFLOWS=${INCLUDE_REPO_WORKFLOWS}
EOF
}

# shellcheck disable=SC2329
main() {
  # INTENT: Stage component, run Checkov, and refresh .checkov.cache.
  # INPUT: script arguments.
  # OUTPUT: None.
  # SIDE_EFFECTS: writes .checkov.cache; runs checkov; removes temp staging dir.
  local cache_root
  local -a stage_cmd=()

  parse_args "$@"
  resolve_repo_root
  require_command checkov
  require_command bash

  if [[ ! -d "${REPO_ROOT}/${COMPONENT_PATH}" ]]; then
    _log "[DBG-910] Component path does not exist: ${COMPONENT_PATH}"
    exit 1
  fi

  cache_root="${REPO_ROOT}/.checkov.cache"
  STAGING_ROOT="$(mktemp -d "${REPO_ROOT}/.checkov-staging-cache.XXXXXX")"

  # CHECKPOINT: promote refreshes repo-local Checkov cache under .checkov.cache (gitignored except forced promote commit).
  cleanup() {
    rm -rf "${STAGING_ROOT}"
  }
  trap cleanup EXIT

  mkdir -p "${cache_root}/ckv"
  export CKV_CACHE_DIR="${cache_root}/ckv"

  stage_cmd=(
    bash "${REPO_ROOT}/policies/scripts/stage_component.sh"
    --component-path "${COMPONENT_PATH}"
    --staging-root "${STAGING_ROOT}"
  )
  if [[ "${INCLUDE_REPO_WORKFLOWS}" == "true" ]]; then
    stage_cmd+=(--include-repo-workflows)
  fi

  _log "[DBG-000] Staging component for Checkov cache refresh: ${COMPONENT_PATH}"
  "${stage_cmd[@]}"

  _log "[DBG-001] Running Checkov scan"
  checkov -d "${STAGING_ROOT}" \
    --config-file "${REPO_ROOT}/.checkov.yaml" \
    --framework github_actions \
    --create-baseline

  if [[ -f "${STAGING_ROOT}/.checkov.baseline" ]]; then
    cp "${STAGING_ROOT}/.checkov.baseline" "${cache_root}/.checkov.baseline"
    _log "[DBG-002] Updated baseline in ${cache_root}/.checkov.baseline"
  fi

  write_cache_metadata
  _log "[DBG-003] Checkov cache refreshed at ${cache_root}"
}

main "$@"
