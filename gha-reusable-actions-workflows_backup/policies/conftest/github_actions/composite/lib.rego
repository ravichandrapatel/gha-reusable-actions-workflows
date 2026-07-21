# FILE_NAME: lib.rego
# DESCRIPTION: Composite-action-only helpers (steps, skip scopes, YAML paths).
# VERSION: 2.0.0
# AUTHORS: DevOps Team

package composite

import rego.v1

all_steps contains entry if {
	input.runs.using == "composite"
	some idx
	step := input.runs.steps[idx]
	entry := {"step_index": idx, "step": step}
}

step_yaml_path(entry) := path if {
	path := sprintf("runs.steps[%d]", [entry.step_index])
}

skip_scopes_for_composite_step(step) := scopes if {
	scopes := [input, step]
}

skip_scopes_composite := scopes if {
	scopes := [input]
}
