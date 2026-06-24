# FILE_NAME: steps.rego
# DESCRIPTION: Workflow step-level policies (CKV_GHA + CKV2_SPVS supply chain).
# VERSION: 1.2.0
# AUTHORS: DevOps Team

package workflow

import rego.v1

# CKV_GHA_1: ACTIONS_ALLOW_UNSECURE_COMMANDS on job or step env
deny contains msg if {
	some job_name
	job := input.jobs[job_name]
	is_object(job.env)
	env_truthy(job.env.ACTIONS_ALLOW_UNSECURE_COMMANDS)
	policy_active("CKV_GHA_1", skip_scopes_for_job(job_name))
	msg := sprintf("CKV_GHA_1 [jobs.%s.env]: job %s must not set ACTIONS_ALLOW_UNSECURE_COMMANDS", [job_name, job_name])
}

deny contains msg if {
	entry := all_steps[_]
	is_object(entry.step.env)
	env_truthy(entry.step.env.ACTIONS_ALLOW_UNSECURE_COMMANDS)
	policy_active("CKV_GHA_1", skip_scopes_for_step(entry.job, entry.step))
	msg := sprintf("CKV_GHA_1 [%s.env]: step in job %s must not set ACTIONS_ALLOW_UNSECURE_COMMANDS", [step_yaml_path(entry), entry.job])
}

# CKV_GHA_2: shell injection in run
deny contains msg if {
	entry := all_steps[_]
	run := step_run(entry.step)
	run != ""
	some pattern in shell_injection_patterns
	regex.match(pattern, run)
	policy_active("CKV_GHA_2", skip_scopes_for_step(entry.job, entry.step))
	msg := sprintf("CKV_GHA_2 [%s.run]: job %s run block may be vulnerable to shell injection", [step_yaml_path(entry), entry.job])
}

# CKV_GHA_3: curl with secrets on same line
deny contains msg if {
	entry := all_steps[_]
	run := step_run(entry.step)
	run != ""
	some line in split(run, "\n")
	contains(line, "curl")
	contains(line, "secret")
	policy_active("CKV_GHA_3", skip_scopes_for_step(entry.job, entry.step))
	msg := sprintf("CKV_GHA_3 [%s.run]: job %s suspicious curl with secrets in run block", [step_yaml_path(entry), entry.job])
}

# CKV_GHA_4: netcat reverse shell pattern
deny contains msg if {
	entry := all_steps[_]
	run := step_run(entry.step)
	regex.match(`(nc|netcat) ([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})`, run)
	policy_active("CKV_GHA_4", skip_scopes_for_step(entry.job, entry.step))
	msg := sprintf("CKV_GHA_4 [%s.run]: job %s suspicious netcat with IP in run block", [step_yaml_path(entry), entry.job])
}

# CKV2_SPVS_2: set -euo pipefail
deny contains msg if {
	entry := all_steps[_]
	run := step_run(entry.step)
	run != ""
	not regex.match(`[\s\S]*set\s+-euo\s+pipefail`, run)
	policy_active("CKV2_SPVS_2", skip_scopes_for_step(entry.job, entry.step))
	msg := sprintf("CKV2_SPVS_2 [%s.run]: job %s run block must include set -euo pipefail", [step_yaml_path(entry), entry.job])
}

# CKV2_SPVS_3: no xtrace
deny contains msg if {
	entry := all_steps[_]
	run := step_run(entry.step)
	run != ""
	regex.match(`[\s\S]*(set\s+-x|set\s+-o\s+xtrace|\bxtrace\b)`, run)
	policy_active("CKV2_SPVS_3", skip_scopes_for_step(entry.job, entry.step))
	msg := sprintf("CKV2_SPVS_3 [%s.run]: job %s run block must not enable xtrace", [step_yaml_path(entry), entry.job])
}

