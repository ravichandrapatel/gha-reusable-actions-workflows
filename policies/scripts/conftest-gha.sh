#!/usr/bin/env bash
# =============================================================================
# FILE_NAME: conftest-gha.sh
# DESCRIPTION: Conftest scanner for GHA workflows/composite actions with inline skips.
# VERSION: 1.4.0
# EXIT_CODES/SIGNALS: 0 pass, 1 policy failure, 2 usage/tool error
# AUTHORS: DevOps Team
# =============================================================================
#
# Usage:
#   bash policies/scripts/conftest-gha.sh
#   bash policies/scripts/conftest-gha.sh -d actions -d workflows
#   bash policies/scripts/conftest-gha.sh -f workflows/common/dummy-workflow/workflow.yml
#
# Inline skips (YAML comments — parsed here; Rego never sees comments):
#   # spvs:skip=CKV2_SPVS_5,CKV2_SPVS_5B: documented reason
#   uses: ../other-action  # checkov:skip=CKV2_SPVS_5B: legacy layout
#
set -euo pipefail

PROJECT_PREFIX="[CONFTEST-GHA]"
CONFTEST_BIN="${CONFTEST_BIN:-conftest}"

# INTENT: Return whether a YAML line contains an inline skip for check_id.
# INPUT: check_id string; line string.
# OUTPUT: return 0 when skip matches, 1 otherwise.
# SIDE_EFFECTS: none.
spvs_inline_line_skips_check() {
  local check_id="$1"
  local line="$2"
  local skip_body=""
  local ids_part=""
  local spec=""
  local id=""

  if [[ ! "${line}" =~ (checkov|spvs):skip=([^#]+) ]]; then
    return 1
  fi

  skip_body="${BASH_REMATCH[2]}"
  skip_body="${skip_body%%#*}"
  ids_part="${skip_body%%:*}"
  ids_part="${ids_part// /}"

  local IFS=','
  for spec in ${ids_part}; do
    id="${spec}"
    if [[ -z "${id}" ]]; then
      continue
    fi
    if [[ "${id}" == "${check_id}" ]]; then
      return 0
    fi
    case "${check_id}" in
      CKV2_SPVS_5 | CKV2_SPVS_5B)
        if [[ "${id}" == "CKV2_SPVS_5" || "${id}" == "CKV2_SPVS_5B" ]]; then
          if [[ "${line}" == *"../"* ]] || [[ "${line}" =~ uses:[[:space:]]*(\.\./|\./) ]]; then
            return 0
          fi
        fi
        ;;
    esac
  done
  return 1
}

# INTENT: Extract policy check id prefix from a Conftest failure message.
# INPUT: failure message string.
# OUTPUT: echoes check id or empty string.
# SIDE_EFFECTS: none.
spvs_extract_check_id_from_msg() {
  local msg="$1"
  if [[ "${msg}" =~ ^(CKV2_(GHA|SPVS)_[0-9]+[A-Z]?|CKV_GHA_[0-9]+) ]]; then
    echo "${BASH_REMATCH[1]}"
  fi
}

# INTENT: Extract uses ref from a workflow step line when present.
# INPUT: YAML line string.
# OUTPUT: echoes uses value or empty string.
# SIDE_EFFECTS: none.
spvs_extract_uses_from_line() {
  local line="$1"
  if [[ "${line}" =~ uses:[[:space:]]*([^[:space:]#]+) ]]; then
    echo "${BASH_REMATCH[1]}"
  fi
}

# INTENT: Decide if a Conftest failure is suppressed by an inline skip in the file.
# INPUT: absolute file path; check_id; failure message.
# OUTPUT: return 0 when suppressed, 1 otherwise.
# SIDE_EFFECTS: reads YAML file from disk.
spvs_resolve_yaml_path() {
  local repo_root="$1"
  local file_path="$2"

  if [[ -f "${file_path}" ]]; then
    printf '%s\n' "$(cd "$(dirname "${file_path}")" && pwd)/$(basename "${file_path}")"
    return 0
  fi
  if [[ "${file_path}" != /* && -f "${repo_root}/${file_path}" ]]; then
    printf '%s\n' "$(cd "${repo_root}/$(dirname "${file_path}")" && pwd)/$(basename "${file_path}")"
    return 0
  fi
  printf '%s\n' "${file_path}"
}

spvs_conftest_failure_suppressed() {
  local repo_root="$1"
  local file_path="$2"
  local check_id="$3"
  local msg="$4"
  local line=""
  local uses_val=""
  local resolved=""

  resolved="$(spvs_resolve_yaml_path "${repo_root}" "${file_path}")"
  if [[ ! -f "${resolved}" ]]; then
    return 1
  fi

  while IFS= read -r line || [[ -n "${line}" ]]; do
    if ! spvs_inline_line_skips_check "${check_id}" "${line}"; then
      continue
    fi

    if [[ "${line}" =~ ^[[:space:]]*# ]]; then
      return 0
    fi

    case "${check_id}" in
      CKV2_SPVS_5 | CKV2_SPVS_5B)
        uses_val="$(spvs_extract_uses_from_line "${line}")"
        if [[ -n "${uses_val}" && "${msg}" == *"${uses_val}"* ]]; then
          return 0
        fi
        if [[ "${check_id}" == "CKV2_SPVS_5B" && "${line}" == *"../"* ]]; then
          return 0
        fi
        ;;
      *)
        if [[ "${line}" != \#* ]]; then
          return 0
        fi
        ;;
    esac
  done <"${resolved}"

  return 1
}

# INTENT: Evaluate Conftest JSON output; return 0 when no unsuppressed failures remain.
# INPUT: path to Conftest JSON array; repo root for relative paths.
# OUTPUT: return 0 pass, 1 when unsuppressed failures exist.
# SIDE_EFFECTS: may print suppressed notices to stderr.
spvs_filter_conftest_json() {
  local json_file="$1"
  local repo_root="$2"
  local file_count=""
  local file_idx=""
  local failure_count=""
  local failure_idx=""
  local unsuppressed=0
  local filename=""
  local check_id=""
  local msg=""

  if [[ ! -f "${json_file}" ]]; then
    printf '%s ERROR: missing Conftest JSON: %s\n' "${PROJECT_PREFIX}" "${json_file}" >&2
    return 1
  fi

  file_count="$(python3 -c "import json,sys; print(len(json.load(open(sys.argv[1]))))" "${json_file}")"

  for ((file_idx = 0; file_idx < file_count; file_idx++)); do
    failure_count="$(python3 -c "
import json, sys
data = json.load(open(sys.argv[1]))
print(len(data[int(sys.argv[2])].get('failures', [])))
" "${json_file}" "${file_idx}")"

    for ((failure_idx = 0; failure_idx < failure_count; failure_idx++)); do
      filename="$(python3 -c "
import json, sys
item = json.load(open(sys.argv[1]))[int(sys.argv[2])]
print(item.get('filename', ''))
" "${json_file}" "${file_idx}")"
      msg="$(python3 -c "
import json, sys
item = json.load(open(sys.argv[1]))[int(sys.argv[2])]
print(item.get('failures', [])[int(sys.argv[3])].get('msg', ''))
" "${json_file}" "${file_idx}" "${failure_idx}")"

      check_id="$(spvs_extract_check_id_from_msg "${msg}")"
      if [[ -z "${check_id}" ]]; then
        unsuppressed=$((unsuppressed + 1))
        continue
      fi

      if spvs_conftest_failure_suppressed "${repo_root}" "${filename}" "${check_id}" "${msg}"; then
        rel="${filename#"${repo_root}/"}"
        printf '%s SUPPRESSED %s in %s (inline skip)\n' "${PROJECT_PREFIX}" "${check_id}" "${rel}" >&2
        continue
      fi

      unsuppressed=$((unsuppressed + 1))
    done
  done

  [[ "${unsuppressed}" -eq 0 ]]
}

# INTENT: Print unsuppressed Conftest failures in a compact format.
# INPUT: path to Conftest JSON; repo root.
# OUTPUT: failure details on stderr.
# SIDE_EFFECTS: none.
spvs_print_conftest_failures() {
  local json_file="$1"
  local repo_root="$2"
  local file_count=""
  local file_idx=""
  local failure_count=""
  local failure_idx=""
  local filename=""
  local rel=""
  local namespace=""
  local check_id=""
  local msg=""

  file_count="$(python3 -c "import json,sys; print(len(json.load(open(sys.argv[1]))))" "${json_file}")"

  for ((file_idx = 0; file_idx < file_count; file_idx++)); do
    filename="$(python3 -c "
import json, sys
item = json.load(open(sys.argv[1]))[int(sys.argv[2])]
print(item.get('filename', ''))
" "${json_file}" "${file_idx}")"
    namespace="$(python3 -c "
import json, sys
item = json.load(open(sys.argv[1]))[int(sys.argv[2])]
print(item.get('namespace', ''))
" "${json_file}" "${file_idx}")"

    failure_count="$(python3 -c "
import json, sys
data = json.load(open(sys.argv[1]))
print(len(data[int(sys.argv[2])].get('failures', [])))
" "${json_file}" "${file_idx}")"

    for ((failure_idx = 0; failure_idx < failure_count; failure_idx++)); do
      msg="$(python3 -c "
import json, sys
item = json.load(open(sys.argv[1]))[int(sys.argv[2])]
print(item.get('failures', [])[int(sys.argv[3])].get('msg', ''))
" "${json_file}" "${file_idx}" "${failure_idx}")"

      check_id="$(spvs_extract_check_id_from_msg "${msg}")"
      if spvs_conftest_failure_suppressed "${repo_root}" "${filename}" "${check_id}" "${msg}"; then
        continue
      fi

      rel="${filename#"${repo_root}/"}"
      printf 'FAIL %s (%s) %s\n' "${rel}" "${namespace}" "${msg}"
    done
  done
}

conftest_gha_usage() {
  cat <<EOF
Usage: bash policies/scripts/conftest-gha.sh [-d DIR]... [-f FILE]...

Runs Conftest Rego policies on:
  actions/*/*/action.yml, workflows/*/*/workflow.yml,
  .github/workflows/*.yml, .github/actions/**/action.yml

  -d DIR   Discover scannable YAML under DIR (repeatable)
  -f FILE  Scan one file exactly (repeatable; use for Release Manager component scans)

Inline policy skips in YAML (honored by this script):
  # spvs:skip=CKV2_SPVS_5,CKV2_SPVS_5B: reason
  uses: ../other-action  # spvs:skip=CKV2_SPVS_5B: reason

Environment:
  CONFTEST_BIN  Path to conftest (default: conftest)
EOF
}

# INTENT: Classify and queue one scannable file for Conftest.
# INPUT: repo_root; absolute or relative file path.
# OUTPUT: return 0 when queued, 1 when skipped (not scannable), 2 on missing file.
# SIDE_EFFECTS: appends to workflow_files or composite_files arrays in caller scope.
conftest_gha_queue_file() {
  local repo_root="$1"
  local file="$2"
  local abs=""
  local rel=""

  if [[ ! -f "${file}" ]]; then
    printf '%s ERROR: file not found: %s\n' "${PROJECT_PREFIX}" "${file}" >&2
    return 2
  fi

  abs="$(cd "$(dirname "${file}")" && pwd)/$(basename "${file}")"
  rel="${abs#"${repo_root}/"}"
  if [[ "${rel}" == "${abs}" ]]; then
    rel="${file#./}"
  fi

  if ! conftest_gha_is_scannable "${rel}"; then
    printf '%s WARN: skipping non-scannable path: %s\n' "${PROJECT_PREFIX}" "${rel}" >&2
    return 1
  fi

  case "${rel}" in
    */action.yml | */action.yaml)
      composite_files+=("${abs}")
      ;;
    *)
      workflow_files+=("${abs}")
      ;;
  esac
  return 0
}

conftest_gha_is_scannable() {
  local rel="$1"
  [[ "${rel}" =~ ^actions/[^/]+/[^/]+/action\.ya?ml$ ]] && return 0
  [[ "${rel}" =~ ^workflows/[^/]+/[^/]+/workflow\.ya?ml$ ]] && return 0
  [[ "${rel}" =~ ^\.github/workflows/.+\.ya?ml$ ]] && return 0
  [[ "${rel}" =~ ^\.github/actions/.+/action\.ya?ml$ ]] && return 0
  return 1
}

conftest_gha_run_batch() {
  local repo_root="$1"
  local namespace="$2"
  local policy_dir="$3"
  shift 3
  local -a files=("$@")
  local json_file=""
  local exit_code=0

  json_file="$(mktemp)"

  set +e
  "${CONFTEST_BIN}" test --parser yaml -n "${namespace}" -p "${policy_dir}" -o json "${files[@]}" >"${json_file}" 2>/dev/null
  exit_code=$?
  set -e

  if [[ "${exit_code}" -ne 0 && "${exit_code}" -ne 1 ]]; then
    cat "${json_file}" >&2 || true
    rm -f "${json_file}"
    return 2
  fi

  if spvs_filter_conftest_json "${json_file}" "${repo_root}"; then
    rm -f "${json_file}"
    return 0
  fi

  spvs_print_conftest_failures "${json_file}" "${repo_root}" >&2
  rm -f "${json_file}"
  return 1
}

conftest_gha_main() {
  local repo_root=""
  local policy_workflow=""
  local policy_composite=""
  local -a default_roots=(actions workflows .github/workflows .github/actions)
  local -a scan_roots=()
  local -a explicit_files=()
  local -a workflow_files=()
  local -a composite_files=()
  local root=""
  local rel=""
  local file=""
  local status=0

  repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
  cd "${repo_root}"

  policy_workflow="${repo_root}/policies/conftest/github_actions/workflow"
  policy_composite="${repo_root}/policies/conftest/github_actions/composite"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -d | --directory)
        scan_roots+=("${2:-}")
        shift 2
        ;;
      -f | --file)
        explicit_files+=("${2:-}")
        shift 2
        ;;
      -h | --help)
        conftest_gha_usage
        return 0
        ;;
      *)
        echo "${PROJECT_PREFIX} ERROR: unknown argument: $1" >&2
        conftest_gha_usage
        return 2
        ;;
    esac
  done

  if [[ ${#scan_roots[@]} -eq 0 && ${#explicit_files[@]} -eq 0 ]]; then
    scan_roots=("${default_roots[@]}")
  fi

  if ! command -v "${CONFTEST_BIN}" &>/dev/null; then
    echo "${PROJECT_PREFIX} ERROR: conftest not found. Install: https://www.conftest.dev/install/" >&2
    return 2
  fi

  if ! command -v python3 &>/dev/null; then
    echo "${PROJECT_PREFIX} ERROR: python3 required for inline skip filtering." >&2
    return 2
  fi

  for file in "${explicit_files[@]}"; do
    conftest_gha_queue_file "${repo_root}" "${file}" || {
      rc=$?
      if [[ "${rc}" -eq 2 ]]; then
        return 2
      fi
    }
  done

  for root in "${scan_roots[@]}"; do
    [[ -d "${root}" ]] || continue
    while IFS= read -r -d '' file; do
      conftest_gha_queue_file "${repo_root}" "${file}" || true
    done < <(find "${root}" -type f \( -name '*.yml' -o -name '*.yaml' \) -print0 2>/dev/null)
  done

  if [[ ${#workflow_files[@]} -eq 0 && ${#composite_files[@]} -eq 0 ]]; then
    if [[ ${#explicit_files[@]} -gt 0 ]]; then
      echo "${PROJECT_PREFIX} ERROR: no scannable GHA files in: ${explicit_files[*]}" >&2
      return 2
    fi
    echo "${PROJECT_PREFIX} No scannable GHA files under: ${scan_roots[*]}" >&2
    return 0
  fi

  if [[ ${#workflow_files[@]} -gt 0 ]]; then
    echo "${PROJECT_PREFIX} Testing ${#workflow_files[@]} workflow file(s)..." >&2
    if ! conftest_gha_run_batch "${repo_root}" workflow "${policy_workflow}" "${workflow_files[@]}"; then
      status=1
    fi
  fi

  if [[ ${#composite_files[@]} -gt 0 ]]; then
    echo "${PROJECT_PREFIX} Testing ${#composite_files[@]} composite action file(s)..." >&2
    if ! conftest_gha_run_batch "${repo_root}" composite "${policy_composite}" "${composite_files[@]}"; then
      status=1
    fi
  fi

  return "${status}"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  conftest_gha_main "$@"
fi
