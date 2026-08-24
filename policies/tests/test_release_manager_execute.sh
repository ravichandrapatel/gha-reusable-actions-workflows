#!/usr/bin/env bash
# =============================================================================
# FILE_NAME: test_release_manager_execute.sh
# DESCRIPTION: Unit tests for release-manager-lib.sh helpers.
# VERSION: 1.0.0
# EXIT_CODES/SIGNALS: 0 pass, 1 assertion failure
# AUTHORS: DevOps Team
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
LIB="${ROOT}/scripts/release-manager-lib.sh"
# shellcheck source=../../scripts/release-manager-lib.sh
source "${LIB}"

FIXTURE="$(mktemp -d)"
trap 'rm -rf "${FIXTURE}"' EXIT

setup_fixture_repo() {
  git -C "${FIXTURE}" init -q
  git -C "${FIXTURE}" config user.email "test@example.com"
  git -C "${FIXTURE}" config user.name "Test"
  mkdir -p "${FIXTURE}/workflows/demo/release-demo"
  printf 'name: demo\n' >"${FIXTURE}/workflows/demo/release-demo/workflow.yml"
  git -C "${FIXTURE}" add .
  git -C "${FIXTURE}" commit -q -m "init"
  git -C "${FIXTURE}" tag -a "release-demo/v1.0.0" -m "v1.0.0"
  printf '\n# patch\n' >>"${FIXTURE}/workflows/demo/release-demo/workflow.yml"
  git -C "${FIXTURE}" add workflows/demo/release-demo/workflow.yml
  git -C "${FIXTURE}" commit -q -m "patch"
  git -C "${FIXTURE}" tag -a "release-demo/v1.0.1" -m "v1.0.1"
  git -C "${FIXTURE}" tag -a "release-demo/v1.1.0" -m "v1.1.0"
}

assert_eq() {
  local got="$1"
  local want="$2"
  local label="$3"
  if [[ "${got}" != "${want}" ]]; then
    echo "FAIL ${label}: expected '${want}', got '${got}'" >&2
    exit 1
  fi
}

cd "${FIXTURE}"
setup_fixture_repo

prev="$(release_manager_find_prev_versioned_tag "release-demo/v1.1.0" "release-demo/v*.*.*")"
assert_eq "${prev}" "release-demo/v1.0.1" "prev tag for v1.1.0"

prev_first="$(release_manager_find_prev_versioned_tag "release-demo/v1.0.0" "release-demo/v*.*.*")"
assert_eq "${prev_first}" "" "no prev tag for first version"

wf="$(release_manager_discover_workflow_file_at_ref "release-demo/v1.0.0" "workflows/demo/release-demo")"
assert_eq "${wf}" "workflow.yml" "workflow file at tag"

git checkout -q main 2>/dev/null || git checkout -q master
release_manager_assert_release_tag_commit "$(git rev-parse HEAD)" "action" "ignored"
release_manager_assert_release_tag_commit "$(git rev-parse HEAD)" "workflow" "release-demo"

mkdir -p .github/workflows
printf 'name: synced\n' >.github/workflows/release-demo.yml
git add .github/workflows/release-demo.yml
git commit -q -m "sync"
base_sha="$(git rev-parse HEAD~1)"
release_manager_assert_release_tag_commit "${base_sha}" "workflow" "release-demo"

if ( release_manager_assert_release_tag_commit "${base_sha}" "action" "ignored" ); then
  echo "FAIL action tag guard should reject extra sync commit" >&2
  exit 1
fi

echo "OK release-manager-lib tests passed"
