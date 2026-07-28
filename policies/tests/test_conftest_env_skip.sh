#!/usr/bin/env bash
# =============================================================================
# FILE_NAME: test_conftest_env_skip.sh
# DESCRIPTION: Integration tests for SPVS_SKIP_POLICY env skips via conftest CLI.
# VERSION: 1.1.0
# EXIT_CODES/SIGNALS: 0 pass, 1 test failure
# AUTHORS: DevOps Team
# =============================================================================
set -euo pipefail

PROJECT_PREFIX="[TEST-ENV-SKIP]"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFTEST_BIN="${CONFTEST_BIN:-conftest}"
POLICY_LIB="${ROOT}/policies/conftest/github_actions/lib"
POLICY_WORKFLOW="${ROOT}/policies/conftest/github_actions/workflow"

TMP=""
failures=0

cleanup() {
  [[ -n "${TMP}" && -f "${TMP}" ]] && rm -f "${TMP}"
}
trap cleanup EXIT

_log() {
  printf '%s %s\n' "${PROJECT_PREFIX}" "$1"
}

scan_workflow() {
  "${CONFTEST_BIN}" test --parser yaml -n workflow \
    -p "${POLICY_WORKFLOW}" -p "${POLICY_LIB}" "$1"
}

assert_scan_passes() {
  local label="$1"
  local file="$2"
  if scan_workflow "${file}" >/dev/null 2>&1; then
    _log "PASS: ${label}"
  else
    _log "FAIL: ${label}"
    failures=$((failures + 1))
  fi
}

assert_scan_fails() {
  local label="$1"
  local file="$2"
  if scan_workflow "${file}" >/dev/null 2>&1; then
    _log "FAIL: ${label} (expected failure)"
    failures=$((failures + 1))
  else
    _log "PASS: ${label}"
  fi
}

TMP="$(mktemp --suffix=.yml)"
cat >"${TMP}" <<'EOF'
name: skip-test
on:
  workflow_call: {}
env:
  SPVS_SKIP_POLICY: CKV2_SPVS_5B
  SPVS_SKIP_REASON: monorepo layout integration test
permissions:
  contents: read
jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - uses: ../other-action
EOF
assert_scan_passes "workflow env skip suppresses CKV2_SPVS_5B" "${TMP}"

TMP="$(mktemp --suffix=.yml)"
cat >"${TMP}" <<'EOF'
name: skip-test
on:
  workflow_call: {}
permissions:
  contents: read
jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    env:
      SPVS_SKIP_POLICY: CKV2_SPVS_5, CKV2_SPVS_6
      SPVS_SKIP_REASON: multi-policy skip test
    steps:
      - uses: ../other-action
      - run: |
          set -euo pipefail
          echo ${inputs.message}
EOF
assert_scan_passes "job env multi-policy skip" "${TMP}"

TMP="$(mktemp --suffix=.yml)"
cat >"${TMP}" <<'EOF'
name: skip-test
on:
  workflow_call: {}
permissions:
  contents: read
jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - uses: ../other-action
EOF
assert_scan_fails "violation without skip fails scan" "${TMP}"

TMP="$(mktemp --suffix=.yml)"
cat >"${TMP}" <<'EOF'
name: skip-test
on:
  workflow_call: {}
env:
  SPVS_SKIP_POLICY: CKV2_SPVS_5B
permissions:
  contents: read
jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - uses: ../other-action
EOF
assert_scan_fails "SPVS_META_1 when SPVS_SKIP_REASON missing" "${TMP}"

DUMMY="${ROOT}/workflows/common/dummy-workflow/workflow.yml"
if [[ -f "${DUMMY}" ]]; then
  assert_scan_passes "repository fixture ${DUMMY} scans clean" "${DUMMY}"
fi

if [[ "${failures}" -gt 0 ]]; then
  echo "${failures} env skip test(s) failed" >&2
  exit 1
fi

echo "All conftest env skip tests passed"
