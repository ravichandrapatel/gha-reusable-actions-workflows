---
type: Reference
title: GHA action pin catalog
description: Observed SHA pins for common marketplace actions used in CI workflows (checkout, cache, artifacts).
tags: [artifacts, catalog, checkout, github-actions, pins, spvs]
timestamp: "2026-08-10T03:00:00Z"
status: active
pack_force_when: [checkout, upload-artifact, download-artifact, actions/cache, cache, workflow_call, ci-pipeline, sonarqube, docker, setup-python, setup-java, setup-node, setup-terraform, create-github-app-token]
---

# GHA action pin catalog

**Evidence grade:** `verified` (live GitHub Releases API peel to commit SHA, 2026-08-10). Refresh via live GitHub/OCI when stale or missing; write-back updates here.

| Action | SHA (40-char) | Tag note |
| :--- | :--- | :--- |
| `actions/checkout` | `3d3c42e5aac5ba805825da76410c181273ba90b1` | v7.0.1 |
| `actions/setup-python` | `5fda3b95a4ea91299a34e894583c3862153e4b97` | v7.0.0 |
| `actions/setup-java` | `b6effb05e454b25005698d916606bdc6ffcbf961` | v5.7.0 |
| `actions/setup-node` | `820762786026740c76f36085b0efc47a31fe5020` | v7.0.0 |
| `actions/cache` | `55cc8345863c7cc4c66a329aec7e433d2d1c52a9` | v6.1.0 |
| `actions/upload-artifact` | `043fb46d1a93c77aae656e7c1c64a875d1fc6a0a` | v7.0.1 |
| `actions/download-artifact` | `3e5f45b2cfb9172054b4087a40e8e0b5a5461e7c` | v8.0.1 |
| `actions/create-github-app-token` | `bcd2ba49218906704ab6c1aa796996da409d3eb1` | v3.2.0 |
| `hashicorp/setup-terraform` | `dfe3c3f87815947d99a8997f908cb6525fc44e9e` | v4.0.1 |
| `docker/login-action` | `dbcb813823bdd20940b903addbd779551569679f` | v4.6.0 |
| `docker/build-push-action` | `53b7df96c91f9c12dcc8a07bcb9ccacbed38856a` | v7.3.0 |
| `docker/setup-buildx-action` | `bb05f3f5519dd87d3ba754cc423b652a5edd6d2c` | v4.2.0 |
| `SonarSource/sonarqube-scan-action` | `22918119ff8e1ca75a623e15c8296b6ea4fbe28f` | v8.2.1 |
| `SonarSource/sonarqube-quality-gate-action` | `7a5fffe8e523c40e0c740b6bc2712ab503e52efa` | v1.2.1 |

SPVS: never `@vN` floating tags. Prefer house `./actions/...` when a composite exists.

## Prompt Card

```text
GHA pins (2026-08-10): checkout@3d3c42e5aac5ba805825da76410c181273ba90b1
setup-python@5fda3b95a4ea91299a34e894583c3862153e4b97
cache@55cc8345863c7cc4c66a329aec7e433d2d1c52a9
upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a
download-artifact@3e5f45b2cfb9172054b4087a40e8e0b5a5461e7c
create-github-app-token@bcd2ba49218906704ab6c1aa796996da409d3eb1
setup-terraform@dfe3c3f87815947d99a8997f908cb6525fc44e9e
docker/login@dbcb813823bdd20940b903addbd779551569679f
docker/build-push@53b7df96c91f9c12dcc8a07bcb9ccacbed38856a
No @vN. Prefer ./actions/* house composites when present.
Missing pin → corpus → live Git → write-back.
```

## Related

- Standard: [GHA SPVS YAML](/standards/gha-spvs-yaml.md)
- Standard: [OKF Prompt Injection](/standards/okf-prompt-injection.md)
- Concept: [GHA CI pipeline recipe](/vault/concepts/gha-ci-pipeline-recipe.md)
- Concept: [GitHub Actions Domain](/vault/concepts/github-actions.md)
- Concept: [Notification Email composite](/vault/concepts/notification-email.md)

# Citations

1. Live GitHub Releases API peeled to commit SHAs on 2026-08-10.
2. Applied across `.github/workflows/`, `actions/`, `workflows/`, `_ab_bench/`.
