#!/usr/bin/env bash
# FILE_NAME: retry.sh
# DESCRIPTION: Retry a shell command with timeout, wait, and exit-code filters.
# VERSION: 1.2.0
# AUTHORS: DevOps Team
set -euo pipefail

COMMAND="${COMMAND:-}"
MAX_ATTEMPTS="${MAX_ATTEMPTS:-3}"
RETRY_WAIT_SECONDS="${RETRY_WAIT_SECONDS:-5}"
TIMEOUT_SECONDS="${TIMEOUT_SECONDS:-0}"
TIMEOUT_MINUTES="${TIMEOUT_MINUTES:-0}"
POLLING_INTERVAL_SECONDS="${POLLING_INTERVAL_SECONDS:-1}"
WARNING_ON_RETRY="${WARNING_ON_RETRY:-true}"
ON_RETRY_COMMAND="${ON_RETRY_COMMAND:-}"
NEW_COMMAND_ON_RETRY="${NEW_COMMAND_ON_RETRY:-}"
RETRY_ON_EXIT_CODE="${RETRY_ON_EXIT_CODE:-}"
RETRY_ON="${RETRY_ON:-error}"
SHELL_NAME="${SHELL_NAME:-bash}"
OUTPUT="${OUTPUT:-${GITHUB_OUTPUT:-}}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --command) COMMAND="$2"; shift 2 ;;
    --max-attempts) MAX_ATTEMPTS="$2"; shift 2 ;;
    --retry-wait-seconds) RETRY_WAIT_SECONDS="$2"; shift 2 ;;
    --timeout-seconds) TIMEOUT_SECONDS="$2"; shift 2 ;;
    --timeout-minutes) TIMEOUT_MINUTES="$2"; shift 2 ;;
    --polling-interval-seconds) POLLING_INTERVAL_SECONDS="$2"; shift 2 ;;
    --warning-on-retry) WARNING_ON_RETRY="$2"; shift 2 ;;
    --on-retry-command) ON_RETRY_COMMAND="$2"; shift 2 ;;
    --new-command-on-retry) NEW_COMMAND_ON_RETRY="$2"; shift 2 ;;
    --retry-on-exit-code) RETRY_ON_EXIT_CODE="$2"; shift 2 ;;
    --retry-on) RETRY_ON="$2"; shift 2 ;;
    --shell) SHELL_NAME="$2"; shift 2 ;;
    --output) OUTPUT="$2"; shift 2 ;;
    *) echo "ERROR: unknown argument $1" >&2; exit 1 ;;
  esac
done

require_int() {
  local name="$1" raw="$2" min="$3"
  if [[ ! "${raw}" =~ ^[0-9]+$ ]] || [[ "${raw}" -lt "${min}" ]]; then
    echo "ERROR: ${name} must be an integer >= ${min}" >&2
    exit 1
  fi
}

COMMAND="$(printf '%s' "${COMMAND}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
if [[ -z "${COMMAND}" ]]; then
  echo "ERROR: --command is empty" >&2
  exit 1
fi
require_int "--max-attempts" "${MAX_ATTEMPTS}" 1
require_int "--retry-wait-seconds" "${RETRY_WAIT_SECONDS}" 0
require_int "--timeout-seconds" "${TIMEOUT_SECONDS}" 0
require_int "--timeout-minutes" "${TIMEOUT_MINUTES}" 0
require_int "--polling-interval-seconds" "${POLLING_INTERVAL_SECONDS}" 1
if [[ "${TIMEOUT_SECONDS}" -gt 0 && "${TIMEOUT_MINUTES}" -gt 0 ]]; then
  echo "ERROR: set only one of --timeout-seconds or --timeout-minutes" >&2
  exit 1
fi
TIMEOUT_SEC="${TIMEOUT_SECONDS}"
if [[ "${TIMEOUT_MINUTES}" -gt 0 ]]; then
  TIMEOUT_SEC=$((TIMEOUT_MINUTES * 60))
fi
RETRY_ON="$(printf '%s' "${RETRY_ON}" | tr '[:upper:]' '[:lower:]')"
if [[ "${RETRY_ON}" != "any" && "${RETRY_ON}" != "error" && "${RETRY_ON}" != "timeout" ]]; then
  echo "ERROR: --retry-on must be any, error, or timeout" >&2
  exit 1
fi
SHELL_NAME="$(printf '%s' "${SHELL_NAME}" | tr '[:upper:]' '[:lower:]')"
if [[ "${SHELL_NAME}" != "bash" && "${SHELL_NAME}" != "sh" ]]; then
  echo "ERROR: --shell must be bash or sh" >&2
  exit 1
