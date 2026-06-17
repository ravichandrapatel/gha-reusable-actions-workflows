# FILE_NAME: steps.rego
# DESCRIPTION: Composite action step policies (CKV_GHA + CKV2_SPVS step rules).
# VERSION: 1.0.0
# AUTHORS: DevOps Team

package composite

import rego.v1

# CKV_GHA_1
deny contains msg if {
	input.runs.using == "composite"
	s := input.runs.steps[_]
	env := object.get(s, "env", null)
	is_object(env)
	env_truthy(env.ACTIONS_ALLOW_UNSECURE_COMMANDS)
	msg := "CKV_GHA_1: composite step must not set ACTIONS_ALLOW_UNSECURE_COMMANDS"
}

# CKV_GHA_2: shell injection in run
deny contains msg if {
	input.runs.using == "composite"
	s := input.runs.steps[_]
	run := step_run(s)
	run != ""
	some pattern in shell_injection_patterns
	regex.match(pattern, run)
	msg := "CKV_GHA_2: composite run block may be vulnerable to shell injection"
}

deny contains msg if {
	input.runs.using == "composite"
	s := input.runs.steps[_]
	run := step_run(s)
	run != ""
	some line in split(run, "\n")
	contains(line, "curl")
	contains(line, "secret")
	msg := "CKV_GHA_3: composite suspicious curl with secrets in run block"
}

deny contains msg if {
	input.runs.using == "composite"
	s := input.runs.steps[_]
	run := step_run(s)
	regex.match(`(nc|netcat) ([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})`, run)
	msg := "CKV_GHA_4: composite suspicious netcat with IP in run block"
}

# CKV2_SPVS_2
deny contains msg if {
	input.runs.using == "composite"
	s := input.runs.steps[_]
	run := step_run(s)
	run != ""
	not regex.match(`[\s\S]*set\s+-euo\s+pipefail`, run)
	msg := "CKV2_SPVS_2: composite run block must include set -euo pipefail"
}

# CKV2_SPVS_3
deny contains msg if {
	input.runs.using == "composite"
	s := input.runs.steps[_]
	run := step_run(s)
	run != ""
	regex.match(`[\s\S]*(set\s+-x|set\s+-o\s+xtrace|\bxtrace\b)`, run)
	msg := "CKV2_SPVS_3: composite run block must not enable xtrace"
}

# CKV2_SPVS_4
deny contains msg if {
	input.runs.using == "composite"
	s := input.runs.steps[_]
	run := step_run(s)
	run != ""
	regex.match(`[\s\S]*\bpython3?\b`, run)
	not regex.match(`[\s\S]*\bpython3?\s+(-\S+\s+)*-u\b`, run)
	not python_unbuffered_env(s)
	msg := "CKV2_SPVS_4: composite python invocation must use -u or PYTHONUNBUFFERED"
}

# CKV2_SPVS_5
deny contains msg if {
	input.runs.using == "composite"
	s := input.runs.steps[_]
	uses := step_uses(s)
	uses != ""
	not uses_allowed(uses)
	msg := sprintf("CKV2_SPVS_5: composite uses %s must use SHA, ./, docker://, or internal /actions/ tag", [uses])
}

# CKV2_SPVS_5B
deny contains msg if {
	input.runs.using == "composite"
	s := input.runs.steps[_]
	uses := step_uses(s)
	startswith(uses, "../")
	msg := sprintf("CKV2_SPVS_5B: composite uses %s must not use ../ local action refs", [uses])
}

# CKV2_SPVS_6
inputs_in_run(run) if {
	regex.match(`[\s\S]*\$\{\{\s*(inputs\.|github\.event\.inputs\.)`, run)
}

inputs_in_run(run) if {
	regex.match(`[\s\S]*\$\{inputs\.`, run)
}

deny contains msg if {
	input.runs.using == "composite"
	s := input.runs.steps[_]
	run := step_run(s)
	inputs_in_run(run)
	msg := "CKV2_SPVS_6: composite must map inputs to env, not interpolate in run"
}

# CKV2_SPVS_7
deny contains msg if {
	input.runs.using == "composite"
	s := input.runs.steps[_]
	env := object.get(s, "env", null)
	is_object(env)
	some key in forbidden_env_keys
	env[key]
	msg := sprintf("CKV2_SPVS_7: composite must not set static credential env %s", [key])
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
	input.runs.using == "composite"
	s := input.runs.steps[_]
	run := step_run(s)
	curl_pipe_shell(run)
	msg := "CKV2_SPVS_13: composite must not pipe curl/wget into shell"
}

# CKV2_SPVS_14
deny contains msg if {
	input.runs.using == "composite"
	s := input.runs.steps[_]
	run := step_run(s)
	regex.match(`[\s\S]*\$\{\{\s*(github\.|steps\.)`, run)
	msg := "CKV2_SPVS_14: composite must map github/steps context to env, not run"
}
