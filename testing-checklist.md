# Testing Checklist: Release Manager Workflow

This checklist is used to verify the functionality of the `release-manager.yml` workflow.

## 0. Prerequisites (Mandatory)
- [ ] **GitHub App Config**: Ensure the GitHub App has `contents: write` and `workflows: write` permissions.
- [ ] **Branch Protection**: If `main` is protected, add the GitHub App to the **"Allow bypass"** list in the branch protection rules for `main`. This is required for the workflow to sync `.github/workflows/` files directly.
- [ ] **Secrets**: Configure `RELEASE_APP_ID` and `RELEASE_APP_PRIVATE_KEY` in the repository.

## 1. Release Mode Verification
- [ ] **Action Release**: Verify versioned tag is created.
- [ ] **Workflow Release**: Verify versioned tag is created AND `.github/workflows/` is synced in the same commit.
- [ ] **Tag Collision**: Verify collision detection for versioned tags.

## 2. Promote Mode Verification
- [ ] **Stable Tag Pointer**: Verify `v1` points to the EXACT same commit as the versioned tag.
- [ ] **No Force Push**: Verify tags are updated by deleting remote first instead of using `--force`.
- [ ] **Stable Tag Name**: Verify stable tag is named `v1` (no component prefix).

## 3. Rollback Mode Verification
- [ ] **Rollback Pointer**: Verify `v1` is updated to point to the previous versioned tag.
- [ ] **Workflow Restoration**: Verify `.github/workflows/` file is restored on `main`.

## 4. Security Tool Verification
- [ ] **Actionlint**: Introduce a syntax error in `action.yml` and verify `security` job fails.
- [x] **Checkov**: Verify GitHub Actions framework scans are performed.
- [x] **Bandit**: Introduce a security issue in a `.py` file (e.g., `eval()`) and verify `security` job fails.
- [x] **Shellcheck**: Introduce a shell script issue and verify `security` job fails.

## 5. Branch Protection Verification
- [ ] **Bypass**: Enable branch protection on `main` and verify the GitHub App can still push workflow syncs (requires "Allow bypass" configuration).
