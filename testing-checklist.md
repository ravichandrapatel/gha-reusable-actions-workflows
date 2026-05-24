# Testing Checklist: Release Manager Workflow

This checklist is used to verify the functionality of the `release-manager.yml` workflow.

## 0. Prerequisites (Mandatory)
- [ ] **GitHub App Config**: Ensure the GitHub App has `contents: write` and `workflows: write` permissions.
- [ ] **Branch Protection**: If `main` is protected, add the GitHub App to the **"Allow bypass"** list in the branch protection rules for `main`. This is required for the workflow to sync `.github/workflows/` files directly.
- [ ] **Secrets**: Configure `RELEASE_APP_ID` and `RELEASE_APP_PRIVATE_KEY` in the repository.

## 1. Release Mode Verification
- [x] **Trigger**: Run workflow with `mode: release`, `component_path: actions/common/janitor-bot`.
- [x] **Validation**:
  - [x] Verify `validate` job succeeds.
  - [x] Verify `Calculate Next Version` step runs and derives a new version (e.g., `0.0.1`).
- [x] **Security**:
  - [x] Verify `security` job succeeds (Checkov, Bandit, Shellcheck). *Note: Actionlint skipped for actions as it misinterpreted them as workflows.*
- [ ] **Execution**:
  - [ ] Verify a new tag `janitor-bot-0.0.1` is created in the repository. *Note: Failed due to missing RELEASE_APP_ID/PRIVATE_KEY secrets.*
- [x] **Audit**:
  - [x] Verify `audit` job logs the correct metadata.

## 2. Tag Collision Verification
- [x] **Trigger**: Run workflow again with the SAME version (e.g., `0.0.1`) and `mode: release`.
- [x] **Validation**:
  - [x] Verify `validate` job FAILS with a "Tag collision detected" error.

## 3. Promote Mode Verification
- [x] **Trigger**: Run workflow with `mode: promote`, `component_path: actions/common/janitor-bot`, `version: 0.0.1`.
- [x] **Execution**:
  - [ ] Verify `execute` job succeeds. *Note: Failed due to missing RELEASE_APP_ID/PRIVATE_KEY secrets.*
  - [ ] Verify stable tag `janitor-bot-v1` is created/updated to point to `janitor-bot-0.0.1`.

## 4. Rollback Mode Verification
- [x] **Trigger**: Run workflow with `mode: rollback`, `component_path: actions/common/janitor-bot`, `version: 0.0.2`.
- [x] **Execution**:
  - [ ] Verify `execute` job succeeds. *Note: Failed due to missing RELEASE_APP_ID/PRIVATE_KEY secrets.*
  - [ ] Verify stable tag `janitor-bot-v1` is updated to point to the PREVIOUS version (e.g., `0.0.1`).

## 5. Security Tool Verification
- [ ] **Actionlint**: Introduce a syntax error in `action.yml` and verify `security` job fails.
- [x] **Checkov**: Verify GitHub Actions framework scans are performed.
- [x] **Bandit**: Introduce a security issue in a `.py` file (e.g., `eval()`) and verify `security` job fails.
- [x] **Shellcheck**: Introduce a shell script issue and verify `security` job fails.
