---
type: Concept
title: Release Manager Modes
description: release, release-promote, promote, and rollback semantics for the gha-reusable-actions-workflows Release Manager.
tags: [github-actions, release-manager, concepts]
timestamp: 2026-08-17T02:18:00Z
status: active
---

# Release Manager Modes

Orchestrator: `.github/workflows/release-manager.yml` (`workflow_dispatch`).

## Inputs

| Input | Required | Notes |
| :--- | :--- | :--- |
| `component_path` | Yes | e.g. `actions/common/janitor-bot` |
| `mode` | Yes | `release` \| `release-promote` \| `promote` \| `rollback` |
| `version` | No | Release / release-promote: auto-derived if empty. Promote/rollback: defaults to latest versioned tag if empty. |

## Stages

1. **Validate** — path/type, SemVer derivation (release / release-promote), tag checks
2. **Security** — Conftest, Actionlint, Bandit, Shellcheck (**release and release-promote**)
3. **Execute** — tag, sync workflow file, promote/rollback stable tag

Environments: `sandbox` (release), `production` (release-promote / promote / rollback).

## Concurrency

| Kind | Group | Effect |
| :--- | :--- | :--- |
| `workflows/...` | `release-manager-workflow` | One workflow deploy at a time (queue; no cancel). Protects `main` sync. |
| `actions/...` | `release-manager-action-{component_path}` | Different actions run in parallel; same path queues. |

## Mode behavior

| Mode | Security | Env | Result |
| :--- | :--- | :--- | :--- |
| `release` | Full | sandbox | Create `{safe_name}/v{X.Y.Z}`; sync workflow to `.github/workflows/{name}.yml` when applicable |
| `release-promote` | Full | production | Same as release, then point `{safe_name}/v1` at the new versioned tag |
| `promote` | Skipped | production | Point `{safe_name}/v1` at chosen versioned tag (delete+recreate, no force-push) |
| `rollback` | Skipped | production | Move `{safe_name}/v1` to previous versioned tag; restore prior workflow file if needed |

## Prompt Card

```text
Release Manager (workflow_dispatch): inputs component_path, mode, version(optional).
release = versioned tag + FULL security (env sandbox).
release-promote = security + versioned tag + move {safe_name}/v1 (env production).
promote = move {safe_name}/v1 (security skipped, env production).
rollback = /v1 to previous versioned tag; restore synced workflow file if needed.
Concurrency: all workflows serialize (one at a time); actions parallel per component_path.
```

## Related

- Concept: [SemVer from commits](/vault/concepts/semver-from-commits.md), [Component tagging](/vault/concepts/component-tagging.md)
- Playbook: [Release component](/vault/playbooks/release-gha-component.md)
- System: [gha-reusable-actions-workflows](/vault/systems/gha-reusable-actions-workflows.md)
