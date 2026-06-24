#!/usr/bin/env bash
# =============================================================================
# FILE_NAME: test_conftest_inline_skip.sh
# DESCRIPTION: Unit tests for conftest-gha.sh inline policy skip filtering.
# VERSION: 1.0.0
# EXIT_CODES/SIGNALS: 0 pass, 1 failure
# AUTHORS: DevOps Team
# =============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT}"

# shellcheck disable=SC1091
source "${ROOT}/policies/scripts/conftest-gha.sh"

failures=0

assert_suppressed() {
  local label="$1"
  local file_path="$2"
  local check_id="$3"
  local msg="$4"
  if spvs_conftest_failure_suppressed "${ROOT}" "${file_path}" "${check_id}" "${msg}"; then
    echo "PASS: ${label}"
  else
    echo "FAIL: ${label}" >&2
    failures=$((failures + 1))
  fi
}

assert_not_suppressed() {
  local label="$1"
  local file_path="$2"
  local check_id="$3"
  local msg="$4"
  if spvs_conftest_failure_suppressed "${ROOT}" "${file_path}" "${check_id}" "${msg}"; then
    echo "FAIL: ${label} (expected not suppressed)" >&2
    failures=$((failures + 1))
  else
    echo "PASS: ${label}"
  fi
}

FIXTURE="${ROOT}/workflows/common/dummy-workflow/workflow.yml"
TMP="$(mktemp)"
trap 'rm -f "${TMP}"' EXIT

cat > "${TMP}" <<'EOF'
permissions:
  contents: read
on:
  workflow_call: {}
jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - uses: ../other-action  # spvs:skip=CKV2_SPVS_5: monorepo layout
        run: |
          set -euo pipefail
          echo ok
EOF

MSG5="CKV2_SPVS_5: job build uses ../other-action must use SHA, ./, docker://, or internal /actions/ tag"
MSG5B="CKV2_SPVS_5B: job build uses ../other-action must not use ../ local action refs"

assert_suppressed "spvs:skip=CKV2_SPVS_5 suppresses CKV2_SPVS_5" "${TMP}" "CKV2_SPVS_5" "${MSG5}"
assert_suppressed "spvs:skip=CKV2_SPVS_5 also suppresses CKV2_SPVS_5B on ../ uses" "${TMP}" "CKV2_SPVS_5B" "${MSG5B}"

cat > "${TMP}" <<'EOF'
# spvs:skip=CKV2_SPVS_2
permissions:
  contents: read
on:
  workflow_call: {}
jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - run: echo no pipefail
EOF

MSG2="CKV2_SPVS_2: job build run block must include set -euo pipefail"
assert_suppressed "file-level spvs:skip comment" "${TMP}" "CKV2_SPVS_2" "${MSG2}"

cat > "${TMP}" <<'EOF'
permissions:
  contents: read
on:
  workflow_call: {}
jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - uses: ../other-action
        run: |
          set -euo pipefail
          echo ok
EOF

assert_not_suppressed "violation without skip stays active" "${TMP}" "CKV2_SPVS_5B" "${MSG5B}"

if [[ -f "${FIXTURE}" ]]; then
  if bash "${ROOT}/policies/scripts/conftest-gha.sh" -f "${FIXTURE}" >/dev/null 2>&1; then
    echo "PASS: repository fixture ${FIXTURE} scans clean"
  else
    echo "FAIL: repository fixture ${FIXTURE} should pass" >&2
    failures=$((failures + 1))
  fi
fi

if [[ "${failures}" -gt 0 ]]; then
  echo "${failures} inline skip test(s) failed" >&2
  exit 1
fi

echo "All conftest-gha inline skip tests passed"
