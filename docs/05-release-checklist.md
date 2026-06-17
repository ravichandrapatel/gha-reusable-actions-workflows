# Chapter 5 — Release Manager Checklist

> **Part IV — Release**

Use this checklist to verify the [Release Manager](../.github/workflows/release-manager.yml) workflow after merging component changes to `main`.

Policy reference: [README — Security policies](../README.md#security-policies-spvs--conftest). Local scans: [Chapter 4 — Testing](04-local-testing.md).

---

## 0. Prerequisites (mandatory)

- [ ] **GitHub App** has `contents: write` and `workflows: write` permissions.
- [ ] **Branch protection:** if `main` is protected, add the GitHub App to **Allow bypass** (required for `.github/workflows/` sync).
- [ ] **Secrets:** `RELEASE_APP_ID` and `RELEASE_APP_PRIVATE_KEY` configured.

See [README — Prerequisites](../README.md#prerequisites).

---

## 1. Release mode verification

Trigger: Release Manager → `mode: release`.

- [ ] **Component docs:** `readme.md` present with inputs, examples, and requirements ([Chapter 2](02-writing-components.md#component-documentation-mandatory-readmemd)).
- [ ] **Naming:** path is `actions/{category}/{name}` or `workflows/{category}/{name}` (kebab-case) ([Chapter 2](02-writing-components.md#naming-standards)).
- [ ] **Action release:** versioned tag created (e.g. `semver-1.2.0`).
- [ ] **Workflow release:** versioned tag created **and** `.github/workflows/{name}.yml` synced in the same commit.
- [ ] **Tag collision:** workflow fails cleanly when versioned tag already exists.
- [ ] **SemVer:** version derived from ticket-prefixed commits since last tag.

> **Note:** `workflows/common/dummy-workflow/workflow.yml` is the **source**; `.github/workflows/dummy-workflow.yml` is the **synced deploy copy** after release.

---

## 2. Promote mode verification

Trigger: Release Manager → `mode: promote`.

- [ ] **Stable tag pointer:** `{name}-v1` points to the **exact same commit** as the selected versioned tag.
- [ ] **No force push:** tags updated via delete-and-recreate, not `--force`.
- [ ] **Stable tag name:** stable tag is `{name}-v1` (component-scoped).

---

## 3. Rollback mode verification

Trigger: Release Manager → `mode: rollback`.

- [ ] **Rollback pointer:** `{name}-v1` updated to previous versioned tag.
- [ ] **Workflow restoration:** for workflows, `.github/workflows/{name}.yml` restored on `main`.

---

## 4. Security tool verification

Run during Release Manager `mode: release` (security job) and locally via [Chapter 4](04-local-testing.md).

- [ ] **Actionlint:** syntax error in workflow YAML fails the security job.
- [ ] **Conftest:** SPVS policies (`CKV2_SPVS_*`, `CKV_GHA_*`, `CKV2_GHA_1`) enforced via Rego under `policies/conftest/github_actions/`.
  - Workflows scanned with `-n workflow`; composite actions with `-n composite`.
  - Release Manager scans **only the component file** (`-f`), matching Actionlint scope.
  - Scan locally: `bash policies/scripts/conftest-gha.sh -f workflows/common/dummy-workflow/workflow.yml`.
  - Full policy catalog: [README — Custom policies](../README.md#custom-policies-ckv2_spvs_1--ckv2_spvs_15).
- [ ] **Bandit:** security issue in `.py` fails the security job.
- [ ] **Shellcheck:** issue in `.sh` fails the security job.

Repository/branch controls (PR reviews, signed commits, force-push, CODEOWNERS) are enforced in **GitHub settings**, not workflow YAML.

### Reference components

| Reference components | Status |
| :--- | :--- |
| `actions/common/semver` | Passes all SPVS checks — `action.yml` + `readme.md` |
| `workflows/common/dummy-workflow` | Passes all SPVS checks — `workflow.yml` + `readme.md` |

Other components may have open remediation items; run Conftest locally before release.

---

## 5. Branch protection verification

- [ ] With branch protection on `main`, GitHub App can still push workflow syncs (**Allow bypass** configured).

---

**Navigation:** ← [Testing](04-local-testing.md) | [Contents](README.md)
