# FILE_NAME: lib.rego
# DESCRIPTION: Workflow-only helpers (jobs, permissions, skip scopes, YAML paths).
# VERSION: 2.0.0
# AUTHORS: DevOps Team

package workflow

import rego.v1

write_permission_keys := ["contents", "packages", "id-token", "security-events", "deployments"]

oidc_action_pattern := `(configure-aws-credentials|azure/login|google-github-actions/auth)`

permissions_is_write_all(perms) if {
	perms == "write-all"
}

permissions_is_write_all(perms) if {
	is_object(perms)
	some _key
	perms[_key] == "write-all"
}

permissions_location(path) := "top-level" if {
	count(path) == 1
	path[0] == "permissions"
}

permissions_location(path) := loc if {
	count(path) == 3
	path[0] == "jobs"
	path[2] == "permissions"
	loc := sprintf("job %s", [path[1]])
}

permissions_location(path) := loc if {
	count(path) > 0
	path[count(path) - 1] == "permissions"
	not count(path) == 1
	not count(path) == 3
	loc := concat(".", path)
}

all_steps contains entry if {
	some job_name
	job := input.jobs[job_name]
	some idx
	step := job.steps[idx]
	entry := {
		"job": job_name,
		"step_index": idx,
		"step": step,
	}
}

step_yaml_path(entry) := path if {
	path := sprintf("jobs.%s.steps[%d]", [entry.job, entry.step_index])
}

skip_scopes_workflow := scopes if {
	scopes := [input]
}

skip_scopes_for_job(job_name) := scopes if {
	scopes := [input, input.jobs[job_name]]
}

skip_scopes_for_step(job_name, step) := scopes if {
	scopes := [input, input.jobs[job_name], step]
}

permissions_skip_scopes(path) := scopes if {
	count(path) == 1
	path[0] == "permissions"
	scopes := [input]
}

permissions_skip_scopes(path) := scopes if {
	count(path) == 3
	path[0] == "jobs"
	path[2] == "permissions"
	job_name := path[1]
	scopes := [input, input.jobs[job_name]]
}

permissions_skip_scopes(path) := scopes if {
	count(path) > 0
	path[count(path) - 1] == "permissions"
	not count(path) == 1
	not count(path) == 3
	scopes := [input]
}
