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
2. **Security** — Conftest, Actionlint, Bandit, Shellcheck (**all modes**; scans the target commit)
3. **Execute** — tag, sync workflow file, promote/rollback stable tag

Environments: `sandbox` (release only — versioned tag + optional main sync), `production` (release-promote / promote / rollback — mutates `{safe_name}/v1`).

## Concurrency

| Kind | Group | Effect |
| :--- | :--- | :--- |
| `workflows/...` | `release-manager-workflow` | One workflow deploy at a time (queue; no cancel). Protects `main` sync. |
| `actions/...` | `release-manager-action-{component_path}` | Different actions run in parallel; same path queues. |

## Mode behavior

| Mode | Security | Env | Result |
| :--- | :--- | :--- | :--- |
| `release` | Full (scan `main` at dispatch) | sandbox | Create `{safe_name}/v{X.Y.Z}`; sync workflow to `.github/workflows/{name}.yml` when applicable |
| `release-promote` | Full (scan `main` at dispatch) | production | Same as release, then point `{safe_name}/v1` at the new versioned tag |
| `promote` | Full (scan target versioned tag commit) | production | Point `{safe_name}/v1` at chosen versioned tag (delete+recreate, no force-push) |
| `rollback` | Full (scan **previous** versioned tag commit — deploy target) | production | Move `{safe_name}/v1` to previous versioned tag; restore prior workflow file if needed |

## Prompt Card

```text
Release Manager (workflow_dispatch): inputs component_path, mode, version(optional).
release = versioned tag + FULL security (env sandbox; scans dispatch SHA).
release-promote = security + versioned tag + move {safe_name}/v1 (env production).
promote = move {safe_name}/v1 after security scan of target tag commit (env production).
rollback = scan PREV versioned tag commit, then move /v1 there; restore synced workflow if needed.
Release tags refuse unrelated main commits (actions: HEAD==scan; workflows: sync file only).
Validate emits scan_commit; security checks it out; execute verifies before promote/rollback.
Concurrency: all workflows serialize (one at a time); actions parallel per component_path.
```

## Related

- Concept: [SemVer from commits](/vault/concepts/semver-from-commits.md), [Component tagging](/vault/concepts/component-tagging.md)
- Playbook: [Release component](/vault/playbooks/release-gha-component.md)
- System: [gha-reusable-actions-workflows](/vault/systems/gha-reusable-actions-workflows.md)
