---
type: Module
title: GitHub Actions Module
description: Core domain module for composite actions, reusable workflows, Release Manager, and SPVS policy governance in gha-reusable-actions-workflows.
tags: [kernel, module, github-actions, spvs]
timestamp: 2026-07-14T17:40:00Z
status: active
---

# Module: GitHub Actions

**Triggers:** "github action", "reusable workflow", "release manager", "SPVS", "action.yml", "workflow_call", "promote tag", "conftest gha", "yaml anchor", "workflow alias"

## 1. Minimum Evidence

1. Component path under `actions/` or `workflows/`, OR a workflow/action YAML dump in `_inbox/`.
2. Intent (author, review, release, promote, rollback, or policy check).

*If Minimum Evidence is NOT met, halt BLOCKED.*

## 2. Analysis Pipeline

1. **Prompt Pack:** Extract slim cards via `okf.py card` / [OKF Prompt Injection](/standards/okf-prompt-injection.md) — do not paste full SPVS/layout docs into generation context.
2. **Layout:** Validate path against [GHA component layout](/standards/gha-component-layout.md).
3. **Policy:** Evaluate YAML against [GHA SPVS YAML](/standards/gha-spvs-yaml.md) (Conftest namespaces `workflow` / `composite`).
4. **Commits / SemVer:** Apply [GHA commit subjects](/standards/gha-commit-subjects.md) and [SemVer from commits](/vault/concepts/semver-from-commits.md).
5. **Release plane:** Route lifecycle work via [Release Manager modes](/vault/concepts/release-manager-modes.md) and playbooks.
6. **Ownership:** Workload/component artifacts live under `actions/` or `workflows/`; do not invent alternate trees.

## 3. Artifact ownership

| Owns | Does not own |
| :--- | :--- |
| Action/workflow authoring contracts, SPVS review findings, release/promote/rollback plans | Cloud vendor IAM encyclopedias (link Vendor/System instead) |

## Prompt Card

```text
GHA module MUST: components live under actions/{cat}/{name}/ or workflows/{cat}/{name}/.
Validate YAML vs SPVS (conftest -n workflow|composite); layout vs gha-component-layout.
Commits: ticket-prefixed conventional (drive SemVer). Release via Release Manager modes.
Inject slim cards only — never full SPVS/layout docs.
```

## 4. Related

- System: [gha-reusable-actions-workflows](/vault/systems/gha-reusable-actions-workflows.md)
- Vendor: [OWASP](/kernel/vendors/owasp.md)
- Standards: [OKF Prompt Injection](/standards/okf-prompt-injection.md)
- Concepts: [GHA YAML Anchors](/vault/concepts/gha-yaml-anchors.md), [Minimal OKF Prompt Cards](/vault/concepts/minimal-okf-prompt-cards.md)
- Playbooks: [Author composite action](/vault/playbooks/author-gha-composite-action.md), [Release component](/vault/playbooks/release-gha-component.md)
