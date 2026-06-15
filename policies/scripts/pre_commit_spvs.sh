#!/usr/bin/env bash
# =============================================================================
# FILE_NAME: pre_commit_spvs.sh
# DESCRIPTION: Pre-commit hook — Checkov SPVS, Shellcheck, Actionlint, and Bandit.
# VERSION: 1.1.0
# EXIT_CODES/SIGNALS: 0 pass, 1 scan failure, 2 missing tool or environment error
# AUTHORS: DevOps Team
# =============================================================================
set -euo pipefail

PROJECT_PREFIX="[SPVS-PRE-COMMIT]"
SPVS_HOOK_VERBOSE="${SPVS_HOOK_VERBOSE:-0}"

ACTIONLINT_VERSION="1.7.7"
ACTIONLINT_SHA256="023070a287cd8cccd71515fedc843f1985bf96c436b7effaecce67290e7e0757"
REPO_ROOT=""
CHANGED_FILES=()
RESOLVED_COMPONENTS=()
SHELL_FILES=()
PYTHON_FILES=()
WORKFLOW_FILES=()

# shellcheck disable=SC2329
_log() {
  # INTENT: Verbose operational logger (suppressed unless SPVS_HOOK_VERBOSE=1).
  # INPUT: message string.
  # OUTPUT: None.
  # SIDE_EFFECTS: writes to stdout when verbose.
  [[ "${SPVS_HOOK_VERBOSE}" == "1" ]] || return 0
  printf '%s %s\n' "${PROJECT_PREFIX}" "$*"
}

# shellcheck disable=SC2329
_log_err() {
  # INTENT: Always-on error logger for hook failures.
  # INPUT: message string.
  # OUTPUT: None.
  # SIDE_EFFECTS: writes to stderr.
  printf '%s %s\n' "${PROJECT_PREFIX}" "$*" >&2
}

# shellcheck disable=SC2329
require_command() {
  # INTENT: Fail fast when a required security CLI is missing.
  # INPUT: command name.
  # OUTPUT: None.
  # SIDE_EFFECTS: exits 2 when command is not on PATH.
  local cmd="$1"
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    _log_err "[DBG-920] Required command not found: ${cmd}"
    exit 2
  fi
}

# shellcheck disable=SC2329
normalize_path() {
  # INTENT: Normalize pre-commit file paths to repo-relative forward-slash form.
  # INPUT: raw path string.
  # OUTPUT: normalized path printed to stdout.
  # SIDE_EFFECTS: none.
  local raw="$1"
  raw="${raw#./}"
  raw="${raw//\\//}"
  printf '%s' "${raw}"
}

# shellcheck disable=SC2329
component_from_path() {
  # INTENT: Map a changed file to its actions/*/* or workflows/*/* component root.
  # INPUT: normalized repo-relative path.
  # OUTPUT: component path or empty string.
  # SIDE_EFFECTS: none.
  local path="$1"
  if [[ "${path}" =~ ^actions/[^/]+/[^/]+ ]]; then
    printf '%s' "${path}" | cut -d/ -f1-3
  elif [[ "${path}" =~ ^workflows/[^/]+/[^/]+ ]]; then
    printf '%s' "${path}" | cut -d/ -f1-3
  fi
}

