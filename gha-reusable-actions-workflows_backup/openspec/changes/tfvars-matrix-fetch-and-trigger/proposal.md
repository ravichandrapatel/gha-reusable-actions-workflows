## Why

Terraform apply/destroy must refresh the shared workspace matrix in this monorepo, and 100+ application pipelines must load that JSON reliably. `raw.githubusercontent.com` intermittently 404s; consumers need an authenticated Contents-API path. Sync PRs must land on `main` without a manual merge click.

## What Changes

- Add composite action `actions/common/fetch-repo-file` — GitHub Contents API fetch with token, retries, write-to-path (no raw CDN).
- Document paste-ready recipe in that action’s `readme.md` for integrating into external **build-preprocess**.
- Document Terraform-repo **`workflow_run`** caller pattern (apply + destroy workflow names, `completed` + `conclusion == success`) that `uses:` `tfvars-matrix-sync`.
- **BREAKING** for sync behavior: `tfvars-matrix-sync` always enables **auto-merge** with a **merge commit** after opening/updating the destination PR (no new input). Destination defaults in docs: this repo, `matrices/workspaces.json`.

## Capabilities

### New Capabilities

- `fetch-repo-file`: Authenticated Contents-API file fetch action + build-preprocess integration recipe.
- `tfvars-matrix-trigger-recipe`: Documented `workflow_run` producer pattern calling `tfvars-matrix-sync` after successful apply/destroy.

### Modified Capabilities

- (none in `openspec/specs/` today — sync behavior change is implemented against existing workflow + covered by new/delta requirements under this change’s specs)

## Non-goals

- Implementing build-preprocess itself (lives elsewhere).
- Shipping Terraform apply/destroy workflows in this monorepo.
- `raw.githubusercontent.com` support.
- Squash/rebase auto-merge.
- Changing matrix JSON shape (`{"workspaces":[...]}`).

## OKF Prompt Pack

Keywords: `tfvars-matrix-sync github actions trigger reusable workflow json artifact raw.githubusercontent release pin custom action`

Cards: gha-ci-pipeline-recipe, gha-action-pin-catalog, gha-reusable-actions-workflows, github-actions, release-manager-modes.

## Grill-me decisions

- Scope: **both** producer trigger + consumer fetch.
- Consumer: shared Contents-API action here + README recipe for build-preprocess.
- Producer: **separate** `workflow_run` (`types: [completed]`), **success-only**, **two** upstream workflows (apply + destroy).
- Matrix destination: **this** monorepo, path **`matrices/workspaces.json`**.
- Auto-merge: **always on**, **no input**, method **merge commit** (gitleaks issues with squash).

## Deviations from user request (OKF auto-correct)

- Pins: third-party `uses:` remain SHA-pinned per house catalog (no `@vN`).
- Layout: new action under `actions/common/fetch-repo-file/` only; `workflow_run` example lives in docs/readme (not a second YAML inside `tfvars-matrix-sync/`).

## Impact

- New `actions/common/fetch-repo-file/**`
- `workflows/common/tfvars-matrix-sync/workflow.yml` + `readme.md`
- Optional placeholder `matrices/workspaces.json` if missing
- Consumers / Terraform repos adopt via docs (out of band)
