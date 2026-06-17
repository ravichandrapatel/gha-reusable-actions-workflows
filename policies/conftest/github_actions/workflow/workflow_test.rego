# FILE_NAME: workflow_test.rego
# DESCRIPTION: Conftest verify tests for workflow policies.
# VERSION: 1.0.0
# AUTHORS: DevOps Team

package workflow_test

import rego.v1

import data.workflow.deny

test_ckv2_spvs_1_fails_without_job_permissions if {
	count(deny) > 0 with input as {
		"permissions": {"contents": "read"},
		"on": {"workflow_call": {}},
		"jobs": {
			"build": {
				"runs-on": "ubuntu-latest",
				"steps": [{"run": "set -euo pipefail\necho ok"}],
			},
		},
	}
}

test_ckv2_spvs_2_fails_without_pipefail if {
	count(deny) > 0 with input as {
		"permissions": {"contents": "read"},
		"jobs": {
			"build": {
				"runs-on": "ubuntu-latest",
				"permissions": {"contents": "read"},
				"steps": [{"run": "echo no pipefail"}],
			},
		},
	}
}

test_valid_minimal_workflow if {
	count(deny) == 0 with input as {
		"permissions": {"contents": "read"},
		"on": {"workflow_call": {}},
		"jobs": {
			"build": {
				"runs-on": "ubuntu-latest",
				"permissions": {"contents": "read"},
				"steps": [{"run": "set -euo pipefail\necho ok"}],
			},
		},
	}
}

test_ckv2_gha_1_write_all if {
	count({msg | some msg in deny; contains(msg, "CKV2_GHA_1")}) > 0 with input as {
		"permissions": "write-all",
		"jobs": {},
	}
}

test_ckv2_spvs_10_write_all_scope if {
	count({msg | some msg in deny; contains(msg, "CKV2_SPVS_10")}) > 0 with input as {
		"permissions": {"contents": "write-all"},
		"jobs": {},
	}
}

test_ckv2_spvs_10_any_scope_write_all if {
	count({msg | some msg in deny; contains(msg, "permissions.id-token must not be write-all")}) > 0 with input as {
		"permissions": {"contents": "read", "id-token": "write-all"},
		"jobs": {},
	}
}

test_ckv2_spvs_10_job_write_all if {
	count({msg | some msg in deny; contains(msg, "CKV2_SPVS_10")}) > 0 with input as {
		"permissions": {"contents": "read"},
		"jobs": {
			"build": {
				"runs-on": "ubuntu-latest",
				"permissions": "write-all",
				"steps": [{"run": "set -euo pipefail\necho ok"}],
			},
		},
	}
}

test_ckv2_spvs_10_job_scope_write_all if {
	count({msg | some msg in deny; contains(msg, "job deploy permissions.packages must not be write-all")}) > 0 with input as {
		"permissions": {"contents": "read"},
		"jobs": {
			"deploy": {
				"runs-on": "ubuntu-latest",
				"permissions": {"contents": "read", "packages": "write-all"},
				"steps": [{"run": "set -euo pipefail\necho ok"}],
			},
		},
	}
}

test_ckv2_spvs_9_missing_workflow_permissions if {
	count({msg | some msg in deny; contains(msg, "CKV2_SPVS_9")}) > 0 with input as {
		"on": {"workflow_call": {}},
		"jobs": {
			"build": {
				"runs-on": "ubuntu-latest",
				"permissions": {"contents": "read"},
				"steps": [{"run": "set -euo pipefail\necho ok"}],
			},
		},
	}
}

test_ckv2_spvs_6_inputs_in_run if {
	count({msg | some msg in deny; contains(msg, "CKV2_SPVS_6")}) > 0 with input as {
		"permissions": {"contents": "read"},
		"jobs": {
			"build": {
				"runs-on": "ubuntu-latest",
				"permissions": {"contents": "read"},
				"steps": [{"run": "set -euo pipefail\necho ${inputs.message}"}],
			},
		},
	}
}

test_ckv2_spvs_15_pull_request_target if {
	count({msg | some msg in deny; contains(msg, "CKV2_SPVS_15")}) > 0 with input as {
		"permissions": {"contents": "read"},
		"on": {"pull_request_target": {"types": ["opened"]}},
		"jobs": {},
	}
}
