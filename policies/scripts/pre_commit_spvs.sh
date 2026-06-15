#!/usr/bin/env bash
# =============================================================================
# FILE_NAME: pre_commit_spvs.sh
# DESCRIPTION: Pre-commit hook — Checkov SPVS, Shellcheck, Actionlint, and Bandit.
# VERSION: 1.3.0
# EXIT_CODES/SIGNALS: 0 pass, 1 scan failure, 2 missing tool or environment error
# AUTHORS: DevOps Team
# =============================================================================
set -euo pipefail

PROJECT_PREFIX="[SPVS-PRE-COMMIT]"
SPVS_HOOK_VERBOSE="${SPVS_HOOK_VERBOSE:-0}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=spvs_common_lib.sh
source "${SCRIPT_DIR}/spvs_common_lib.sh"

REPO_ROOT=""
CHANGED_FILES=()
DISCOVERED_COMPONENTS=()
POLICIES_CHANGED=0
REPO_WORKFLOWS_CHANGED=0
CHECKOV_COMPONENTS=()
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
  spvs_require_command "$1" 2
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
  if [[ "${path}" =~ ^((actions|workflows)/[^/]+/[^/]+) ]]; then
    printf '%s' "${BASH_REMATCH[1]}"
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
cache_change_flags() {
  # INTENT: Compute policy and repo-workflow change flags once per hook run.
  # INPUT: none (uses CHANGED_FILES).
  # OUTPUT: none.
  # SIDE_EFFECTS: sets POLICIES_CHANGED and REPO_WORKFLOWS_CHANGED.
  if policies_changed; then
    POLICIES_CHANGED=1
  else
    POLICIES_CHANGED=0
  fi
  if repo_workflows_changed; then
    REPO_WORKFLOWS_CHANGED=1
  else
    REPO_WORKFLOWS_CHANGED=0
  fi
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
  done | LC_ALL=C sort -u
}

