# FILE_NAME: spvs_skip.rego
# DESCRIPTION: Shared SPVS_SKIP_POLICY env skip helpers for workflow and composite packages.
# VERSION: 1.0.0
# AUTHORS: DevOps Team

package lib

import rego.v1

skip_pair := {
	"CKV2_SPVS_5": "CKV2_SPVS_5B",
	"CKV2_SPVS_5B": "CKV2_SPVS_5",
}

# INTENT: Return true when check_id is listed in SPVS_SKIP_POLICY on any scope (union inheritance).
# INPUT: check_id string; scopes array of objects (workflow, job, step, or composite root/step).
# OUTPUT: defined when skipped.
# SIDE_EFFECTS: none.
policy_skipped(check_id, scopes) if {
	some scope in scopes
	is_object(scope)
	scope_has_skip_id(scope, check_id)
}

policy_skipped(check_id, scopes) if {
	paired := skip_pair[check_id]
	some scope in scopes
	is_object(scope)
	scope_has_skip_id(scope, paired)
}

# INTENT: True when scope.env.SPVS_SKIP_POLICY contains check_id (comma-separated list).
# INPUT: scope object; check_id string.
# OUTPUT: defined when matched.
# SIDE_EFFECTS: none.
scope_has_skip_id(scope, check_id) if {
	env_block := object.get(scope, "env", {})
	raw_skip := object.get(env_block, "SPVS_SKIP_POLICY", "")
	is_string(raw_skip)
	trim_space(raw_skip) != ""
	some part in split(raw_skip, ",")
	trim_space(part) == check_id
}
