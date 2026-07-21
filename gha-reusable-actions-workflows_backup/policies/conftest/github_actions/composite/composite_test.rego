# FILE_NAME: composite_test.rego
# DESCRIPTION: Conftest verify tests for composite action policies.
# VERSION: 1.0.0
# AUTHORS: DevOps Team

package composite_test

import rego.v1

import data.composite.deny

test_composite_fails_without_pipefail if {
	count(deny) > 0 with input as {
		"name": "Test",
		"runs": {
			"using": "composite",
			"steps": [{"run": "echo missing pipefail"}],
		},
	}
}

test_composite_passes_with_pipefail if {
	count(deny) == 0 with input as {
		"name": "Test",
		"runs": {
			"using": "composite",
			"steps": [{"run": "set -euo pipefail\necho ok"}],
		},
	}
}

test_composite_ckv2_spvs_5b if {
	count({msg | some msg in deny; contains(msg, "CKV2_SPVS_5B")}) > 0 with input as {
		"runs": {
			"using": "composite",
			"steps": [{"uses": "../other-action"}],
		},
	}
}

test_composite_env_skip_suppresses_ckv2_spvs_5b if {
	count({msg | some msg in deny; contains(msg, "CKV2_SPVS_5B")}) == 0 with input as {
		"env": {
			"SPVS_SKIP_POLICY": "CKV2_SPVS_5B",
			"SPVS_SKIP_REASON": "monorepo layout",
		},
		"runs": {
			"using": "composite",
			"steps": [{"uses": "../other-action"}],
		},
	}
}

test_composite_spvs_meta_1_missing_reason if {
	count({msg | some msg in deny; contains(msg, "SPVS_META_1")}) > 0 with input as {
		"runs": {
			"using": "composite",
			"steps": [{
				"run": "set -euo pipefail\necho ok",
				"env": {"SPVS_SKIP_POLICY": "CKV2_SPVS_2"},
			}],
		},
	}
}
