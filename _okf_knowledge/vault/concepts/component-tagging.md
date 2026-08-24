---
type: Concept
title: Component Tagging
description: safe_name derivation and versioned vs stable tag conventions for GHA components.
tags: [github-actions, tagging, release, concepts]
timestamp: 2026-08-17T15:42:00Z
status: active
---

# Component Tagging

| Item | Rule |
| :--- | :--- |
| `safe_name` | Basename of `component_path` (Release Manager rejects duplicate basenames across categories) |
| Versioned tag | `{safe_name}/v{X.Y.Z}` e.g. `janitor-bot/v1.2.3` |
| Stable tag | `{safe_name}/v1` e.g. `janitor-bot/v1` |
| Promote | Delete remote `/v1` then recreate at **peeled commit** of `{safe_name}/v{X.Y.Z}` (`git rev-parse tag^{commit}`). Do not point `/v1` at the versioned tag object — nested annotated tags break nektos/act (`unsupported object type`). No force-push. |
| Rollback previous | Sorted versioned tags (`{safe_name}/v*.*.*`); previous index of target `{safe_name}/v{version}` |
| Workflow sync | On release, copy `workflows/.../workflow.yml` to `.github/workflows/{name}.yml` then tag |

Consumers typically reference `@{safe_name}/v1` (stable) or a versioned tag / commit SHA.

## Prompt Card

```text
Tags: versioned {safe_name}/v{X.Y.Z}; stable {safe_name}/v1.
safe_name = basename(component_path); duplicate basenames rejected.
Promote = delete+recreate /v1 at peeled commit of versioned tag (not nested tag).
Workflow release also syncs .github/workflows/{name}.yml before tagging.
```

## Related

- Concept: [Release Manager modes](/vault/concepts/release-manager-modes.md), [SemVer from commits](/vault/concepts/semver-from-commits.md)
- System: [gha-reusable-actions-workflows](/vault/systems/gha-reusable-actions-workflows.md)
