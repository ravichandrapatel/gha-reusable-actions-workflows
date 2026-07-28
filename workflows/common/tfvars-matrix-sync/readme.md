# Tfvars Matrix Sync

Reusable workflow that discovers `*.tfvars` workspace names, writes a JSON matrix, and opens a pull request on a destination repository using a GitHub App.

## Overview & context

- **Purpose**: Keep a downstream repo’s workspace matrix in sync with Terraform `*.tfvars` files in the caller repo.
- **Scope**: Non-recursive `*.tfvars` discovery; basename without `.tfvars` becomes a workspace name; PR-only delivery to another repository.
- **Primary users**: Platform / Terraform owners who maintain env matrices in a separate config repo.
- **Success criteria**: Destination PR contains a stable `{"workspaces":[...]}` JSON when names change; no PR when unchanged.

## Metadata dashboard

| Attribute | Value |
| --- | --- |
| **Owner / Lead** | DevOps Team |
| **Service Status** | Draft (pre-release) |
| **Repository / Code** | `workflows/common/tfvars-matrix-sync` |
| **Dependencies** | `actions/checkout`, `actions/create-github-app-token`, GitHub CLI (`gh`), `jq` |
| **Slack / Support** | Platform / DevOps |

## What it does

1. Checks out the caller repository.
2. Finds `*.tfvars` in `working_directory`/`vars_folder` (non-recursive).
3. Strips the `.tfvars` extension and writes sorted JSON: `{"workspaces":["dev","prod",...]}`.
4. Mints a GitHub App installation token scoped to `destination_repository`.
5. Checks out the destination repo, commits the JSON to `destination_path` on `pr_branch`, and opens or updates a PR against `destination_base_branch`.

## JSON shape

```json
{
  "workspaces": ["dev", "prod", "staging"]
}
```

## Inputs (`workflow_call`)

| Input | Required | Default | Description |
| --- | --- | --- | --- |
| `vars_folder` | Yes | — | Folder with `*.tfvars` relative to `working_directory`. |
| `working_directory` | No | `.` | Source root relative to the caller repo. |
| `destination_repository` | Yes | — | Destination `owner/repo`. |
| `destination_path` | Yes | — | JSON path inside the destination repo. |
| `destination_base_branch` | No | `main` | PR base branch. |
| `pr_branch` | No | `chore/sync-tfvars-matrix` | PR head branch (force-updated). |
| `pr_title` | No | `chore: sync tfvars workspace matrix` | Commit message and PR title. |
| `environment_name` | No | `sandbox` | GitHub Environment for the write-capable job. |

## Secrets (`workflow_call`)

| Secret | Required | Description |
| --- | --- | --- |
| `app_id` | Yes | GitHub App client ID. |
| `app_private_key` | Yes | GitHub App private key. |

### GitHub App permissions (destination)

Install the App on the destination repository (or org) with at least:

- **Contents**: Read and write
- **Pull requests**: Read and write

## Outputs

| Output | Description |
| --- | --- |
| `pr_url` | Opened/updated PR URL, or empty when the matrix is unchanged. |
| `workspaces_count` | Number of discovered workspaces. |

## Usage examples

### Call from another workflow (same org)

```yaml
jobs:
  sync:
    uses: my-org/gha-reusable-actions-workflows/.github/workflows/tfvars-matrix-sync.yml@tfvars-matrix-sync-v1
    with:
      vars_folder: terraform/envs
      destination_repository: my-org/downstream-config
      destination_path: matrices/workspaces.json
      environment_name: sandbox
    secrets:
      app_id: ${{ secrets.SYNC_APP_ID }}
      app_private_key: ${{ secrets.SYNC_APP_PRIVATE_KEY }}
```

### Call from this monorepo (path reference)

```yaml
jobs:
  sync:
    uses: ./.github/workflows/tfvars-matrix-sync.yml
    with:
      vars_folder: envs
      working_directory: terraform
      destination_repository: my-org/downstream-config
      destination_path: matrices/workspaces.json
    secrets:
      app_id: ${{ secrets.SYNC_APP_ID }}
      app_private_key: ${{ secrets.SYNC_APP_PRIVATE_KEY }}
```

## Release layout

| Location | Role |
| --- | --- |
| `workflows/common/tfvars-matrix-sync/workflow.yml` | **Source** (authoring) |
| `workflows/common/tfvars-matrix-sync/readme.md` | Usage documentation |
| `.github/workflows/tfvars-matrix-sync.yml` | **Synced copy** after Release Manager `mode: release` |

Tags (after release): `tfvars-matrix-sync-1.0.0` (versioned), `tfvars-matrix-sync-v1` (stable).

## Requirements

- Caller must pass GitHub App credentials that can write contents and open PRs on the destination repository.
- Caller GitHub Environment named by `environment_name` must exist (default `sandbox`) because the sync job uses `contents: write`.
- Destination base branch must exist.
- At least one `*.tfvars` file must exist in the vars folder.
