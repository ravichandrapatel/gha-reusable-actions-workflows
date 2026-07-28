---
type: System
title: gha-reusable-actions-workflows
description: Monorepo for reusable GitHub Actions, reusable workflows, SPVS Conftest policies, and Release Manager lifecycle.
tags: [github-actions, spvs, release-manager, monorepo, system]
timestamp: 2026-07-28T00:30:00Z
status: active
---

# gha-reusable-actions-workflows

Monorepo that publishes composite GitHub Actions and reusable workflows under an OWASP SPVS-aligned release plane (Validate → Security → Execute).

## Directory map

| Path | Role |
| --- | --- |
| `actions/{category}/{name}/` | Composite actions (`action.yml` + `readme.md`) |
| `workflows/{category}/{name}/` | Reusable workflows (`workflow.yml` + `readme.md`) |
| `policies/conftest/github_actions/` | Conftest Rego |
| `policies/scripts/` | Commit-msg lib, hooks, Conftest runners |
| `.github/workflows/` | Release Manager, OKF lint, synced published workflows |
| `AGENTS.md` + `_okf_knowledge/` | Portable Aegis OKF package (this brain) |

## Components (observed 2026-07-28)

| Kind | Path |
| --- | --- |
| Action | `actions/common/semver` |
| Action | `actions/common/drift-auditor` |
| Action | `actions/common/git-path-filter` |
| Action | `actions/common/prbot` |
| Action | `actions/common/build-preprocess` |
| Action | `actions/security/owasp-dependency-check` |
| Workflow | `workflows/common/dummy-workflow` |
| Workflow | `workflows/common/tfvars-matrix-sync` |
| Workflow | `workflows/archtype/ng-ui-build-pipeline` |
| Orchestrator | `.github/workflows/release-manager.yml` |
| E2E | `.github/workflows/git-path-filter-e2e.yml` |

## Release plane

Modes: `release` (sandbox versioned tag), `promote` (stable `{name}-v1`), `rollback` (previous versioned tag).

Tag patterns: `{safe_name}-{X.Y.Z}` and `{safe_name}-v1`.

## Prerequisites

- GitHub App secrets: `RELEASE_APP_ID`, `RELEASE_APP_PRIVATE_KEY` (`contents: write`, `workflows: write`)

## Prompt Card

```text
Monorepo: actions/{cat}/{name}/ (action.yml+readme); workflows/{cat}/{name}/.
Actions: semver, drift-auditor, git-path-filter, prbot, build-preprocess, owasp-dependency-check.
Workflows: dummy-workflow, tfvars-matrix-sync, ng-ui-build-pipeline (archtype).
Release: release-manager.yml. OKF: AGENTS.md + _okf_knowledge/ at package root.
```

## Related

- [GitHub Actions](/vault/concepts/github-actions.md)
- [Release Manager modes](/vault/concepts/release-manager-modes.md)
- [GHA component layout](/standards/gha-component-layout.md)
- [GHA SPVS YAML](/standards/gha-spvs-yaml.md)
- [Release component](/vault/playbooks/release-gha-component.md)
