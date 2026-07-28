# FILE_NAME: skip_meta.rego
# DESCRIPTION: Meta-policies for SPVS_SKIP_POLICY / SPVS_SKIP_REASON env contract (composite).
# VERSION: 1.1.0
# AUTHORS: DevOps Team

package composite

import rego.v1

import data.lib

# SPVS_META_1: SPVS_SKIP_REASON required whenever SPVS_SKIP_POLICY is set.
deny contains msg if {
	is_object(input.env)
	lib.skip_reason_missing(input.env)
	msg := "SPVS_META_1: composite action env must define SPVS_SKIP_REASON when SPVS_SKIP_POLICY is set"
}

deny contains msg if {
	input.runs.using == "composite"
	step := input.runs.steps[_]
	is_object(step.env)
	lib.skip_reason_missing(step.env)
	msg := "SPVS_META_1: composite step must define SPVS_SKIP_REASON when SPVS_SKIP_POLICY is set"
}
