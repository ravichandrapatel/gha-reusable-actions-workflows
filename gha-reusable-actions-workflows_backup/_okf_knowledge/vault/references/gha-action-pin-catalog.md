---
type: Reference
title: GHA action pin catalog
description: Observed SHA pins for common marketplace actions used in CI workflows (checkout, cache, artifacts).
tags: [artifacts, catalog, checkout, github-actions, pins, spvs]
timestamp: "2026-07-20T23:25:00Z"
status: active
pack_force_when: [checkout, upload-artifact, download-artifact, actions/cache, cache, workflow_call, ci-pipeline, sonarqube, docker]
---

# GHA action pin catalog

**Evidence grade:** `observed` (corpus + live GitHub API + bench workflows in this monorepo). Refresh via live GitHub/OCI when stale or missing; write-back updates here.

| Action | SHA (40-char) | Tag note |
| :--- | :--- | :--- |
| `actions/checkout` | `11bd71901bbe5b1630ceea73d27597364c9af683` | v4.2.2 |
| `actions/cache` | `5a3ec84eff668545956fd18022155c47e93e2684` | v4.2.3 |
| `actions/upload-artifact` | `ea165f8d65b6e75b540449e92b4886f43607fa02` | v4.6.2 |
| `actions/download-artifact` | `95815c38cf2ff2164869cbab79da8d1f422bc89e` | v4.2.1 |
| `sonarsource/sonarqube-scan-action` | `7451daf950bc136c497f29045f2b4d4f9f7ba43a` | master @ 2026-07-20 |
| `sonarsource/sonarqube-quality-gate-action` | `8e9b0ca0a7273d6f16986388d98393efdfcf56fd` | master @ 2026-07-20 |
| `docker/login-action` | `c66a8fcb2472d4283042d726b2a061b43b3f49ab` | master @ 2026-07-20 |
| `docker/build-push-action` | `cb941d0b895b09c17fa011d41c411b33c752cf28` | master @ 2026-07-20 |

SPVS: never `@vN` floating tags. Prefer house `./actions/...` when a composite exists.

## Prompt Card

```text
GHA pins (observed): checkout@11bd71901bbe5b1630ceea73d27597364c9af683
cache@5a3ec84eff668545956fd18022155c47e93e2684
upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02
download-artifact@95815c38cf2ff2164869cbab79da8d1f422bc89e
sonarqube-scan@7451daf950bc136c497f29045f2b4d4f9f7ba43a
sonarqube-quality-gate@8e9b0ca0a7273d6f16986388d98393efdfcf56fd
docker/login@c66a8fcb2472d4283042d726b2a061b43b3f49ab
docker/build-push@cb941d0b895b09c17fa011d41c411b33c752cf28
No @vN. Prefer ./actions/* house composites when present.
Missing pin → corpus → live Git → write-back.
```

## Related

- Standard: [GHA SPVS YAML](/standards/gha-spvs-yaml.md)
- Standard: [OKF Prompt Injection](/standards/okf-prompt-injection.md)
- Concept: [GHA CI pipeline recipe](/vault/concepts/gha-ci-pipeline-recipe.md)
- Concept: [GitHub Actions Domain](/vault/concepts/github-actions.md)

# Citations

1. Workspace observed pins: `_ab_bench/*/ci-pipeline/workflow.yml`, `workflows/common/tfvars-matrix-sync/workflow.yml`