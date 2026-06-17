# FILE_NAME: lib.rego
# DESCRIPTION: Shared helpers for GitHub Actions workflow policy checks.
# VERSION: 1.0.0
# AUTHORS: DevOps Team

package workflow

import rego.v1

write_permission_keys := ["contents", "packages", "id-token", "security-events", "deployments"]

forbidden_env_keys := {
	"AWS_ACCESS_KEY_ID",
	"AWS_SECRET_ACCESS_KEY",
	"AWS_SESSION_TOKEN",
	"GCP_SERVICE_ACCOUNT_KEY",
	"GOOGLE_APPLICATION_CREDENTIALS",
	"AZURE_CLIENT_SECRET",
	"ARM_CLIENT_SECRET",
}

shell_injection_patterns := [
	`\$\{\{\s*github.event.issue.title\s*\}\}`,
	`\$\{\{\s*github.event.issue.body\s*\}\}`,
	`\$\{\{\s*github.event.pull_request.title\s*\}\}`,
	`\$\{\{\s*github.event.pull_request.body\s*\}\}`,
	`\$\{\{\s*github.event.comment.body\s*\}\}`,
	`\$\{\{\s*github.event.review.body\s*\}\}`,
	`\$\{\{\s*github.event.review_comment.body\s*\}\}`,
	`\$\{\{\s*github.event.pages.*.page_name\s*\}\}`,
	`\$\{\{\s*github.event.head_commit.message\s*\}\}`,
	`\$\{\{\s*github.event.head_commit.author.email\s*\}\}`,
	`\$\{\{\s*github.event.head_commit.author.name\s*\}\}`,
	`\$\{\{\s*github.event.commits.*.author.email\s*\}\}`,
	`\$\{\{\s*github.event.commits.*.author.name\s*\}\}`,
	`\$\{\{\s*github.event.pull_request.head.ref\s*\}\}`,
	`\$\{\{\s*github.event.pull_request.head.label\s*\}\}`,
	`\$\{\{\s*github.event.pull_request.head.repo.default_branch\s*\}\}`,
	`\$\{\{\s*github.head_ref\s*\}\}`,
]

oidc_action_pattern := `(configure-aws-credentials|azure/login|google-github-actions/auth)`

# permissions_is_write_all: scalar write-all or any permission scope set to write-all
permissions_is_write_all(perms) if {
	perms == "write-all"
}

permissions_is_write_all(perms) if {
	is_object(perms)
	some _key
	perms[_key] == "write-all"
}

# permissions_location: human-readable path for a permissions block
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

step_run(step) := run if {
	is_string(step.run)
	run := step.run
}

step_run(step) := "" if {
	not is_string(step.run)
}

step_uses(step) := uses if {
	is_string(step.uses)
	uses := step.uses
}

step_uses(step) := "" if {
	not is_string(step.uses)
}

uses_allowed(uses) if {
	startswith(uses, "./")
}

uses_allowed(uses) if {
	startswith(uses, "docker://")
}

uses_allowed(uses) if {
	regex.match(`.*@[0-9a-fA-F]{40}(\s|$|#)`, uses)
}

uses_allowed(uses) if {
	regex.match(`^[^@]+/actions/.+@(v[0-9]+|[0-9]+\.[0-9]+\.[0-9]+|[A-Za-z0-9._-]+-v[0-9]+)$`, uses)
}

job_steps(job) := steps if {
	is_array(job.steps)
	steps := job.steps
}

job_steps(job) := [] if {
	not is_array(job.steps)
}

env_truthy(val) if {
	val == true
}

env_truthy(val) if {
	val == "true"
}

env_truthy(val) if {
	val == "True"
}

env_truthy(val) if {
	val == "1"
}

python_unbuffered_env(step) if {
	is_object(step.env)
	step.env.PYTHONUNBUFFERED
}

all_steps contains entry if {
	some job_name
	job := input.jobs[job_name]
	step := job.steps[_]
	entry := {"job": job_name, "step": step}
}
