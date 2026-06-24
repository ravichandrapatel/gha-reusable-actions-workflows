# FILE_NAME: lib.rego
# DESCRIPTION: Shared helpers for composite action policy checks.
# VERSION: 1.1.0
# AUTHORS: DevOps Team

package composite

import rego.v1

import data.lib

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

composite_steps contains step if {
	input.runs.using == "composite"
	step := input.runs.steps[_]
}

all_steps contains entry if {
	input.runs.using == "composite"
	some idx
	step := input.runs.steps[idx]
	entry := {"step_index": idx, "step": step}
}

step_yaml_path(entry) := path if {
	path := sprintf("runs.steps[%d]", [entry.step_index])
}

# INTENT: Build composite root + step skip scope chain (union inheritance).
# INPUT: step object from runs.steps.
# OUTPUT: array of scope objects.
# SIDE_EFFECTS: none.
skip_scopes_for_composite_step(step) := scopes if {
	scopes := [input, step]
}

# INTENT: Build composite root-only skip scope chain.
# INPUT: none (uses input document).
# OUTPUT: array of scope objects.
# SIDE_EFFECTS: none.
skip_scopes_composite := scopes if {
	scopes := [input]
}

# INTENT: Guard deny rules — true when check_id is not skipped in any scope.
# INPUT: check_id string; scopes array.
# OUTPUT: defined when policy must still fire.
# SIDE_EFFECTS: none.
policy_active(check_id, scopes) if {
	not lib.policy_skipped(check_id, scopes)
}
