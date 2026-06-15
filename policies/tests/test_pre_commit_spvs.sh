# =============================================================================
# FILE_NAME: test_pre_commit_spvs.sh
# DESCRIPTION: Unit tests for pre_commit_spvs.sh helper functions.
# VERSION: 1.0.0
# EXIT_CODES/SIGNALS: 0 pass, 1 assertion failure
# AUTHORS: DevOps Team
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${SCRIPT_DIR}/../scripts/pre_commit_spvs.sh"

assert_eq() {
  local expected="$1"
  local actual="$2"
  local label="$3"
  if [[ "${expected}" != "${actual}" ]]; then
    echo "FAIL ${label}: expected '${expected}', got '${actual}'" >&2
    exit 1
  fi
}

assert_eq "actions/common/prbot" "$(component_from_path "actions/common/prbot/action.yml")" "component_from_path action"
assert_eq "workflows/common/dummy-workflow" "$(component_from_path "workflows/common/dummy-workflow/workflow.yml")" "component_from_path workflow"
assert_eq "" "$(component_from_path ".github/workflows/release-manager.yml")" "component_from_path repo workflow"

CHANGED_FILES=("policies/github_actions/NoCurlPipeBash.yaml")
if policies_changed; then
  : "policies_changed ok"
else
  echo "FAIL policies_changed should be true" >&2
  exit 1
fi

CHANGED_FILES=("actions/common/semver/action.yml")
if policies_changed; then
  echo "FAIL policies_changed should be false" >&2
  exit 1
fi
if component_yaml_changed "actions/common/semver"; then
  : "component_yaml_changed ok"
else
  echo "FAIL component_yaml_changed should be true for action.yml" >&2
  exit 1
fi

CHANGED_FILES=("actions/common/semver/run.sh")
if component_yaml_changed "actions/common/semver"; then
  echo "FAIL component_yaml_changed should be false for non-yaml" >&2
  exit 1
fi

CHANGED_FILES=(".github/workflows/release-manager.yml")
if repo_workflows_changed; then
  : "repo_workflows_changed ok"
else
  echo "FAIL repo_workflows_changed should be true" >&2
  exit 1
fi

echo "All pre_commit_spvs.sh helper tests passed"
