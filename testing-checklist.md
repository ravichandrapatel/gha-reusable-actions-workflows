# Testing Checklist: Release Manager Workflow

This checklist is used to verify the functionality of the `release-manager.yml` workflow.

## 1. Release Mode Verification
- [ ] **Trigger**: Run workflow with `mode: release`, `component_path: actions/common/janitor-bot`.
- [ ] **Validation**:
  - [ ] Verify `validate` job succeeds.
  - [ ] Verify `Calculate Next Version` step runs and derives a new version (e.g., `1.0.1`).
- [ ] **Security**:
  - [ ] Verify `security` job succeeds (Actionlint, Checkov, Bandit, Shellcheck).
- [ ] **Execution**:
  - [ ] Verify `execute` job succeeds.
  - [ ] Verify a new tag `janitor-bot-1.0.1` is created in the repository.
- [ ] **Audit**:
  - [ ] Verify `audit` job logs the correct metadata.

## 2. Tag Collision Verification
- [ ] **Trigger**: Run workflow again with the SAME version (e.g., `1.0.1`) and `mode: release`.
- [ ] **Validation**:
  - [ ] Verify `validate` job FAILS with a "Tag collision detected" error.

## 3. Promote Mode Verification
- [ ] **Trigger**: Run workflow with `mode: promote`, `component_path: actions/common/janitor-bot`, `version: 1.0.1`.
- [ ] **Execution**:
  - [ ] Verify `execute` job succeeds.
  - [ ] Verify stable tag `janitor-bot-v1` is created/updated to point to `janitor-bot-1.0.1`.
- [ ] **Workflow Sync (if applicable)**:
  - [ ] If testing a workflow, verify `.github/workflows/[name].yml` is updated.

## 4. Rollback Mode Verification
- [ ] **Trigger**: Run workflow with `mode: rollback`, `component_path: actions/common/janitor-bot`, `version: 1.0.1`.
- [ ] **Execution**:
  - [ ] Verify `execute` job succeeds.
  - [ ] Verify stable tag `janitor-bot-v1` is updated to point to the PREVIOUS version (e.g., `1.0.0`).
- [ ] **Workflow Sync (if applicable)**:
  - [ ] If testing a workflow, verify `.github/workflows/[name].yml` is reverted.

## 5. Security Tool Verification
- [ ] **Actionlint**: Introduce a syntax error in `action.yml` and verify `security` job fails.
- [ ] **Checkov**: Verify GitHub Actions framework scans are performed.
- [ ] **Bandit**: Introduce a security issue in a `.py` file (e.g., `eval()`) and verify `security` job fails.
- [ ] **Shellcheck**: Introduce a shell script issue and verify `security` job fails.
