#!/usr/bin/env bash
# =============================================================================
# FILE_NAME: spvs_conftest_run.sh
# DESCRIPTION: Run Conftest for SPVS and print failures with YAML line numbers.
# VERSION: 1.0.0
# EXIT_CODES/SIGNALS: 0 pass, 1 policy failure, 2 tool error
# AUTHORS: DevOps Team
# =============================================================================
set -euo pipefail

CONFTEST_RUN_PREFIX="[SPVS-CONFTEST]"
CONFTEST_BIN="${CONFTEST_BIN:-conftest}"

# INTENT: Execute Conftest test and render line-numbered failure report.
# INPUT: namespace; policy_dir; policy_lib; file list.
# OUTPUT: return 0 pass, 1 policy failure, 2 tool error.
# SIDE_EFFECTS: prints report to stdout.
spvs_conftest_test() {
  local namespace="$1"
  local policy_dir="$2"
  local policy_lib="$3"
  shift 3
  local script_dir=""
  local report_py=""
  local json_file=""
  local conftest_rc=0
  local report_rc=0

  if [[ $# -eq 0 ]]; then
    return 0
  fi

  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  report_py="${script_dir}/spvs_conftest_report.py"
  json_file="$(mktemp)"

  if ! command -v python3 &>/dev/null; then
    printf '%s ERROR: python3 required for line-number reporting.\n' "${CONFTEST_RUN_PREFIX}" >&2
    return 2
  fi

  set +e
  "${CONFTEST_BIN}" test --parser yaml -n "${namespace}" \
    -p "${policy_dir}" -p "${policy_lib}" -o json "$@" >"${json_file}" 2>/dev/null
  conftest_rc=$?
  set -e

  if [[ "${conftest_rc}" -ne 0 && "${conftest_rc}" -ne 1 ]]; then
    cat "${json_file}" >&2 || true
    rm -f "${json_file}"
    printf '%s ERROR: conftest exited with status %s\n' "${CONFTEST_RUN_PREFIX}" "${conftest_rc}" >&2
    return 2
  fi

  python3 "${report_py}" "${json_file}"
  report_rc=$?
  rm -f "${json_file}"

  if [[ "${report_rc}" -ne 0 ]]; then
    return 1
  fi
  return 0
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if [[ $# -lt 4 ]]; then
    echo "Usage: spvs_conftest_run.sh NAMESPACE POLICY_DIR POLICY_LIB FILE..." >&2
    exit 2
  fi
  spvs_conftest_test "$@"
fi