# CKV2_SPVS_4: python unbuffered
deny contains msg if {
	entry := all_steps[_]
	run := step_run(entry.step)
	run != ""
	regex.match(`[\s\S]*\bpython3?\b`, run)
	not regex.match(`[\s\S]*\bpython3?\s+(-\S+\s+)*-u\b`, run)
	not python_unbuffered_env(entry.step)
	policy_active("CKV2_SPVS_4", skip_scopes_for_step(entry.job, entry.step))
	msg := sprintf("CKV2_SPVS_4 [%s.run]: job %s python invocation must use -u or PYTHONUNBUFFERED", [step_yaml_path(entry), entry.job])
}

# CKV2_SPVS_5: pin actions
deny contains msg if {
	entry := all_steps[_]
	uses := step_uses(entry.step)
	uses != ""
	not uses_allowed(uses)
	policy_active("CKV2_SPVS_5", skip_scopes_for_step(entry.job, entry.step))
	msg := sprintf("CKV2_SPVS_5 [%s.uses]: job %s uses %s must use SHA, ./, docker://, or internal /actions/ tag", [step_yaml_path(entry), entry.job, uses])
}

# CKV2_SPVS_5B: no parent path uses
deny contains msg if {
	entry := all_steps[_]
	uses := step_uses(entry.step)
	startswith(uses, "../")
	policy_active("CKV2_SPVS_5B", skip_scopes_for_step(entry.job, entry.step))
	msg := sprintf("CKV2_SPVS_5B [%s.uses]: job %s uses %s must not use ../ local action refs", [step_yaml_path(entry), entry.job, uses])
}

# CKV2_SPVS_6: inputs in run (GHA expressions or mistaken shell-style inputs.* refs)
inputs_in_run(run) if {
	regex.match(`[\s\S]*\$\{\{\s*(inputs\.|github\.event\.inputs\.)`, run)
}

inputs_in_run(run) if {
	regex.match(`[\s\S]*\$\{inputs\.`, run)
}

deny contains msg if {
	entry := all_steps[_]
	run := step_run(entry.step)
	inputs_in_run(run)
	policy_active("CKV2_SPVS_6", skip_scopes_for_step(entry.job, entry.step))
	msg := sprintf("CKV2_SPVS_6 [%s.run]: job %s must map inputs to env, not interpolate in run", [step_yaml_path(entry), entry.job])
}

# CKV2_SPVS_7: static cloud credentials in env
deny contains msg if {
	entry := all_steps[_]
	is_object(entry.step.env)
	some key in forbidden_env_keys
	entry.step.env[key]
	policy_active("CKV2_SPVS_7", skip_scopes_for_step(entry.job, entry.step))
	msg := sprintf("CKV2_SPVS_7 [%s.env]: job %s must not set static credential env %s", [step_yaml_path(entry), entry.job, key])
}

curl_pipe_shell(run) if {
	regex.match(`[\s\S]*(curl|wget)`, run)
	regex.match(`[\s\S]*\|\s*(ba)?sh\b`, run)
}

curl_pipe_shell(run) if {
	regex.match(`[\s\S]*(ba)?sh\s*<`, run)
	regex.match(`[\s\S]*(curl|wget)`, run)
}

# CKV2_SPVS_13: curl pipe bash
deny contains msg if {
	entry := all_steps[_]
	run := step_run(entry.step)
	curl_pipe_shell(run)
	policy_active("CKV2_SPVS_13", skip_scopes_for_step(entry.job, entry.step))
	msg := sprintf("CKV2_SPVS_13 [%s.run]: job %s must not pipe curl/wget into shell", [step_yaml_path(entry), entry.job])
}

# CKV2_SPVS_14: github/steps context in run
deny contains msg if {
	entry := all_steps[_]
	run := step_run(entry.step)
	regex.match(`[\s\S]*\$\{\{\s*(github\.|steps\.)`, run)
	policy_active("CKV2_SPVS_14", skip_scopes_for_step(entry.job, entry.step))
	msg := sprintf("CKV2_SPVS_14 [%s.run]: job %s must map github/steps context to env, not run", [step_yaml_path(entry), entry.job])
}
