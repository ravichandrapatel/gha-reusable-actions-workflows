#!/usr/bin/env bash
# =============================================================================
# FILE_NAME: test_checkov_inline_skip.sh
# DESCRIPTION: Unit tests for checkov_inline_skip_lib.sh inline skip matching.
# VERSION: 1.0.0
# EXIT_CODES/SIGNALS: 0 pass, 1 assertion failure
# AUTHORS: DevOps Team
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../scripts/checkov_inline_skip_lib.sh"

assert_skip_match() {
  local check_id="$1"
  local line="$2"
  local label="$3"
  if ! spvs_checkov_line_skips_check "${check_id}" "${line}"; then
    echo "FAIL ${label}: expected skip match for ${check_id}" >&2
    exit 1
  fi
}

assert_skip_no_match() {
  local check_id="$1"
  local line="$2"
  local label="$3"
  if spvs_checkov_line_skips_check "${check_id}" "${line}"; then
    echo "FAIL ${label}: expected no skip match for ${check_id}" >&2
    exit 1
  fi
}

assert_skip_match "CKV2_SPVS_5B" \
  "        uses: ../other-action  # checkov:skip=CKV2_SPVS_5,CKV2_SPVS_5B: documented exception" \
  "same-line skip"

assert_skip_match "CKV_GHA_1" \
  "# checkov:skip=CKV_GHA_1,CKV_GHA_2: dual skip" \
  "multi-id skip first"

assert_skip_match "CKV_GHA_2" \
  "# checkov:skip=CKV_GHA_1,CKV_GHA_2: dual skip" \
  "multi-id skip second"

assert_skip_no_match "CKV2_SPVS_5B" \
  "        uses: ../other-action  # checkov:skip=CKV2_SPVS_5: wrong id" \
  "wrong check id"

if ! command -v yq >/dev/null 2>&1; then
  echo "SKIP integration: yq not installed"
  echo "All checkov_inline_skip_lib unit tests passed"
  exit 0
fi

STAGING="$(mktemp -d)"
mkdir -p "${STAGING}/.github/workflows"
cat >"${STAGING}/.github/workflows/test-skip.yml" <<'EOF'
name: test-skip
on: workflow_dispatch
permissions:
  contents: read
jobs:
  test:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - name: use parent path
        uses: ../other-action  # checkov:skip=CKV2_SPVS_5,CKV2_SPVS_5B: documented exception
EOF

REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
if command -v checkov >/dev/null 2>&1; then
  if spvs_run_checkov_with_inline_skips "${STAGING}" "${REPO_ROOT}" "0"; then
    : "integration skip ok"
  else
    echo "FAIL spvs_run_checkov_with_inline_skips should pass when CKV2_SPVS_5B is skipped" >&2
    rm -rf "${STAGING}"
    exit 1
  fi
else
  echo "SKIP integration: checkov not installed"
fi

rm -rf "${STAGING}"
echo "All checkov_inline_skip_lib tests passed"