# shellcheck disable=SC2329
ensure_discovered_components() {
  # INTENT: Lazily populate DISCOVERED_COMPONENTS once per hook run.
  # INPUT: none.
  # OUTPUT: none.
  # SIDE_EFFECTS: fills DISCOVERED_COMPONENTS when empty.
  if [[ ${#DISCOVERED_COMPONENTS[@]} -gt 0 ]]; then
    return 0
  fi
  mapfile -t DISCOVERED_COMPONENTS < <(discover_all_components)
}

# shellcheck disable=SC2329
component_yaml_changed() {
  # INTENT: Return whether a staged path changed YAML under a component (Checkov-relevant).
  # INPUT: component path relative to repo root.
  # OUTPUT: 0 if component YAML changed, 1 otherwise.
  # SIDE_EFFECTS: none.
  local component="$1"
  local path
  for path in "${CHANGED_FILES[@]}"; do
    [[ "${path}" == "${component}/"* ]] || continue
    case "${path}" in
      *.yml | *.yaml)
        return 0
        ;;
    esac
  done
  return 1
}

# shellcheck disable=SC2329
resolve_checkov_components() {
  # INTENT: Build Checkov component list — YAML changes only unless policies require full rescan.
  # INPUT: none (uses globals).
  # OUTPUT: populates CHECKOV_COMPONENTS array.
  # SIDE_EFFECTS: none.
  CHECKOV_COMPONENTS=()
  local -A seen=()
  local path component

  if [[ "${SPVS_HOOK_SKIP_CHECKOV:-0}" == "1" ]]; then
    _log "[DBG-907] Checkov skipped (SPVS_HOOK_SKIP_CHECKOV=1)"
    return 0
  fi

  if [[ "${POLICIES_CHANGED}" -eq 1 ]]; then
    _log "[DBG-004a] Policy change detected; Checkov will scan all components"
    ensure_discovered_components
    for component in "${DISCOVERED_COMPONENTS[@]}"; do
      [[ -n "${component}" ]] || continue
      seen["${component}"]=1
    done
  else
    for path in "${CHANGED_FILES[@]}"; do
      component="$(component_from_path "${path}")"
      if [[ -n "${component}" ]] && component_yaml_changed "${component}"; then
        seen["${component}"]=1
      fi
    done
  fi

  if [[ ${#seen[@]} -gt 0 ]]; then
    mapfile -t CHECKOV_COMPONENTS < <(spvs_sorted_keys seen)
  fi
}

# shellcheck disable=SC2329
# shellcheck disable=SC2329,SC2034
collect_language_files() {
  # INTENT: Gather shell or Python files for Shellcheck/Bandit from changes or full rescan.
  # INPUT: file suffix without dot (sh or py); output array variable name.
  # OUTPUT: populates the named array.
  # SIDE_EFFECTS: reads filesystem.
  local suffix="$1"
  local output_name="$2"
  local -n output_ref="${output_name}"
  local -A seen=()
  local path component

  output_ref=()

  if [[ "${POLICIES_CHANGED}" -eq 1 ]]; then
    spvs_add_glob_to_seen "${REPO_ROOT}/policies/scripts" "${suffix}" seen
    ensure_discovered_components
    for component in "${DISCOVERED_COMPONENTS[@]}"; do
      [[ -n "${component}" ]] || continue
      spvs_add_glob_to_seen "${REPO_ROOT}/${component}" "${suffix}" seen
    done
  else
    for path in "${CHANGED_FILES[@]}"; do
      if [[ "${path}" == *.${suffix} ]] && [[ -f "${REPO_ROOT}/${path}" ]]; then
        seen["${REPO_ROOT}/${path}"]=1
      fi
      if [[ "${path}" == policies/scripts/* ]]; then
        spvs_add_glob_to_seen "${REPO_ROOT}/policies/scripts" "${suffix}" seen
      fi
    done
  fi

  if [[ ${#seen[@]} -gt 0 ]]; then
    mapfile -t output_ref < <(spvs_sorted_keys seen)
  fi
}

# shellcheck disable=SC2329
collect_shell_scripts() {
  collect_language_files sh SHELL_FILES
}

# shellcheck disable=SC2329
collect_python_files() {
  collect_language_files py PYTHON_FILES
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
  local candidates=("${dir}"/*.{yml,yaml})
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
  local path component wf wf_file

  if [[ "${POLICIES_CHANGED}" -eq 1 ]] || [[ "${REPO_WORKFLOWS_CHANGED}" -eq 1 ]]; then
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
        .github/workflows/*.yml | .github/workflows/*.yaml | workflows/*/*/*.yml | workflows/*/*/*.yaml)
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
    mapfile -t WORKFLOW_FILES < <(spvs_sorted_keys seen)
  fi
}

# shellcheck disable=SC2329
run_shellcheck() {
  # INTENT: Run Shellcheck on changed shell scripts in one invocation.
  # INPUT: none (uses SHELL_FILES).
  # OUTPUT: None.
  # SIDE_EFFECTS: runs shellcheck; exits 1 on findings.
  if [[ ${#SHELL_FILES[@]} -eq 0 ]]; then
    _log "[DBG-010] No shell scripts to scan; skipping Shellcheck"
    return 0
  fi
  require_command shellcheck
  _log "[DBG-011] Running Shellcheck on ${#SHELL_FILES[@]} file(s)"
  shellcheck -x "${SHELL_FILES[@]}"
}

# shellcheck disable=SC2329
run_actionlint() {
  # INTENT: Run Actionlint on workflow YAML files in one invocation.
  # INPUT: none (uses WORKFLOW_FILES).
  # OUTPUT: None.
  # SIDE_EFFECTS: runs actionlint; exits 1 on findings.
  if [[ ${#WORKFLOW_FILES[@]} -eq 0 ]]; then
    _log "[DBG-013] No workflow files to scan; skipping Actionlint"
    return 0
  fi
  spvs_ensure_actionlint "${REPO_ROOT}" _log
  require_command actionlint
  _log "[DBG-014] Running Actionlint on ${#WORKFLOW_FILES[@]} file(s)"
  actionlint "${WORKFLOW_FILES[@]}"
}

# shellcheck disable=SC2329
run_bandit() {
  # INTENT: Run Bandit on changed Python files in one invocation.
  # INPUT: none (uses PYTHON_FILES).
  # OUTPUT: None.
  # SIDE_EFFECTS: runs bandit; exits 1 on findings.
  if [[ ${#PYTHON_FILES[@]} -eq 0 ]]; then
    _log "[DBG-016] No Python files to scan; skipping Bandit"
    return 0
  fi
  require_command bandit
  _log "[DBG-017] Running Bandit on ${#PYTHON_FILES[@]} file(s)"
  if [[ "${SPVS_HOOK_VERBOSE}" == "1" ]]; then
    bandit -q "${PYTHON_FILES[@]}"
    return 0
  fi
  local bandit_output=""
  if ! bandit_output="$(bandit -q "${PYTHON_FILES[@]}" 2>&1)"; then
    printf '%s\n' "${bandit_output}" >&2
    return 1
  fi
}

# shellcheck disable=SC2329
execute_checkov_on_dir() {
  # INTENT: Run Checkov against an already-staged directory tree.
  # INPUT: staging_root directory path.
  # OUTPUT: None.
  # SIDE_EFFECTS: runs checkov; exits 1 on findings.
  local staging_root="$1"
  local -a checkov_args=()

  require_command checkov
  mkdir -p "${REPO_ROOT}/.checkov.cache/ckv"
  export CKV_CACHE_DIR="${REPO_ROOT}/.checkov.cache/ckv"
  checkov_args=(
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
run_stage_component() {
  # INTENT: Invoke stage_component.sh, suppressing stdout unless verbose.
  # INPUT: stage_component argument list.
  # OUTPUT: none.
  # SIDE_EFFECTS: runs staging script.
  if [[ "${SPVS_HOOK_VERBOSE}" == "1" ]]; then
    bash "${REPO_ROOT}/policies/scripts/stage_component.sh" "$@"
  else
    bash "${REPO_ROOT}/policies/scripts/stage_component.sh" "$@" >/dev/null
  fi
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
  local label

  if [[ "${repo_only}" == "true" ]]; then
    label="repo-workflows"
    _log "[DBG-002] Staging for Checkov: ${label}"
    run_stage_component --staging-root "${staging_root}" --repo-workflows-only
  else
    label="${component_path}"
    _log "[DBG-002] Staging for Checkov: ${label}"
    if [[ "${include_repo}" == "true" ]]; then
      run_stage_component --staging-root "${staging_root}" --component-path "${component_path}" --include-repo-workflows
    else
      run_stage_component --staging-root "${staging_root}" --component-path "${component_path}"
    fi
  fi

  _log "[DBG-003] Running Checkov on staged ${label}"
  execute_checkov_on_dir "${staging_root}"
}

# shellcheck disable=SC2329
run_checkov() {
  # INTENT: Orchestrate Checkov scans for changed component YAML (batched) or repo workflows.
  # INPUT: none (uses globals).
  # OUTPUT: None.
  # SIDE_EFFECTS: temp staging dirs; runs checkov.
  local staging_root=""
  local component=""
  local include_repo="false"
  local scan_repo_only="false"
  local first="true"

  if [[ "${REPO_WORKFLOWS_CHANGED}" -eq 1 ]]; then
    include_repo="true"
  fi
  if [[ "${POLICIES_CHANGED}" -eq 1 ]]; then
    include_repo="true"
  fi

  if [[ "${REPO_WORKFLOWS_CHANGED}" -eq 1 ]] && [[ ${#CHECKOV_COMPONENTS[@]} -eq 0 ]] && [[ "${POLICIES_CHANGED}" -eq 0 ]]; then
    scan_repo_only="true"
  fi

  if [[ "${scan_repo_only}" == "true" ]]; then
    staging_root="$(mktemp -d)"
    run_checkov_scan "${staging_root}" "" "false" "true"
    rm -rf "${staging_root}"
    return 0
  fi

  if [[ ${#CHECKOV_COMPONENTS[@]} -eq 0 ]]; then
    _log "[DBG-906] No component YAML changes for Checkov; skipping"
    return 0
  fi

  staging_root="$(mktemp -d)"
  for component in "${CHECKOV_COMPONENTS[@]}"; do
    _log "[DBG-002] Staging for Checkov: ${component}"
    if [[ "${first}" == "true" ]]; then
      run_stage_component --staging-root "${staging_root}" --component-path "${component}"
      first="false"
    else
      run_stage_component --staging-root "${staging_root}" --component-path "${component}" --append
    fi
  done

  if [[ "${include_repo}" == "true" ]]; then
    _log "[DBG-002] Staging repo workflows for Checkov"
    run_stage_component --staging-root "${staging_root}" --include-repo-workflows --append
  fi

  _log "[DBG-003] Running Checkov on ${#CHECKOV_COMPONENTS[@]} staged component(s)"
  execute_checkov_on_dir "${staging_root}"
  rm -rf "${staging_root}"
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

  cache_change_flags
  resolve_checkov_components
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
