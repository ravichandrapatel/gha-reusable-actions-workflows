# FILE_NAME: skip_meta.rego
# DESCRIPTION: Meta-policies for SPVS_SKIP_POLICY / SPVS_SKIP_REASON env contract (composite).
# VERSION: 1.0.0
# AUTHORS: DevOps Team

package composite

import rego.v1

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

# SPVS_META_1: SPVS_SKIP_REASON required whenever SPVS_SKIP_POLICY is set.
deny contains msg if {
	is_object(input.env)
	skip_reason_missing(input.env)
	msg := "SPVS_META_1: composite action env must define SPVS_SKIP_REASON when SPVS_SKIP_POLICY is set"
}

deny contains msg if {
	input.runs.using == "composite"
	step := input.runs.steps[_]
	is_object(step.env)
	skip_reason_missing(step.env)
	msg := "SPVS_META_1: composite step must define SPVS_SKIP_REASON when SPVS_SKIP_POLICY is set"
}
