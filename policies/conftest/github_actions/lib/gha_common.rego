# FILE_NAME: gha_common.rego
# DESCRIPTION: Shared GitHub Actions step helpers and constants for workflow and composite packages.
# VERSION: 1.0.0
# AUTHORS: DevOps Team

package lib

import rego.v1

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

inputs_in_run(run) if {
	regex.match(`[\s\S]*\$\{\{\s*(inputs\.|github\.event\.inputs\.)`, run)
}

inputs_in_run(run) if {
	regex.match(`[\s\S]*\$\{inputs\.`, run)
}

curl_pipe_shell(run) if {
	regex.match(`[\s\S]*(curl|wget)`, run)
	regex.match(`[\s\S]*\|\s*(ba)?sh\b`, run)
}

curl_pipe_shell(run) if {
	regex.match(`[\s\S]*(ba)?sh\s*<`, run)
	regex.match(`[\s\S]*(curl|wget)`, run)
}

# INTENT: Guard deny rules — true when check_id is not skipped in any scope.
# INPUT: check_id string; scopes array.
# OUTPUT: defined when policy must still fire.
# SIDE_EFFECTS: none.
policy_active(check_id, scopes) if {
	not policy_skipped(check_id, scopes)
}

# INTENT: SPVS_SKIP_POLICY set without a non-empty SPVS_SKIP_REASON.
# INPUT: env object.
# OUTPUT: defined when reason is missing.
# SIDE_EFFECTS: none.
skip_reason_missing(env_block) if {
	is_object(env_block)
	raw_skip := object.get(env_block, "SPVS_SKIP_POLICY", "")
	is_string(raw_skip)
	trim_space(raw_skip) != ""
	reason := object.get(env_block, "SPVS_SKIP_REASON", "")
	not is_string(reason)
}

skip_reason_missing(env_block) if {
	is_object(env_block)
	raw_skip := object.get(env_block, "SPVS_SKIP_POLICY", "")
	is_string(raw_skip)
	trim_space(raw_skip) != ""
	reason := object.get(env_block, "SPVS_SKIP_REASON", "")
	is_string(reason)
	trim_space(reason) == ""
}
