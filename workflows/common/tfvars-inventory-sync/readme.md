# Tfvars Inventory Sync

Reusable workflow that discovers `*.tfvars` names in a caller-repo folder, writes `inventory.json`, pushes that file into `actions/common/check-inventory` on the destination repo using a GitHub App token, and dispatches Release Manager to release the inventory action.

## Overview & context

- **Purpose**: Keep the versioned `check-inventory` inventory in the destination catalog in sync with Terraform `*.tfvars` files that live in another repository.
- **Scope**: Non-recursive `*.tfvars` discovery; basename without `.tfvars` becomes a repo name; commit to destination `main`; auto-release when the JSON changes.
- **Primary users**: Platform / Terraform owners whose env files live in an app or infra repo.
- **Success criteria**: Destination `inventory.json` matches a sorted JSON array of repo names; Release Manager is dispatched only when the file changed.

## Metadata dashboard

| Attribute | Value |
| --- | --- |
| **Owner / Lead** | DevOps Team |
| **Service Status** | Draft (pre-release) |
| **Repository / Code** | `workflows/common/tfvars-inventory-sync` |
| **Dependencies** | `actions/checkout`, `actions/create-github-app-token`, GitHub CLI (`gh`), `jq` |
| **Slack / Support** | Platform / DevOps |

## What it does

1. Checks out the **caller** repository (the repo that invoked this workflow).
2. Finds `*.tfvars` in `working_directory`/`folder_name` (non-recursive).
3. Strips the `.tfvars` extension and writes sorted JSON: `["dev","prod",...]`.
4. Mints a GitHub App installation token scoped to `destination_repo` (credentials from inherited secrets `APP_ID` / `APP_PRIVATE_KEY`).
5. Checks out the destination, commits `actions/common/check-inventory/inventory.json` to `main` when the file changed.
6. Dispatches the destination’s **Release Manager** (`mode: release-promote`, `component_path: actions/common/check-inventory`).

If destination `inventory.json` already has the same repo list as the generated file, the job succeeds without a commit and **does not** dispatch Release Manager. Comparison is on the sorted unique array, so whitespace-only JSON differences do not count as a change.

## JSON shape

```json
[
  "reponame",
  "repo"
]
```

## Inputs (`workflow_call`)

| Input | Required | Default | Description |
| --- | --- | --- | --- |
| `folder_name` | Yes | — | Folder with `*.tfvars` relative to `working_directory`. |
| `working_directory` | No | `.` | Source root relative to the caller repo. |
| `destination_repo` | Yes | — | Destination `owner/repo` that owns `check-inventory`. |
| `commit_message` | No | `DCDT-0000 chore(check-inventory): sync inventory.json` | Ticket-prefixed conventional subject. |
| `release_version` | No | `""` | Optional explicit SemVer for Release Manager. |

Commits always target **`main`**.

## Secrets

This workflow does not declare `workflow_call` secrets. The caller must pass inherited secrets that include:

| Secret | Description |
| --- | --- |
| `APP_ID` | GitHub App client ID. |
| `APP_PRIVATE_KEY` | GitHub App private key. |

```yaml
secrets: inherit
```

### GitHub App permissions (destination)

Install the App on the destination repository with at least:

- **Contents**: Read and write (commit `inventory.json`)
- **Actions**: Read and write (dispatch Release Manager)

If `main` is protected, add the App to the bypass list (same requirement as Release Manager itself).

Release Manager still uses destination secrets `RELEASE_APP_ID` and `RELEASE_APP_PRIVATE_KEY` when it runs.

## Outputs

| Output | Description |
| --- | --- |
| `repos_count` | Number of discovered repos. |
| `inventory_changed` | `true` when a destination commit was pushed. |
| `commit_sha` | New destination commit SHA, or empty when unchanged. |
| `release_dispatched` | `true` when Release Manager was dispatched. |

## Usage examples

Caller workflow in a **different** repo. Reusable workflows must be referenced from `.github/workflows/` on the catalog (Release Manager copies the source there on `mode: release`).

```yaml
name: Sync tfvars inventory

on:
  push:
    paths:
      - 'terraform/envs/*.tfvars'
  workflow_dispatch:

jobs:
  sync:
    uses: my-org/gha-reusable-actions-workflows/.github/workflows/tfvars-inventory-sync.yml@tfvars-inventory-sync-v1
    with:
      folder_name: terraform/envs
      destination_repo: my-org/gha-reusable-actions-workflows
    secrets: inherit
```

## Release layout

| Location | Role |
| --- | --- |
| `workflows/common/tfvars-inventory-sync/workflow.yml` | **Source** (authoring) |
| `workflows/common/tfvars-inventory-sync/readme.md` | Usage documentation |
| `.github/workflows/tfvars-inventory-sync.yml` | **Synced copy** after Release Manager `mode: release` |

Tags (after this workflow is released): `tfvars-inventory-sync-1.0.0` (versioned), `tfvars-inventory-sync-v1` (stable).

Bootstrap:

1. Merge this component to the destination default branch.
2. Run Release Manager on `workflows/common/tfvars-inventory-sync` (`release-promote`) so callers can `uses:` the synced file.
3. Ensure `actions/common/check-inventory/action.yml` is already on `main` before the first caller sync.

## Requirements

- At least one `*.tfvars` file in the folder.
- Caller/org secrets `APP_ID` and `APP_PRIVATE_KEY` available via `secrets: inherit`.
- Destination `main` must exist; App must be able to push to it.
- Destination Release Manager must be callable (`release-manager.yml` on `main`).
