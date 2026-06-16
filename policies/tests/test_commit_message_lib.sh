#!/usr/bin/env bash
# =============================================================================
# FILE_NAME: test_commit_message_lib.sh
# DESCRIPTION: Unit tests for commit_message_lib.sh validation and semver mapping.
# VERSION: 1.2.0
# EXIT_CODES/SIGNALS: 0 pass, 1 assertion failure
# AUTHORS: DevOps Team
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../scripts/commit_message_lib.sh
source "${SCRIPT_DIR}/../scripts/commit_message_lib.sh"

assert_valid() {
  local subject="$1"
  if ! commit_msg_validate_subject "${subject}" >/dev/null 2>&1; then
    echo "FAIL expected valid: ${subject}" >&2
    exit 1
  fi
}

assert_invalid() {
  local subject="$1"
  if commit_msg_validate_subject "${subject}" >/dev/null 2>&1; then
    echo "FAIL expected invalid: ${subject}" >&2
    exit 1
  fi
}

assert_bump() {
  local subject="$1"
  local expected="$2"
  local body bump
  body="$(commit_msg_strip_ticket_prefix "${subject}")"
  bump="$(commit_msg_classify_semver_bump "${body}")"
  if [[ "${bump}" != "${expected}" ]]; then
    echo "FAIL bump for '${subject}': expected ${expected}, got ${bump}" >&2
    exit 1
  fi
}

# Pattern 1: TICKET keyword(scope): message
assert_valid "DCDT-1234 feat(release): add commit validation hook"
assert_valid "sctask9876543 fix: correct path handling"
assert_valid "DCDT-1999 chore(deps): bump checkov"
assert_valid "SCTASK123 docs: update testing checklist"
assert_valid "INC001 refactor(api): simplify parsing"
assert_valid "DCDT-200 perf(cache): reduce lookups"
assert_valid "SCTASK300 test(hook): add coverage"
assert_valid "INC400 style: apply shellcheck fixes"

# Pattern 2: TICKET: keyword(scope) message
assert_valid "DCDT-1234: feat(release) add commit validation hook"
assert_valid "SCTASK999: fix correct path handling"
assert_valid "inc42: docs update testing checklist"

# Pattern 3: TICKET: keyword() message
assert_valid "DCDT-1234: feat() add commit validation hook"
assert_valid "SCTASK888: fix() correct path handling"

# Pattern 4: TICKET keyword(): message
assert_valid "DCDT-1234 feat(): add commit validation hook"
assert_valid "INC777 fix(): correct path handling"

assert_valid "Merge branch 'feature/foo' into main"

assert_invalid "feat: missing ticket prefix"
assert_invalid "DCDT-1234 random words without keyword"
assert_invalid "JIRA-123 feat: wrong ticket system"
assert_invalid "DCDT-1234: random words without keyword"
assert_invalid "DCDT-1234 bugfix: deprecated keyword"
assert_invalid "SCTASK123 skip ci: deprecated keyword"
assert_invalid "DCDT-1234 ci: deprecated keyword"
assert_invalid "DCDT-1234 build: deprecated keyword"
assert_invalid "DCDT-1234 revert: deprecated keyword"

# Semver bumps (pattern 1)
assert_bump "DCDT-1001 feat: new capability" "minor"
assert_bump "DCDT-1001 fix: bug" "patch"
assert_bump "DCDT-1001 chore: maintenance" "patch"
assert_bump "DCDT-1001 docs: readme" "skip"
assert_bump "DCDT-1001 refactor: cleanup" "skip"
assert_bump "DCDT-1001 perf: faster scan" "skip"
assert_bump "DCDT-1001 test: add cases" "skip"
assert_bump "DCDT-1001 style: format shell" "skip"

# Semver bumps (patterns 2–4)
assert_bump "DCDT-1002: feat(release) new capability" "minor"
assert_bump "DCDT-1003: fix() bug fix" "patch"
assert_bump "DCDT-1004 feat(): new capability" "minor"
assert_bump "SCTASK55: chore() maintenance" "patch"

echo "All commit_message_lib tests passed"
