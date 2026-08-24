# Change close-out write-back: tfvars-inventory-sync

**Evidence grade:** observed
**Suggested destination:** vault/systems/gha-reusable-actions-workflows.md (component inventory) | MAINTAIN later

## What shipped / learned

- New reusable workflow `workflows/common/tfvars-inventory-sync`: caller passes `folder_name`; non-recursive `*.tfvars` basenames → `{"repos":[...]}` `inventory.json`.
- GitHub App token is scoped to `destination_repo` (not `github.repository` / caller). Caller-only tokens cannot push into this catalog’s `actions/common/build-preprocess`.
- App credentials are inherited (`secrets: inherit` → `APP_ID` / `APP_PRIVATE_KEY`); no `workflow_call` secrets block.
- On JSON change: commit `actions/common/build-preprocess/inventory.json` to `main`, then `gh workflow run release-manager.yml` with `mode=release-promote` and `component_path=actions/common/build-preprocess`. Unchanged JSON skips both.
- Scaffolded empty-dir `actions/common/build-preprocess` with `action.yml` + stub `inventory.json` so Release Manager validation has a composite to tag.
- Cross-repo `uses:` still requires Release Manager to sync the workflow into `.github/workflows/tfvars-inventory-sync.yml`.
- App needs catalog **Contents: write** and **Actions: write**. Protected `main` needs the same App bypass as Release Manager.
- Conftest: workflow 26/26, composite 14/14 (2026-08-17). Pins: checkout `3d3c42e5…` v7.0.1, create-github-app-token `bcd2ba49…` v3.2.0.