# shellcheck disable=SC2329
policies_changed() {
  # INTENT: Detect policy or Checkov config edits requiring full rescan.
  # INPUT: none (uses global CHANGED_FILES array).
  # OUTPUT: 0 if full rescan required, 1 otherwise.
  # SIDE_EFFECTS: none.
  local path
  for path in "${CHANGED_FILES[@]}"; do
    case "${path}" in
      .checkov.yaml | policies/scripts/stage_component.sh | policies/scripts/stage_component.py)
        return 0
        ;;
      policies/github_actions/*)
        return 0
        ;;
    esac
  done
  return 1
}

# shellcheck disable=SC2329
repo_workflows_changed() {
  # INTENT: Detect edits under .github/workflows/.
  # INPUT: none (uses global CHANGED_FILES array).
  # OUTPUT: 0 if repo workflows changed, 1 otherwise.
  # SIDE_EFFECTS: none.
  local path
  for path in "${CHANGED_FILES[@]}"; do
    if [[ "${path}" == .github/workflows/* ]]; then
      return 0
    fi
  done
  return 1
}

# shellcheck disable=SC2329
discover_all_components() {
  # INTENT: List every actions/*/* and workflows/*/* component directory.
  # INPUT: none (uses REPO_ROOT).
  # OUTPUT: component paths printed one per line.
  # SIDE_EFFECTS: reads filesystem.
  local tree category component
  for tree in actions workflows; do
    if [[ ! -d "${REPO_ROOT}/${tree}" ]]; then
      continue
    fi
    for category in "${REPO_ROOT}/${tree}"/*; do
      [[ -d "${category}" ]] || continue
      for component in "${category}"/*; do
        [[ -d "${component}" ]] || continue
        printf '%s/%s/%s\n' "${tree}" "$(basename "${category}")" "$(basename "${component}")"
      done
    done
  done | sort -u
}

# shellcheck disable=SC2329
resolve_components() {
  # INTENT: Build unique sorted component list from changed files or full discovery.
  # INPUT: none (uses globals).
  # OUTPUT: populates RESOLVED_COMPONENTS array.
  # SIDE_EFFECTS: none.
  RESOLVED_COMPONENTS=()
  local -A seen=()
  local path component

  if policies_changed; then
    _log "[DBG-004] Policy/config change detected; resolving all components"
    while IFS= read -r component; do
      [[ -n "${component}" ]] || continue
      seen["${component}"]=1
    done < <(discover_all_components)
  else
    for path in "${CHANGED_FILES[@]}"; do
      component="$(component_from_path "${path}")"
      if [[ -n "${component}" ]]; then
        seen["${component}"]=1
      fi
    done
  fi

  for component in "${!seen[@]}"; do
    RESOLVED_COMPONENTS+=("${component}")
  done
  if [[ ${#RESOLVED_COMPONENTS[@]} -gt 0 ]]; then
    mapfile -t RESOLVED_COMPONENTS < <(printf '%s\n' "${RESOLVED_COMPONENTS[@]}" | LC_ALL=C sort -u)
  fi
}

# shellcheck disable=SC2329
ensure_actionlint() {
  # INTENT: Use actionlint from PATH or install a pinned binary under .cache/actionlint.
  # INPUT: none (uses REPO_ROOT).
  # OUTPUT: None.
  # SIDE_EFFECTS: may download actionlint; updates PATH.
  if command -v actionlint >/dev/null 2>&1; then
    return 0
  fi

  local cache_dir="${REPO_ROOT}/.cache/actionlint"
  local archive="actionlint_${ACTIONLINT_VERSION}_linux_amd64.tar.gz"
  local url="https://github.com/rhysd/actionlint/releases/download/v${ACTIONLINT_VERSION}/${archive}"
  local bin="${cache_dir}/actionlint"

  if [[ -x "${bin}" ]]; then
    export PATH="${cache_dir}:${PATH}"
    return 0
  fi

  require_command curl
  require_command tar
  require_command sha256sum

  _log "[DBG-019] Installing actionlint ${ACTIONLINT_VERSION} to ${cache_dir}"
  mkdir -p "${cache_dir}"
  curl -fsSL -o "${cache_dir}/${archive}" "${url}"
  echo "${ACTIONLINT_SHA256}  ${cache_dir}/${archive}" | sha256sum -c -
  tar xzf "${cache_dir}/${archive}" -C "${cache_dir}" actionlint
  rm -f "${cache_dir}/${archive}"
  chmod +x "${bin}"
  export PATH="${cache_dir}:${PATH}"
}

# shellcheck disable=SC2329
_glob_files_in_dir() {
  # INTENT: Print absolute paths for *.suffix files in a directory.
  # INPUT: directory path; file suffix without dot (e.g. sh, py).
  # OUTPUT: matching file paths one per line.
  # SIDE_EFFECTS: reads filesystem.
  local dir="$1"
  local suffix="$2"
  local file_path
  if [[ ! -d "${dir}" ]]; then
    return 0
  fi
  shopt -s nullglob
  for file_path in "${dir}"/*."${suffix}"; do
    if [[ -f "${file_path}" ]]; then
      printf '%s\n' "${file_path}"
    fi
  done
  shopt -u nullglob
}

# shellcheck disable=SC2329
collect_shell_scripts() {
  # INTENT: Gather shell scripts to scan with Shellcheck from changed files and components.
  # INPUT: none (uses globals).
  # OUTPUT: populates SHELL_FILES array.
  # SIDE_EFFECTS: reads filesystem.
  local -A seen=()
  local path component full_rescan=0
  SHELL_FILES=()

  _add_glob_to_seen() {
    local dir="$1"
    local suffix="$2"
    local file_path
    while IFS= read -r file_path; do
      [[ -n "${file_path}" ]] || continue
      seen["${file_path}"]=1
    done < <(_glob_files_in_dir "${dir}" "${suffix}")
  }

  if policies_changed; then
    full_rescan=1
  fi

  if [[ "${full_rescan}" -eq 1 ]]; then
    _add_glob_to_seen "${REPO_ROOT}/policies/scripts" sh
    while IFS= read -r component; do
      [[ -n "${component}" ]] || continue
      _add_glob_to_seen "${REPO_ROOT}/${component}" sh
    done < <(discover_all_components)
  else
    for path in "${CHANGED_FILES[@]}"; do
      if [[ "${path}" == *.sh ]] && [[ -f "${REPO_ROOT}/${path}" ]]; then
        seen["${REPO_ROOT}/${path}"]=1
      fi
      component="$(component_from_path "${path}")"
      if [[ -n "${component}" ]]; then
        _add_glob_to_seen "${REPO_ROOT}/${component}" sh
      fi
      if [[ "${path}" == policies/scripts/* ]]; then
        _add_glob_to_seen "${REPO_ROOT}/policies/scripts" sh
      fi
    done
  fi

  if [[ ${#seen[@]} -gt 0 ]]; then
    mapfile -t SHELL_FILES < <(printf '%s\n' "${!seen[@]}" | LC_ALL=C sort)
  fi
}

# shellcheck disable=SC2329
collect_python_files() {
  # INTENT: Gather Python files to scan with Bandit from changed files and components.
  # INPUT: none (uses globals).
  # OUTPUT: populates PYTHON_FILES array.
  # SIDE_EFFECTS: reads filesystem.
  local -A seen=()
  local path component full_rescan=0
  PYTHON_FILES=()

  _add_glob_to_seen() {
    local dir="$1"
    local suffix="$2"
    local file_path
    while IFS= read -r file_path; do
      [[ -n "${file_path}" ]] || continue
      seen["${file_path}"]=1
    done < <(_glob_files_in_dir "${dir}" "${suffix}")
  }

  if policies_changed; then
    full_rescan=1
  fi

  if [[ "${full_rescan}" -eq 1 ]]; then
    _add_glob_to_seen "${REPO_ROOT}/policies/scripts" py
    while IFS= read -r component; do
      [[ -n "${component}" ]] || continue
      _add_glob_to_seen "${REPO_ROOT}/${component}" py
    done < <(discover_all_components)
  else
    for path in "${CHANGED_FILES[@]}"; do
      if [[ "${path}" == *.py ]] && [[ -f "${REPO_ROOT}/${path}" ]]; then
        seen["${REPO_ROOT}/${path}"]=1
      fi
      component="$(component_from_path "${path}")"
      if [[ -n "${component}" ]]; then
        _add_glob_to_seen "${REPO_ROOT}/${component}" py
      fi
      if [[ "${path}" == policies/scripts/* ]]; then
        _add_glob_to_seen "${REPO_ROOT}/policies/scripts" py
      fi
    done
  fi

  if [[ ${#seen[@]} -gt 0 ]]; then
    mapfile -t PYTHON_FILES < <(printf '%s\n' "${!seen[@]}" | LC_ALL=C sort)
  fi
}

# shellcheck disable=SC2329
workflow_file_for_component() {
  # INTENT: Find the workflow YAML file inside a workflows/*/* component directory.
  # INPUT: component path relative to repo root.
  # OUTPUT: absolute workflow file path or empty.
  # SIDE_EFFECTS: reads filesystem.
  local component="$1"
  local dir="${REPO_ROOT}/${component}"
  local candidate
  if [[ ! -d "${dir}" ]]; then
    return 0
  fi
  shopt -s nullglob
  local candidates=("${dir}"/*.yml "${dir}"/*.yaml)
  shopt -u nullglob
  if [[ ${#candidates[@]} -eq 0 ]]; then
    return 0
  fi
  candidate="${candidates[0]}"
  if [[ ${#candidates[@]} -gt 1 ]]; then
    _log "[DBG-921] Multiple workflow files in ${component}; using ${candidate}"
  fi
  printf '%s' "${candidate}"
}

# shellcheck disable=SC2329
collect_workflow_files() {
  # INTENT: Gather workflow YAML files for Actionlint from changes or full rescan.
  # INPUT: none (uses globals).
  # OUTPUT: populates WORKFLOW_FILES array.
  # SIDE_EFFECTS: reads filesystem.
  local -A seen=()
  local path component wf full_rescan wf_file

  if policies_changed || repo_workflows_changed; then
    full_rescan=1
  else
    full_rescan=0
  fi

  if [[ "${full_rescan}" -eq 1 ]]; then
    shopt -s nullglob
    for wf_file in "${REPO_ROOT}"/.github/workflows/*.{yml,yaml}; do
      seen["${wf_file}"]=1
    done
    for wf_file in "${REPO_ROOT}"/workflows/*/*/*.{yml,yaml}; do
      seen["${wf_file}"]=1
    done
    shopt -u nullglob
  else
    for path in "${CHANGED_FILES[@]}"; do
      case "${path}" in
        .github/workflows/*.yml | .github/workflows/*.yaml)
          if [[ -f "${REPO_ROOT}/${path}" ]]; then
            seen["${REPO_ROOT}/${path}"]=1
          fi
          ;;
        workflows/*/*/*.yml | workflows/*/*/*.yaml)
          if [[ -f "${REPO_ROOT}/${path}" ]]; then
            seen["${REPO_ROOT}/${path}"]=1
          fi
          ;;
      esac
      component="$(component_from_path "${path}")"
      if [[ "${component}" == workflows/* ]]; then
        wf="$(workflow_file_for_component "${component}")"
        if [[ -n "${wf}" ]]; then
          seen["${wf}"]=1
        fi
      fi
    done
  fi

  WORKFLOW_FILES=()
  if [[ ${#seen[@]} -gt 0 ]]; then
    mapfile -t WORKFLOW_FILES < <(printf '%s\n' "${!seen[@]}" | LC_ALL=C sort)
  fi
}

# shellcheck disable=SC2329
run_shellcheck() {
  # INTENT: Run Shellcheck on changed shell scripts.
  # INPUT: none (uses SHELL_FILES).
  # OUTPUT: None.
  # SIDE_EFFECTS: runs shellcheck; exits 1 on findings.
  local script
  if [[ ${#SHELL_FILES[@]} -eq 0 ]]; then
    _log "[DBG-010] No shell scripts to scan; skipping Shellcheck"
    return 0
  fi
  require_command shellcheck
  _log "[DBG-011] Running Shellcheck on ${#SHELL_FILES[@]} file(s)"
  for script in "${SHELL_FILES[@]}"; do
    _log "[DBG-012] Shellcheck: ${script#"${REPO_ROOT}/"}"
    (
      cd "$(dirname "${script}")"
      shellcheck -x "$(basename "${script}")"
    )
  done
}

# shellcheck disable=SC2329
run_actionlint() {
  # INTENT: Run Actionlint on workflow YAML files (not composite action.yml).
  # INPUT: none (uses WORKFLOW_FILES).
  # OUTPUT: None.
  # SIDE_EFFECTS: runs actionlint; exits 1 on findings.
  local wf_file
  if [[ ${#WORKFLOW_FILES[@]} -eq 0 ]]; then
    _log "[DBG-013] No workflow files to scan; skipping Actionlint"
    return 0
  fi
  ensure_actionlint
  require_command actionlint
  _log "[DBG-014] Running Actionlint on ${#WORKFLOW_FILES[@]} file(s)"
  for wf_file in "${WORKFLOW_FILES[@]}"; do
    _log "[DBG-015] Actionlint: ${wf_file#"${REPO_ROOT}/"}"
    actionlint "${wf_file}"
  done
}

# shellcheck disable=SC2329
run_bandit() {
  # INTENT: Run Bandit on changed Python files.
  # INPUT: none (uses PYTHON_FILES).
  # OUTPUT: None.
  # SIDE_EFFECTS: runs bandit; exits 1 on findings.
  local py_file
  if [[ ${#PYTHON_FILES[@]} -eq 0 ]]; then
    _log "[DBG-016] No Python files to scan; skipping Bandit"
    return 0
  fi
  require_command bandit
  _log "[DBG-017] Running Bandit on ${#PYTHON_FILES[@]} file(s)"
  for py_file in "${PYTHON_FILES[@]}"; do
    _log "[DBG-018] Bandit: ${py_file#"${REPO_ROOT}/"}"
    if [[ "${SPVS_HOOK_VERBOSE}" == "1" ]]; then
      bandit -q "${py_file}"
      continue
    fi
    local bandit_output=""
    if ! bandit_output="$(bandit -q "${py_file}" 2>&1)"; then
      printf '%s\n' "${bandit_output}" >&2
      return 1
    fi
  done
}

# shellcheck disable=SC2329
run_checkov_scan() {
  # INTENT: Stage component or repo workflows and run Checkov SPVS policies.
  # INPUT: staging_root, component_path (optional), include_repo, repo_only flags.
  # OUTPUT: None.
  # SIDE_EFFECTS: writes staging files; runs checkov.
  local staging_root="$1"
  local component_path="${2:-}"
  local include_repo="${3:-false}"
  local repo_only="${4:-false}"
  local -a stage_cmd=()
  local label

  require_command checkov

  stage_cmd=(bash "${REPO_ROOT}/policies/scripts/stage_component.sh" --staging-root "${staging_root}")
  if [[ "${repo_only}" == "true" ]]; then
    label="repo-workflows"
    stage_cmd+=(--repo-workflows-only)
  else
    label="${component_path}"
    stage_cmd+=(--component-path "${component_path}")
    if [[ "${include_repo}" == "true" ]]; then
      stage_cmd+=(--include-repo-workflows)
    fi
  fi

  _log "[DBG-002] Staging for Checkov: ${label}"
  if [[ "${SPVS_HOOK_VERBOSE}" == "1" ]]; then
    "${stage_cmd[@]}"
  else
    "${stage_cmd[@]}" >/dev/null
  fi

  _log "[DBG-003] Running Checkov on staged ${label}"
  mkdir -p "${REPO_ROOT}/.checkov.cache/ckv"
  export CKV_CACHE_DIR="${REPO_ROOT}/.checkov.cache/ckv"
  local -a checkov_args=(
    -d "${staging_root}"
    --config-file "${REPO_ROOT}/.checkov.yaml"
    --framework github_actions
  )
  if [[ "${SPVS_HOOK_VERBOSE}" != "1" ]]; then
    checkov_args+=(--quiet --compact)
  fi
  if [[ "${SPVS_HOOK_VERBOSE}" == "1" ]]; then
    checkov "${checkov_args[@]}"
    return 0
  fi
  local checkov_output=""
  if ! checkov_output="$(checkov "${checkov_args[@]}" 2>&1)"; then
    printf '%s\n' "${checkov_output}" >&2
    return 1
  fi
}

# shellcheck disable=SC2329
run_checkov() {
  # INTENT: Orchestrate Checkov scans for all resolved components.
  # INPUT: none (uses globals).
  # OUTPUT: None.
  # SIDE_EFFECTS: temp staging dirs; runs checkov.
  local staging_root
  local component
  local include_repo="false"
  local scan_repo_only="false"

  if repo_workflows_changed; then
    include_repo="true"
  fi
  if policies_changed; then
    include_repo="true"
  fi

  if repo_workflows_changed && [[ ${#RESOLVED_COMPONENTS[@]} -eq 0 ]] && ! policies_changed; then
    scan_repo_only="true"
  fi

  if [[ "${scan_repo_only}" == "true" ]]; then
    staging_root="$(mktemp -d)"
    run_checkov_scan "${staging_root}" "" "false" "true"
    rm -rf "${staging_root}"
    return 0
  fi

  if [[ ${#RESOLVED_COMPONENTS[@]} -eq 0 ]]; then
    _log "[DBG-906] No components resolved for Checkov; skipping"
    return 0
  fi

  for component in "${RESOLVED_COMPONENTS[@]}"; do
    staging_root="$(mktemp -d)"
    run_checkov_scan "${staging_root}" "${component}" "${include_repo}" "false"
    rm -rf "${staging_root}"
  done
}

main() {
  # INTENT: Pre-commit entrypoint for SPVS security scans.
  # INPUT: changed file paths from pre-commit.
  # OUTPUT: None.
  # SIDE_EFFECTS: runs security tools; exits non-zero on failure.
  local raw

  _log "[DBG-000] Pre-commit SPVS security scan starting"

  if [[ "$#" -eq 0 ]]; then
    _log "[DBG-001] No changed files passed; skipping"
    return 0
  fi

  REPO_ROOT="$(git rev-parse --show-toplevel)"
  cd "${REPO_ROOT}"

  CHANGED_FILES=()
  for raw in "$@"; do
    CHANGED_FILES+=("$(normalize_path "${raw}")")
  done

  resolve_components
  collect_shell_scripts
  collect_python_files
  collect_workflow_files

  run_shellcheck
  run_actionlint
  run_bandit
  run_checkov

  _log "[DBG-005] Pre-commit SPVS security scan passed"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main "$@"
fi
