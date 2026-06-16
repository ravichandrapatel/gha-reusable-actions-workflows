#!/usr/bin/env bash
# =============================================================================
# FILE_NAME: checkov_inline_skip_lib.sh
# DESCRIPTION: Honor # checkov:skip= comments for github_actions scans (Checkov gap).
# VERSION: 1.0.0
# EXIT_CODES/SIGNALS: Sourced only; filter helpers return 0/1.
# AUTHORS: DevOps Team
# =============================================================================

# shellcheck disable=SC2329
spvs_checkov_line_skips_check() {
  # INTENT: Return whether a YAML line contains an inline skip for check_id.
  # INPUT: check_id string; line string.
  # OUTPUT: return 0 when skip matches, 1 otherwise.
  # SIDE_EFFECTS: none.
  local check_id="$1"
  local line="$2"
  local skip_specs=""
  local spec=""
  local id=""

  if [[ ! "${line}" =~ checkov:skip=([^#]+) ]]; then
    return 1
  fi

  skip_specs="${BASH_REMATCH[1]}"
  skip_specs="${skip_specs%%[[:space:]]*}"

  local IFS=','
  for spec in ${skip_specs}; do
    id="${spec%%:*}"
    id="${id// /}"
    if [[ "${id}" == "${check_id}" ]]; then
      return 0
    fi
  done
  return 1
}

# shellcheck disable=SC2329
spvs_checkov_failure_suppressed() {
  # INTENT: Decide if a Checkov JSON failure is suppressed by inline skip comments.
  # INPUT: path to Checkov JSON; failure index.
  # OUTPUT: return 0 when suppressed, 1 when it should fail the scan.
  # SIDE_EFFECTS: reads YAML file from disk.
  local json_file="$1"
  local index="$2"
  local check_id=""
  local file_path=""
  local start_line=""
  local end_line=""
  local block_len=""
  local block_idx=""
  local line=""
  local scan_start=""

  check_id="$(yq -r ".results.failed_checks[${index}].check_id" "${json_file}")"
  file_path="$(yq -r ".results.failed_checks[${index}].file_abs_path" "${json_file}")"
  start_line="$(yq -r ".results.failed_checks[${index}].file_line_range[0]" "${json_file}")"
  end_line="$(yq -r ".results.failed_checks[${index}].file_line_range[1]" "${json_file}")"

  block_len="$(yq ".results.failed_checks[${index}].code_block | length" "${json_file}")"
  for ((block_idx = 0; block_idx < block_len; block_idx++)); do
    line="$(yq -r ".results.failed_checks[${index}].code_block[${block_idx}][1]" "${json_file}")"
    if spvs_checkov_line_skips_check "${check_id}" "${line}"; then
      return 0
    fi
  done

  if [[ -f "${file_path}" ]] && [[ "${start_line}" =~ ^[0-9]+$ ]] && [[ "${end_line}" =~ ^[0-9]+$ ]]; then
    scan_start=$((start_line - 2))
    if [[ "${scan_start}" -lt 1 ]]; then
      scan_start=1
    fi
    while IFS= read -r line || [[ -n "${line}" ]]; do
      if spvs_checkov_line_skips_check "${check_id}" "${line}"; then
        return 0
      fi
    done < <(sed -n "${scan_start},${end_line}p" "${file_path}")
  fi

  return 1
}

# shellcheck disable=SC2329
spvs_filter_checkov_json() {
  # INTENT: Evaluate Checkov JSON; return 0 when no unsuppressed failures remain.
  # INPUT: path to Checkov JSON output file.
  # OUTPUT: return 0 pass, 1 when unsuppressed failures exist.
  # SIDE_EFFECTS: none.
  local json_file="$1"
  local failure_count=""
  local index=""
  local unsuppressed=0

  if [[ ! -f "${json_file}" ]]; then
    printf '[SPVS-CHECKOV-SKIP] [DBG-910] Missing Checkov JSON: %s\n' "${json_file}" >&2
    return 1
  fi

  failure_count="$(yq '.results.failed_checks | length' "${json_file}")"
  if [[ "${failure_count}" == "0" ]] || [[ "${failure_count}" == "null" ]]; then
    return 0
  fi

  for ((index = 0; index < failure_count; index++)); do
    if spvs_checkov_failure_suppressed "${json_file}" "${index}"; then
      continue
    fi
    unsuppressed=$((unsuppressed + 1))
  done

  [[ "${unsuppressed}" -eq 0 ]]
}

# shellcheck disable=SC2329
spvs_print_checkov_failures() {
  # INTENT: Print compact Checkov failures (matches checkov --quiet --compact).
  # INPUT: path to Checkov JSON; optional verbose flag (0|1).
  # OUTPUT: failure details on stdout.
  # SIDE_EFFECTS: none.
  local json_file="$1"
  local verbose="${2:-0}"
  local failure_count=""
  local index=""
  local unsuppressed=0
  local check_id=""
  local check_name=""
  local resource=""
  local file_path=""
  local start_line=""
  local end_line=""
  local guide=""
  local block_len=""
  local block_idx=""
  local line_no=""
  local line_text=""

  failure_count="$(yq '.results.failed_checks | length' "${json_file}")"
  for ((index = 0; index < failure_count; index++)); do
    if spvs_checkov_failure_suppressed "${json_file}" "${index}"; then
      continue
    fi
    unsuppressed=$((unsuppressed + 1))
  done

  printf 'Passed checks: %s, Failed checks: %s, Skipped checks: 0\n\n' \
    "$(yq -r '.summary.passed // "?"' "${json_file}")" \
    "${unsuppressed}"

  for ((index = 0; index < failure_count; index++)); do
    if spvs_checkov_failure_suppressed "${json_file}" "${index}"; then
      continue
    fi

    check_id="$(yq -r ".results.failed_checks[${index}].check_id" "${json_file}")"
    check_name="$(yq -r ".results.failed_checks[${index}].check_name" "${json_file}")"
    resource="$(yq -r ".results.failed_checks[${index}].resource" "${json_file}")"
    file_path="$(yq -r ".results.failed_checks[${index}].file_path" "${json_file}")"
    start_line="$(yq -r ".results.failed_checks[${index}].file_line_range[0]" "${json_file}")"
    end_line="$(yq -r ".results.failed_checks[${index}].file_line_range[1]" "${json_file}")"
    guide="$(yq -r ".results.failed_checks[${index}].guideline // \"\"" "${json_file}")"

    printf 'Check: %s: "%s"\n' "${check_id}" "${check_name}"
    printf '\tFAILED for resource: %s\n' "${resource}"
    printf '\tFile: %s:%s-%s\n' "${file_path}" "${start_line}" "${end_line}"
    if [[ -n "${guide}" ]] && [[ "${guide}" != "null" ]]; then
      printf '\tGuide: %s\n' "${guide}"
    fi

    if [[ "${verbose}" == "1" ]]; then
      block_len="$(yq ".results.failed_checks[${index}].code_block | length" "${json_file}")"
      for ((block_idx = 0; block_idx < block_len; block_idx++)); do
        line_no="$(yq -r ".results.failed_checks[${index}].code_block[${block_idx}][0]" "${json_file}")"
        line_text="$(yq -r ".results.failed_checks[${index}].code_block[${block_idx}][1]" "${json_file}")"
        printf '\t\t%s | %s' "${line_no}" "${line_text}"
      done
      printf '\n'
    fi
  done
}

# shellcheck disable=SC2329
spvs_run_checkov_with_inline_skips() {
  # INTENT: Run Checkov on a directory and honor inline skip comments in workflow YAML.
  # INPUT: staging_root; repo_root; verbose flag (0|1).
  # OUTPUT: return 0 pass, 1 on unsuppressed findings, 2 on tool error.
  # SIDE_EFFECTS: runs checkov; may print failures to stderr.
  local staging_root="$1"
  local repo_root="$2"
  local verbose="${3:-0}"
  local json_file=""
  local -a checkov_args=()

  if ! command -v yq >/dev/null 2>&1; then
    printf '[SPVS-CHECKOV-SKIP] [DBG-911] yq is required for inline Checkov skips; run install_dev_hooks.sh\n' >&2
    return 2
  fi

  if ! command -v checkov >/dev/null 2>&1; then
    printf '[SPVS-CHECKOV-SKIP] [DBG-912] checkov not found on PATH\n' >&2
    return 2
  fi

  mkdir -p "${repo_root}/.checkov.cache/ckv"
  export CKV_CACHE_DIR="${repo_root}/.checkov.cache/ckv"

  json_file="$(mktemp)"
  checkov_args=(
    -d "${staging_root}"
    --config-file "${repo_root}/.checkov.yaml"
    --framework github_actions
    --output json
    --quiet
  )

  checkov "${checkov_args[@]}" >"${json_file}" 2>/dev/null || true

  if spvs_filter_checkov_json "${json_file}"; then
    if [[ "${verbose}" == "1" ]]; then
      yq -r '.summary' "${json_file}" 2>/dev/null || true
    fi
    rm -f "${json_file}"
    return 0
  fi

  {
    printf 'github_actions scan results:\n\n'
    spvs_print_checkov_failures "${json_file}" "${verbose}"
  } >&2
  rm -f "${json_file}"
  return 1
}