fi

run_command() {
  local cmd="$1"
  TIMED_OUT="false"
  if [[ "${TIMEOUT_SEC}" -le 0 ]]; then
    set +e
    "${SHELL_NAME}" -c "${cmd}"
    EXIT_CODE=$?
    set -e
    return 0
  fi
  set +e
  "${SHELL_NAME}" -c "${cmd}" &
  local pid=$!
  set -e
  local elapsed=0
  while kill -0 "${pid}" 2>/dev/null; do
    if [[ "${elapsed}" -ge "${TIMEOUT_SEC}" ]]; then
      kill -TERM "${pid}" 2>/dev/null || true
      sleep 1
      kill -KILL "${pid}" 2>/dev/null || true
      wait "${pid}" 2>/dev/null || true
      TIMED_OUT="true"
      EXIT_CODE=124
      return 0
    fi
    sleep "${POLLING_INTERVAL_SECONDS}"
    elapsed=$((elapsed + POLLING_INTERVAL_SECONDS))
  done
  set +e
  wait "${pid}"
  EXIT_CODE=$?
  set -e
}

should_retry() {
  if [[ "${EXIT_CODE}" -eq 0 ]]; then
    return 1
  fi
  if [[ -n "${RETRY_ON_EXIT_CODE}" ]]; then
    local part
    IFS=',' read -r -a codes <<< "${RETRY_ON_EXIT_CODE}"
    for part in "${codes[@]}"; do
      part="$(printf '%s' "${part}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
      if [[ "${part}" == "${EXIT_CODE}" ]]; then
        return 0
      fi
    done
    return 1
  fi
  if [[ "${RETRY_ON}" == "timeout" ]]; then
    [[ "${TIMED_OUT}" == "true" ]]
    return $?
  fi
  if [[ "${RETRY_ON}" == "error" ]]; then
    [[ "${TIMED_OUT}" != "true" ]]
    return $?
  fi
  return 0
}

EXIT_CODE=1
TIMED_OUT="false"
ATTEMPTS=0
ACTIVE="${COMMAND}"
attempt=1
while [[ "${attempt}" -le "${MAX_ATTEMPTS}" ]]; do
  ATTEMPTS="${attempt}"
  echo "attempt : ${attempt}/${MAX_ATTEMPTS}"
  run_command "${ACTIVE}"
  if [[ "${TIMED_OUT}" == "true" ]]; then
    echo "timeout : true" >&2
  fi
  if [[ "${EXIT_CODE}" -eq 0 || "${attempt}" -eq "${MAX_ATTEMPTS}" ]]; then
    break
  fi
  if ! should_retry; then
    break
  fi
  warn="$(printf '%s' "${WARNING_ON_RETRY}" | tr '[:upper:]' '[:lower:]')"
  if [[ "${warn}" == "true" || "${warn}" == "1" || "${warn}" == "yes" ]]; then
    echo "WARNING: retrying after exit ${EXIT_CODE} (attempt ${attempt}/${MAX_ATTEMPTS})" >&2
  fi
  failed_code="${EXIT_CODE}"
  if [[ -n "${ON_RETRY_COMMAND}" ]]; then
    run_command "${ON_RETRY_COMMAND}"
    if [[ "${EXIT_CODE}" -ne 0 ]]; then
      echo "WARNING: on_retry_command exited ${EXIT_CODE}" >&2
    fi
    EXIT_CODE="${failed_code}"
    TIMED_OUT="false"
  fi
  if [[ -n "${NEW_COMMAND_ON_RETRY}" ]]; then
    ACTIVE="${NEW_COMMAND_ON_RETRY}"
  fi
  if [[ "${RETRY_WAIT_SECONDS}" -gt 0 ]]; then
    sleep "${RETRY_WAIT_SECONDS}"
  fi
  attempt=$((attempt + 1))
done

SUCCEEDED="false"
if [[ "${EXIT_CODE}" -eq 0 ]]; then
  SUCCEEDED="true"
fi
echo "attempts : ${ATTEMPTS}"
echo "exit_code : ${EXIT_CODE}"
echo "succeeded : ${SUCCEEDED}"
echo "timed_out : ${TIMED_OUT}"
if [[ -n "${OUTPUT}" ]]; then
  {
    echo "attempts=${ATTEMPTS}"
    echo "exit_code=${EXIT_CODE}"
    echo "succeeded=${SUCCEEDED}"
    echo "timed_out=${TIMED_OUT}"
  } >> "${OUTPUT}"
fi
exit "${EXIT_CODE}"
