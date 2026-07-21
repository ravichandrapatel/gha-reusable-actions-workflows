---
type: Concept
title: GHA CI pipeline recipe
description: Binding recipe for multi-job reusable CI — checkout, real artifact sharing, house OWASP action; no stub staging as design.
tags: [github-actions, ci-pipeline, artifacts, owasp, workflow_call]
timestamp: 2026-07-21T04:30:00Z
status: active
pack_force_when: [ci-pipeline, workflow_call, owasp, sonarqube, artifact, artifacts, upload-artifact]
---

# GHA CI pipeline recipe

For multi-job `workflow_call` CI (build → OWASP → Sonar → gate → publish):

## MUST

1. **Checkout** each job that needs the repo (`actions/checkout@<SHA>` from pin catalog, or `./` wrapper).
2. **Cross-job artifacts** via `actions/upload-artifact` + `actions/download-artifact` (SHA-pinned). Local `mkdir` staging alone does **not** share across jobs.
3. **OWASP:** `uses: ./actions/security/owasp-dependency-check` (Podman/ARC; see SPVS lifecycle).
4. If pins/recipe missing after pack → **corpus** (`actions/`, `workflows/`) → **live** upstream → **write-back** to OKF. Do not invent floating `@vN`.

## FORBIDDEN

1. Approving “run-oriented staging / promote later” as the design when the task requires real artifact sharing.
2. Stubbing OWASP/Sonar with echo reports when house actions or pin cards exist (or can be resolved via ladder).
3. Mining grader/Rego to invent compliance while authoring.

## Prompt Card

```text
CI multi-job MUST: checkout; upload-artifact+download-artifact for cross-job;
OWASP via ./actions/security/owasp-dependency-check.
FORBIDDEN: stub local staging as design; @vN tags.
Missing pins → corpus → live → write-back (never Conftest-green stubs).
```

## Related

- Reference: [GHA action pin catalog](/vault/references/gha-action-pin-catalog.md)
- Standards: [GHA SPVS YAML](/standards/gha-spvs-yaml.md), [OKF Prompt Injection](/standards/okf-prompt-injection.md)
- Concepts: [SPVS Lifecycle](/vault/concepts/spvs-lifecycle.md), [GitHub Actions Domain](/vault/concepts/github-actions.md)
