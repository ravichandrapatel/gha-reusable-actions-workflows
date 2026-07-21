## Context

`tfvars-matrix-sync` already discovers `*.tfvars` → `{"workspaces":[...]}` and opens a PR on a destination repo. Gaps: (1) Terraform apply/destroy do not trigger sync; (2) 100+ apps hit flaky `raw.githubusercontent.com`; (3) matrix must reach `main` via auto-merge (merge commit). External **build-preprocess** will consume the shared fetch action.

## Goals / Non-Goals

**Goals:**

- House composite `actions/common/fetch-repo-file` via Contents API + retries.
- README recipe for pasting into build-preprocess.
- Docs for Terraform-repo `workflow_run` → call sync on success of apply + destroy workflows.
- Sync always auto-merges destination PR with **merge commit**.
- Document destination: this monorepo, `matrices/workspaces.json`.

**Non-Goals:**

- Owning Terraform workflows in this repo; implementing build-preprocess; squash auto-merge; raw CDN.

## Decisions

1. **Fetch via Contents API (not raw, not sparse checkout)**  
   `GET /repos/{owner}/{repo}/contents/{path}?ref=` with token; decode base64; write file; retry transient 404/5xx. Lighter than full checkout; stable vs CDN.

2. **Action: `actions/common/fetch-repo-file`**  
   Inputs: `repository` (owner/repo), `path`, `ref` (default `main`), `destination` (runner path), `github_token` (default `${{ github.token }}`), retry knobs. Outputs: `destination` path, optional `sha`. Composite + bash + `gh api` (runner has `gh`). SHA-pin any third-party `uses:` if added (prefer zero third-party beyond none).

3. **Producer: `workflow_run` in Terraform repo (docs only here)**  
   ```yaml
   on:
     workflow_run:
       workflows: ["<Apply Workflow Name>", "<Destroy Workflow Name>"]
       types: [completed]
   jobs:
     sync:
       if: ${{ github.event.workflow_run.conclusion == 'success' }}
       uses: <org>/gha-reusable-actions-workflows/.github/workflows/tfvars-matrix-sync.yml@<pin>
       with:
         destination_repository: <org>/gha-reusable-actions-workflows
         destination_path: matrices/workspaces.json
         # vars_folder / working_directory as today
       secrets: inherit # or explicit App secrets
   ```
   Same-repo constraint for `workflow_run` documented clearly.

4. **Auto-merge always on (no input)**  
   After PR open/update in sync job: `gh pr merge --merge --auto` (merge commit). If already mergeable and policy allows, merges when checks pass. Document repo prerequisites: allow merge commits, auto-merge enabled, App can merge.

5. **Placeholder matrix file**  
   Add `matrices/workspaces.json` with empty or minimal `{"workspaces":[]}` only if needed for path existence — prefer documenting first commit via sync PR; optional stub if consumers need a file on day one.

6. **Layout**  
   Example caller YAML in `tfvars-matrix-sync/readme.md` (and fetch action readme recipe). No second `workflow.yml` under the sync component.

## Risks / Trade-offs

- [Always-on auto-merge] → Document branch protection / required checks; App needs merge rights; failed checks block merge (expected).
- [workflow_run name coupling] → Docs stress exact `name:` match for apply/destroy.
- [GITHUB_TOKEN cross-repo] → Private matrix repo may need App/PAT in consumers; action accepts token input.
- [Merge commit + gitleaks] → User-validated preference over squash.
- [Empty workspaces] → Sync already errors on zero tfvars; stub file on destination is separate.

## Migration Plan

1. Land fetch action + docs; release/promote when ready.
2. Patch sync auto-merge; update sync readme (workflow_run + destination).
3. Terraform repo: add workflow_run caller; set apply/destroy names.
4. build-preprocess: adopt recipe / `uses:` fetch-repo-file.
5. Rollback: revert sync auto-merge commit; consumers keep last good JSON on `main`.

## Open Questions

None — grill-me closed.
