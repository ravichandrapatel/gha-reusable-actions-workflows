# FILE_NAME: steps.rego
# DESCRIPTION: Composite action step policies (CKV_GHA + CKV2_SPVS step rules).
# VERSION: 1.2.0
# AUTHORS: DevOps Team

package composite

import rego.v1

# CKV_GHA_1
deny contains msg if {
	entry := all_steps[_]
	is_object(entry.step.env)
	env_truthy(entry.step.env.ACTIONS_ALLOW_UNSECURE_COMMANDS)
	policy_active("CKV_GHA_1", skip_scopes_for_composite_step(entry.step))
	msg := sprintf("CKV_GHA_1 [%s.env]: composite step must not set ACTIONS_ALLOW_UNSECURE_COMMANDS", [step_yaml_path(entry)])
}

# CKV_GHA_2: shell injection in run
deny contains msg if {
	entry := all_steps[_]
	run := step_run(entry.step)
	run != ""
	some pattern in shell_injection_patterns
	regex.match(pattern, run)
	policy_active("CKV_GHA_2", skip_scopes_for_composite_step(entry.step))
	msg := sprintf("CKV_GHA_2 [%s.run]: composite run block may be vulnerable to shell injection", [step_yaml_path(entry)])
}

deny contains msg if {
	entry := all_steps[_]
	run := step_run(entry.step)
	run != ""
	some line in split(run, "\n")
	contains(line, "curl")
	contains(line, "secret")
	policy_active("CKV_GHA_3", skip_scopes_for_composite_step(entry.step))
	msg := sprintf("CKV_GHA_3 [%s.run]: composite suspicious curl with secrets in run block", [step_yaml_path(entry)])
}

deny contains msg if {
	entry := all_steps[_]
	run := step_run(entry.step)
	regex.match(`(nc|netcat) ([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})`, run)
	policy_active("CKV_GHA_4", skip_scopes_for_composite_step(entry.step))
	msg := sprintf("CKV_GHA_4 [%s.run]: composite suspicious netcat with IP in run block", [step_yaml_path(entry)])
}

# CKV2_SPVS_2
deny contains msg if {
	entry := all_steps[_]
	run := step_run(entry.step)
	run != ""
	not regex.match(`[\s\S]*set\s+-euo\s+pipefail`, run)
	policy_active("CKV2_SPVS_2", skip_scopes_for_composite_step(entry.step))
	msg := sprintf("CKV2_SPVS_2 [%s.run]: composite run block must include set -euo pipefail", [step_yaml_path(entry)])
}

# CKV2_SPVS_3
deny contains msg if {
	entry := all_steps[_]
	run := step_run(entry.step)
	run != ""
	regex.match(`[\s\S]*(set\s+-x|set\s+-o\s+xtrace|\bxtrace\b)`, run)
	policy_active("CKV2_SPVS_3", skip_scopes_for_composite_step(entry.step))
	msg := sprintf("CKV2_SPVS_3 [%s.run]: composite run block must not enable xtrace", [step_yaml_path(entry)])
}

# CKV2_SPVS_4
deny contains msg if {
	entry := all_steps[_]
	run := step_run(entry.step)
	run != ""
	regex.match(`[\s\S]*\bpython3?\b`, run)
	not regex.match(`[\s\S]*\bpython3?\s+(-\S+\s+)*-u\b`, run)
	not python_unbuffered_env(entry.step)
	policy_active("CKV2_SPVS_4", skip_scopes_for_composite_step(entry.step))
	msg := sprintf("CKV2_SPVS_4 [%s.run]: composite python invocation must use -u or PYTHONUNBUFFERED", [step_yaml_path(entry)])
}

# CKV2_SPVS_5
deny contains msg if {
	entry := all_steps[_]
	uses := step_uses(entry.step)
	uses != ""
	not uses_allowed(uses)
	policy_active("CKV2_SPVS_5", skip_scopes_for_composite_step(entry.step))
	msg := sprintf("CKV2_SPVS_5 [%s.uses]: composite uses %s must use SHA, ./, docker://, or internal /actions/ tag", [step_yaml_path(entry), uses])
}

# CKV2_SPVS_5B
deny contains msg if {
	entry := all_steps[_]
	uses := step_uses(entry.step)
	startswith(uses, "../")
	policy_active("CKV2_SPVS_5B", skip_scopes_for_composite_step(entry.step))
	msg := sprintf("CKV2_SPVS_5B [%s.uses]: composite uses %s must not use ../ local action refs", [step_yaml_path(entry), uses])
}

# CKV2_SPVS_6
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
	policy_active("CKV2_SPVS_6", skip_scopes_for_composite_step(entry.step))
	msg := sprintf("CKV2_SPVS_6 [%s.run]: composite must map inputs to env, not interpolate in run", [step_yaml_path(entry)])
}

# CKV2_SPVS_7
deny contains msg if {
	entry := all_steps[_]
	is_object(entry.step.env)
	some key in forbidden_env_keys
	entry.step.env[key]
	policy_active("CKV2_SPVS_7", skip_scopes_for_composite_step(entry.step))
	msg := sprintf("CKV2_SPVS_7 [%s.env]: composite must not set static credential env %s", [step_yaml_path(entry), key])
}

curl_pipe_shell(run) if {
	regex.match(`[\s\S]*(curl|wget)`, run)
	regex.match(`[\s\S]*\|\s*(ba)?sh\b`, run)
}

curl_pipe_shell(run) if {
	regex.match(`[\s\S]*(ba)?sh\s*<`, run)
	regex.match(`[\s\S]*(curl|wget)`, run)
}

# CKV2_SPVS_13
deny contains msg if {
	entry := all_steps[_]
	run := step_run(entry.step)
	curl_pipe_shell(run)
	policy_active("CKV2_SPVS_13", skip_scopes_for_composite_step(entry.step))
	msg := sprintf("CKV2_SPVS_13 [%s.run]: composite must not pipe curl/wget into shell", [step_yaml_path(entry)])
}

# CKV2_SPVS_14
deny contains msg if {
	entry := all_steps[_]
	run := step_run(entry.step)
	regex.match(`[\s\S]*\$\{\{\s*(github\.|steps\.)`, run)
	policy_active("CKV2_SPVS_14", skip_scopes_for_composite_step(entry.step))
	msg := sprintf("CKV2_SPVS_14 [%s.run]: composite must map github/steps context to env, not run", [step_yaml_path(entry)])
}
