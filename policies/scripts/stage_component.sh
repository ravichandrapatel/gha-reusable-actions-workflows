#!/usr/bin/env bash
# =============================================================================
# FILE_NAME: stage_component.sh
# DESCRIPTION: Stage component workflows/actions under .github/workflows for Checkov.
# VERSION: 1.1.0
# EXIT_CODES/SIGNALS: 0 success, 1 validation or I/O failure
# AUTHORS: DevOps Team
# =============================================================================
set -euo pipefail

PROJECT_PREFIX="[SPVS-CHECKOV-STAGE]"
SPVS_HOOK_VERBOSE="${SPVS_HOOK_VERBOSE:-0}"

_log() {
  [[ "${SPVS_HOOK_VERBOSE}" == "1" ]] || return 0
  printf '%s %s\n' "${PROJECT_PREFIX}" "$*" >&2
}

_log_err() {
  printf '%s %s\n' "${PROJECT_PREFIX}" "$*" >&2
}

usage() {
  cat <<'EOF'
Usage: stage_component.sh --staging-root PATH [--component-path PATH | --repo-workflows-only] [--include-repo-workflows]
EOF
}

require_command() {
  local cmd="$1"
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    _log_err "[DBG-920] Required command not found: ${cmd}"
    exit 1
  fi
}

ensure_staging_workflows_dir() {
  local staging_root="$1"
  local reset="$2"
  local workflows_dir="${staging_root}/.github/workflows"

  if [[ "${reset}" == "true" ]] && [[ -d "${staging_root}/.github" ]]; then
    rm -rf "${staging_root}/.github"
  fi
  mkdir -p "${workflows_dir}"
  printf '%s' "${workflows_dir}"
}

reset_staging_workflows_dir() {
  local staging_root="$1"
  ensure_staging_workflows_dir "${staging_root}" "true"
}

