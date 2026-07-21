## ADDED Requirements

### Requirement: Workflow_run producer documentation

The `tfvars-matrix-sync` documentation MUST describe a same-repository `workflow_run` caller that listens for **two** upstream workflows (apply and destroy), uses `types: [completed]`, runs only when `github.event.workflow_run.conclusion == 'success'`, and calls the reusable `tfvars-matrix-sync` workflow with destination this monorepo and path `matrices/workspaces.json` (or documented equivalents).

#### Scenario: Docs show success-gated workflow_run

- **WHEN** a Terraform-repo owner reads the sync component readme
- **THEN** they see a complete example with `workflows: ["…Apply…", "…Destroy…"]`, `types: [completed]`, and a success `if:` guard
- **AND** the example `uses:` the released/synced `tfvars-matrix-sync` workflow

### Requirement: Always-on merge-commit auto-merge

After `tfvars-matrix-sync` opens or updates a destination pull request with matrix changes, the workflow MUST enable or perform auto-merge using a **merge commit** (not squash or rebase). This behavior MUST NOT be gated behind a new workflow input.

#### Scenario: Changed matrix enables merge-commit auto-merge

- **WHEN** the sync job commits a changed matrix JSON and opens or updates a destination PR
- **THEN** the job requests auto-merge (or merges) with merge-commit strategy
- **AND** no workflow_call input is required to enable that behavior

#### Scenario: Unchanged matrix skips PR and merge

- **WHEN** the matrix JSON is unchanged versus the destination base
- **THEN** the job skips PR creation as today
- **AND** no merge operation is required
