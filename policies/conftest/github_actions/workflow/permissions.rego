# FILE_NAME: permissions.rego
# DESCRIPTION: Workflow IAM and permissions policies (CKV2_SPVS + CKV2_GHA_1).
# VERSION: 1.1.0
# AUTHORS: DevOps Team

package workflow

import rego.v1

# CKV2_GHA_1: top-level permissions must not be write-all (scalar or any scope)
deny contains msg if {
	permissions_is_write_all(input.permissions)
	msg := "CKV2_GHA_1: top-level permissions must not be write-all"
}

# CKV2_SPVS_10: any permissions block must not use write-all (workflow or job, any scope)
deny contains msg if {
	walk(input, [path, value])
	count(path) > 0
	path[count(path) - 1] == "permissions"
	value == "write-all"
	loc := permissions_location(path)
	msg := sprintf("CKV2_SPVS_10: %s permissions must not be write-all", [loc])
}

deny contains msg if {
	walk(input, [path, value])
	count(path) > 0
	path[count(path) - 1] == "permissions"
	is_object(value)
	some scope
	value[scope] == "write-all"
	loc := permissions_location(path)
	msg := sprintf("CKV2_SPVS_10: %s permissions.%s must not be write-all", [loc, scope])
}

# CKV2_SPVS_9: workflow must declare explicit top-level permissions
deny contains msg if {
	not input.permissions
	msg := "CKV2_SPVS_9: workflow must declare explicit top-level permissions"
}

# CKV2_SPVS_9: workflow-level permissions must not grant write scopes
deny contains msg if {
	is_object(input.permissions)
	some key in write_permission_keys
	input.permissions[key] == "write"
	msg := sprintf("CKV2_SPVS_9: workflow permissions.%s must not be write", [key])
}

# CKV2_SPVS_15: prohibit pull_request_target
deny contains msg if {
	on := input["on"]
	regex.match(`pull_request_target`, json.marshal(on))
	msg := "CKV2_SPVS_15: pull_request_target trigger is prohibited"
}

# CKV2_SPVS_1: every job must declare permissions
deny contains msg if {
	some job_name
	job := input.jobs[job_name]
	not job.permissions
	msg := sprintf("CKV2_SPVS_1: job %s must declare explicit permissions", [job_name])
}

# CKV2_SPVS_8: OIDC cloud actions require id-token write
deny contains msg if {
	some job_name
	job := input.jobs[job_name]
	regex.match(oidc_action_pattern, json.marshal(job.steps))
	not job.permissions["id-token"] == "write"
	msg := sprintf("CKV2_SPVS_8: job %s using cloud OIDC action requires permissions.id-token: write", [job_name])
}

# CKV2_SPVS_11: jobs with contents write need environment
deny contains msg if {
	some job_name
	job := input.jobs[job_name]
	job.permissions.contents == "write"
	not job.environment
	msg := sprintf("CKV2_SPVS_11: job %s with contents:write must declare environment", [job_name])
}

# CKV2_SPVS_12: bare self-hosted runner prohibited
deny contains msg if {
	some job_name
	job := input.jobs[job_name]
	job["runs-on"] == "self-hosted"
	msg := sprintf("CKV2_SPVS_12: job %s must not use bare self-hosted runner", [job_name])
}