include_repo_workflows() {
  local staging_root="$1"
  local repo_wf_dir=".github/workflows"
  local dest_dir="${staging_root}/.github/workflows"
  local copied=0
  local wf_file

  if [[ ! -d "${repo_wf_dir}" ]]; then
    _log "[DBG-906] No .github/workflows directory; skipping repo workflow staging"
    return 0
  fi

  mkdir -p "${dest_dir}"
  shopt -s nullglob
  for wf_file in "${repo_wf_dir}"/*.{yml,yaml}; do
    cp -f "${wf_file}" "${dest_dir}/spvs-repo-$(basename "${wf_file}")"
    copied=$((copied + 1))
    _log "[DBG-005] Staged repo workflow ${wf_file} -> ${dest_dir}/spvs-repo-$(basename "${wf_file}")"
  done
  shopt -u nullglob

  if [[ "${copied}" -eq 0 ]]; then
    _log "[DBG-907] No repo workflow files found to stage"
  fi
}

synthesize_workflow_from_action() {
  local action_file="$1"
  local component_name="$2"
  local dest="$3"

  require_command yq

  if ! yq eval '.runs.using' "${action_file}" | grep -qx 'composite'; then
    _log_err "[DBG-915] Only composite actions are supported for staging"
    exit 1
  fi

  if [[ "$(yq eval '.runs.steps | length' "${action_file}")" == "0" ]]; then
    _log_err "[DBG-916] action.yml runs.steps must not be empty"
    exit 1
  fi

  _log "[DBG-002] Synthesizing workflow from ${action_file}"
  yq eval -n \
    '{
      "name": "SPVS Checkov Staging - '"${component_name}"'",
      "on": {"workflow_call": {}},
      "permissions": {"contents": "read"},
      "jobs": {
        "spvs_staged_action": {
          "name": "Staged Composite Action Steps",
          "runs-on": "ubuntu-latest",
          "permissions": {"contents": "read"},
          "steps": load("'"${action_file}"'").runs.steps
        }
      }
    }' > "${dest}"
}

stage_component() {
  local component_path="$1"
  local staging_root="$2"
  local append="${3:-false}"
  local workflows_dir dest component_name path_str action_file source candidates reset="true"

  if [[ ! -d "${component_path}" ]]; then
    _log_err "[DBG-901] Component path does not exist: ${component_path}"
    exit 1
  fi

  if [[ "${append}" == "true" ]]; then
    reset="false"
  fi
  workflows_dir="$(ensure_staging_workflows_dir "${staging_root}" "${reset}")"
  component_name="$(basename "${component_path}")"
  dest="${workflows_dir}/spvs-staged-${component_name}.yml"
  path_str="${component_path//\\//}"

  if [[ "${path_str}" == actions/* ]] || [[ "${path_str}" == *"/actions/"* ]]; then
    action_file="${component_path}/action.yml"
    if [[ ! -f "${action_file}" ]]; then
      action_file="${component_path}/action.yaml"
    fi
    if [[ ! -f "${action_file}" ]]; then
      _log_err "[DBG-902] No action.yml found in ${component_path}"
      exit 1
    fi
    synthesize_workflow_from_action "${action_file}" "${component_name}" "${dest}"
    printf '%s' "${dest}"
    return 0
  fi

  if [[ "${path_str}" == workflows/* ]] || [[ "${path_str}" == *"/workflows/"* ]]; then
    shopt -s nullglob
    candidates=("${component_path}"/*.yml "${component_path}"/*.yaml)
    shopt -u nullglob
    if [[ ${#candidates[@]} -eq 0 ]]; then
      _log_err "[DBG-903] No workflow YAML found in ${component_path}"
      exit 1
    fi
    if [[ ${#candidates[@]} -gt 1 ]]; then
      _log "[DBG-904] Multiple workflow files found; using ${candidates[0]}"
    fi
    source="${candidates[0]}"
    _log "[DBG-003] Copying workflow ${source} to staging area"
    cp -f "${source}" "${dest}"
    printf '%s' "${dest}"
    return 0
  fi

  _log_err "[DBG-905] Component must live under actions/ or workflows/"
  exit 1
}

stage_repo_workflows_only() {
  local staging_root="$1"
  local dest_dir

  reset_staging_workflows_dir "${staging_root}" >/dev/null
  include_repo_workflows "${staging_root}"
  dest_dir="${staging_root}/.github/workflows"
  if [[ ! -d "${dest_dir}" ]]; then
    _log_err "[DBG-908] No repo workflows staged for repo-workflows-only scan"
    exit 1
  fi
  shopt -s nullglob
  local staged_files=("${dest_dir}"/*)
  shopt -u nullglob
  if [[ ${#staged_files[@]} -eq 0 ]]; then
    _log_err "[DBG-908] No repo workflows staged for repo-workflows-only scan"
    exit 1
  fi
  printf '%s' "${dest_dir}"
}

main() {
  local component_path=""
  local staging_root=".checkov-staging"
  local include_repo="false"
  local repo_only="false"
  local append="false"
  local staged=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --component-path)
        component_path="${2:-}"
        shift 2
        ;;
      --staging-root)
        staging_root="${2:-}"
        shift 2
        ;;
      --include-repo-workflows)
        include_repo="true"
        shift
        ;;
      --repo-workflows-only)
        repo_only="true"
        shift
        ;;
      --append)
        append="true"
        shift
        ;;
      -h | --help)
        usage
        exit 0
        ;;
      *)
        _log_err "[DBG-909] Unknown argument: $1"
        usage
        exit 1
        ;;
    esac
  done

  _log "[DBG-000] Starting component staging for Checkov"

  if [[ "${repo_only}" == "true" ]]; then
    if [[ -n "${component_path}" ]]; then
      _log_err "[DBG-914] --repo-workflows-only cannot be combined with --component-path"
      exit 1
    fi
    staged="$(stage_repo_workflows_only "${staging_root}")"
    _log "[DBG-004] Staged repo workflows ready: ${staged}"
    printf '%s\n' "${staged}"
    exit 0
  fi

  if [[ -z "${component_path}" ]]; then
    if [[ "${include_repo}" == "true" && "${append}" == "true" ]]; then
      include_repo_workflows "${staging_root}"
      _log "[DBG-004] Staged repo workflows ready: ${staging_root}/.github/workflows"
      printf '%s\n' "${staging_root}/.github/workflows"
      exit 0
    fi
    _log_err "[DBG-913] --component-path is required unless --repo-workflows-only is set"
    usage
    exit 1
  fi

  staged="$(stage_component "${component_path}" "${staging_root}" "${append}")"
  if [[ "${include_repo}" == "true" ]]; then
    include_repo_workflows "${staging_root}"
  fi
  _log "[DBG-004] Staged workflow ready: ${staged}"
  printf '%s\n' "${staged}"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
