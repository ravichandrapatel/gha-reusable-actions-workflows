# FILE_NAME: skip_meta.rego
# DESCRIPTION: Meta-policies for SPVS_SKIP_POLICY / SPVS_SKIP_REASON env contract.
# VERSION: 1.1.0
# AUTHORS: DevOps Team

package workflow

import rego.v1

import data.lib

# SPVS_META_1: SPVS_SKIP_REASON required whenever SPVS_SKIP_POLICY is set.
deny contains msg if {
	is_object(input.env)
	lib.skip_reason_missing(input.env)
	msg := "SPVS_META_1: workflow env must define SPVS_SKIP_REASON when SPVS_SKIP_POLICY is set"
}

deny contains msg if {
	some job_name
	job := input.jobs[job_name]
	is_object(job.env)
	lib.skip_reason_missing(job.env)
	msg := sprintf("SPVS_META_1: job %s env must define SPVS_SKIP_REASON when SPVS_SKIP_POLICY is set", [job_name])
}

deny contains msg if {
	entry := all_steps[_]
	is_object(entry.step.env)
	lib.skip_reason_missing(entry.step.env)
	msg := sprintf("SPVS_META_1: step in job %s must define SPVS_SKIP_REASON when SPVS_SKIP_POLICY is set", [entry.job])
}
