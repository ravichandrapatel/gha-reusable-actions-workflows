---
type: Concept
title: Minimal OKF Prompt Cards
description: Inject a short SPVS checklist + pin cache into agent prompts — not the full standard — for one-shot Conftest-pass.
tags: [github-actions, okf, prompting, tokens, spvs]
timestamp: 2026-07-13T16:45:00Z
status: active
---

# Minimal OKF Prompt Cards

Bench finding (Nexus Docker composite, Composer Fast): **fat OKF cards waste tokens**; **no-OKF + Conftest fix loops are slower** than a minimal one-shot when the first shot already exceeds min-OKF wall time.

## MUST (agent prompting)

1. For authoring tasks, inject a **minimal card** (target ≤150 tokens): SPVS MUST bullets + SHA pin lines only.
2. Keep encyclopedic rules in the vault ([GHA SPVS YAML](/standards/gha-spvs-yaml.md)); **do not** paste the full standard into every prompt.
3. Prefer **one-shot Conftest-pass** over generate → fail → remediate.

## SHOULD

1. Maintain a **pin cache** (tag → 40-char SHA) for common actions; attach it when remediating CKV2_SPVS_5 so agents do not discover SHAs via API.
2. Tell the agent: short `readme.md` (inputs/outputs + one example) — no metadata dashboards.

## FORBIDDEN (prompting anti-patterns)

1. Pasting the entire SPVS catalog + long design essays into authoring prompts by default.
2. Relying on “no OKF is faster” without measuring **time to Conftest-pass** (include remediation turns).

## Bench snapshot (Nexus composite)

| Path | Wall to PASS | Notes |
| :--- | ---: | :--- |
| Fat OKF one-shot | ~59s | PASS; high tokens |
| Minimal OKF one-shot | ~17s | PASS; best |
| no-OKF + Conftest + gh SHA discover | ~76s | PASS; slow |
| no-OKF + Conftest + pin cache | ~61s | PASS; still slower than min OKF |

## Example minimal card

```text
SPVS composite MUST:
- runs.using: composite; action.yml + readme.md
- bash run: set -euo pipefail; no set -x
- no ${{ inputs.* }} in run — map via env
- uses: 40-char SHA only; no ../
- no curl|bash; no AWS_* static keys

Pins:
docker/login-action@74a5d142397b4f367a81961eba4e8cd7edddf772
docker/setup-buildx-action@b5ca514318bd6ebac0fb2aedd5d36ec1b5c232a2
```

## Prompt Card

```text
Prompting MUST: inject ## Prompt Card only (≤150 tok); no full-brain dump.
Prefer one-shot Conftest-pass. On CKV2_SPVS_5 use pin cache, not gh rediscovery.
Short readme: inputs/outputs + one example.
```

## Related

- Standard: [OKF Prompt Injection](/standards/okf-prompt-injection.md)
- Playbook: [Author GHA Composite Action](/vault/playbooks/author-gha-composite-action.md)
- Standard: [GHA SPVS YAML](/standards/gha-spvs-yaml.md)
- Playbook: [Run GHA Local Policy Tests](/vault/playbooks/run-gha-local-policy-tests.md)
- Concept: [Simplicity First](/standards/simplicity-first.md)
