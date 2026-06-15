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
- [x] **Checkov**: Verify GitHub Actions framework scans with OWASP SPVS YAML policies (`CKV2_SPVS_*`).
  - Policies: `policies/github_actions/*.yaml`
  - Config: `.checkov.yaml`
  - Policies apply to **both** `actions/` (via synthetic workflow) and `workflows/` (direct copy); same YAML rules, same graph entities (`jobs`, `steps`, `permissions`, `on`).
  - Stage with `python3 policies/scripts/stage_component.py --include-repo-workflows` to also scan `.github/workflows/` (e.g. release-manager).
  - **Pre-commit (shell only):** `pip install -r requirements-dev.txt` then `pre-commit install --hook-type pre-commit --hook-type commit-msg`. Hooks: `pre_commit_spvs.sh` (Checkov via `stage_component.sh`, Shellcheck, Actionlint, Bandit) and `validate_commit_message.sh`. System tools: `shellcheck`, `actionlint`, `yq`.
  - Policy IDs: `CKV2_SPVS_1`–`15` plus built-in `CKV_GHA_*` / `CKV2_GHA_1`.
  - **Policy inventory**

    | ID | Rule |
    |----|------|
    | CKV2_SPVS_1 | Job-level `permissions` required |
    | CKV2_SPVS_2 | `set -euo pipefail` in run blocks |
    | CKV2_SPVS_3 | No `set -x` / xtrace |
    | CKV2_SPVS_4 | `python -u` or `PYTHONUNBUFFERED=1` |
    | CKV2_SPVS_5 | SHA, `./`, docker, or internal `/actions/` tags |
    | CKV2_SPVS_5B | Block `../` local action paths |
    | CKV2_SPVS_6 | No `${{ inputs.* }}` in run |
    | CKV2_SPVS_7 | No static AWS/GCP/Azure credential env vars |
    | CKV2_SPVS_8 | Cloud OIDC actions need `id-token: write` |
    | CKV2_SPVS_9 | No write scopes at workflow level |
    | CKV2_SPVS_10 | No top-level `write-all` |
    | CKV2_SPVS_11 | Write jobs need `environment:` |
    | CKV2_SPVS_12 | No bare `self-hosted` runner |
    | CKV2_SPVS_13 | No curl\|bash / bash<(curl ...) |
    | CKV2_SPVS_14 | No `${{ github.* }}` / `${{ steps.* }}` in run |
    | CKV2_SPVS_15 | No `pull_request_target` trigger |

  - **Known repo findings (policy gaps now covered)**

    | Location | Issue | Policy |
    |----------|-------|--------|
    | `release-manager.yml` | `bash <(curl ...)` actionlint install | CKV2_SPVS_13 |
    | `release-manager.yml` | Top-level `write-all` permissions | CKV2_SPVS_10 / CKV2_GHA_1 |
    | `dummy-workflow` | No permissions, no `set -euo`, inputs in run | CKV2_SPVS_1, 2, 6 |
    | `prbot`, `janitor-bot`, `git-path-filter` | Context/inputs in run, missing hardening | CKV2_SPVS_2, 4, 6, 14 |
    | `drift-auditor` | Tag-pinned public actions (`@v6`) | CKV2_SPVS_5 |
    | `owasp-dependency-check` | Inputs in run, `set -e` only | CKV2_SPVS_2, 6 |
    | `semver` | Reference component — passes all checks | — |
  - Repository/branch controls (PR reviews, signed commits, force-push, CODEOWNERS) are out of scope for workflow YAML.
- [x] **Bandit**: Introduce a security issue in a `.py` file (e.g., `eval()`) and verify `security` job fails.
- [x] **Shellcheck**: Introduce a shell script issue and verify `security` job fails.

## 5. Branch Protection Verification
- [ ] **Bypass**: Enable branch protection on `main` and verify the GitHub App can still push workflow syncs (requires "Allow bypass" configuration).
