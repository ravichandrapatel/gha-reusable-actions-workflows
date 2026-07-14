---
type: Vendor
title: OWASP Vendor Extension
description: OWASP SPVS alignment and Dependency-Check action constraints for the GitHub Actions module.
tags: [kernel, vendor, owasp, spvs, security]
timestamp: 2026-07-14T17:40:00Z
status: active
---

# Vendor: OWASP

**Triggers:** "OWASP", "SPVS", "dependency-check", "CKV2_SPVS"

## 1. Scope

Extends [GitHub Actions Module](/kernel/modules/github-actions.md) with OWASP Secure Pipeline Verification Standard expectations and the Podman-based Dependency-Check action.

Does **not** own generic composite-action layout (that is the Module / System).

## 2. Minimum Evidence

1. Target workflow/action YAML, OR Dependency-Check scan request with `project` / `path` / `format`.
2. Lifecycle stage (Integrate vs Release vs Operate).

## 3. Analysis Pipeline

1. Map controls to [SPVS lifecycle](/vault/concepts/spvs-lifecycle.md).
2. Enforce YAML rules via [GHA SPVS YAML](/standards/gha-spvs-yaml.md).
3. For Dependency-Check: require Podman/ARC-compatible runners; no Docker-only assumptions.

## Prompt Card

```text
OWASP vendor MUST: map controls to SPVS lifecycle stage (Plan/Integrate/Release/Operate).
Enforce gha-spvs-yaml rules via Conftest. Dependency-Check: Podman/ARC runners only —
no Docker-only assumptions. Branch protection/CODEOWNERS are GitHub settings, not YAML.
```

## 4. Related

- System: [gha-reusable-actions-workflows](/vault/systems/gha-reusable-actions-workflows.md)
- Module: [GitHub Actions](/kernel/modules/github-actions.md)
- Standard: [GHA SPVS YAML](/standards/gha-spvs-yaml.md)
