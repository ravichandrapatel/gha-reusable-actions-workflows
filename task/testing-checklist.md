# SPVS / Conftest — Comprehensive Testing Checklist

Use this checklist after policy changes, hook/CI wiring changes, or before a release promotion.
Mark each item `[x]` when verified. Record date, tester, and notes in the **Sign-off** section.

**Scope:** Conftest Rego policies, Conftest CLI, pre-commit hooks, Release Manager security job, and regression against all in-repo workflows/actions.

---

## 0. Prerequisites

| # | Check | Command / action | Expected |
|---|-------|------------------|----------|
| 0.1 | [ ] Clean git working tree (or note intentional changes) | `git status` | No unexpected untracked policy files |
| 0.2 | [ ] Repo root | `git rev-parse --show-toplevel` | Points to clone root |
| 0.3 | [ ] Conftest installed (≥ 0.56.0) | `conftest --version` | `Conftest: 0.56.0` (or pinned version) |
| 0.4 | [ ] Pre-commit installed | `pre-commit --version` | Version prints |
| 0.5 | [ ] Actionlint installed | `actionlint -version` | v1.7.12+ (or pinned in `install_hooks.sh`) |
| 0.6 | [ ] Bandit installed | `bandit --version` | Version prints |
| 0.7 | [ ] Shellcheck installed | `shellcheck --version` | Version prints |
| 0.8 | [ ] Python 3.12+ (for Bandit on action Python) | `python3 --version` | 3.12+ |
| 0.9 | [ ] Install script succeeds on fresh machine | `bash policies/scripts/install_hooks.sh` | Exit 0; conftest + actionlint in PATH |
| 0.10 | [ ] Checkov fully removed | `command -v checkov; ls policies/github_actions 2>&1; test ! -f .checkov.yaml` | All missing / not found |

---

## 1. Automated test suite (run first)

| # | Check | Command | Expected |
|---|-------|---------|----------|
| 1.1 | [ ] Full policy test runner | `bash policies/tests/run_tests.sh` | Exit 0; message `All SPVS policy tests passed` |
| 1.2 | [ ] Workflow `conftest verify` | `conftest verify -p policies/conftest/github_actions/workflow` | 5 tests, 5 passed |
| 1.3 | [ ] Composite `conftest verify` | `conftest verify -p policies/conftest/github_actions/composite` | 3 tests, 3 passed |
| 1.4 | [ ] Full repo scan | `bash policies/tests/run_tests.sh` | Exit 0; workflows + composites, 0 failures |

---

## 2. Conftest CLI — scan behavior

### 2.1 Full repo and single-file scans

| # | Check | Command | Expected |
|---|-------|---------|----------|
| 2.1.1 | [ ] Full repo scan | `bash policies/tests/run_tests.sh` | Exit 0; workflows + composites, 0 failures |
| 2.1.2 | [ ] Missing conftest | `CONFTEST_BIN=/nonexistent bash policies/tests/run_tests.sh` | Exit 1; conftest not found message |
| 2.1.3 | [ ] Single workflow | `conftest test --parser yaml -n workflow -p policies/conftest/github_actions/workflow -p policies/conftest/github_actions/lib workflows/common/dummy-workflow/workflow.yml` | Pass |
| 2.1.4 | [ ] Single composite action | `conftest test --parser yaml -n composite -p policies/conftest/github_actions/composite -p policies/conftest/github_actions/lib actions/common/semver/action.yml` | Pass |
| 2.1.5 | [ ] Policy failure exit code | Scan a known-bad fixture (see §4) | Exit 1 |

### 2.2 Scannable path patterns

| # | Path pattern | Namespace | Package |
|---|--------------|-----------|---------|
| 2.2.1 | [ ] `actions/common/foo/action.yml` | composite | `-n composite` |
| 2.2.2 | [ ] `actions/common/foo/action.yaml` | composite | `-n composite` |
| 2.2.3 | [ ] `workflows/common/foo/workflow.yml` | workflow | `-n workflow` |
| 2.2.4 | [ ] `workflows/common/foo/workflow.yaml` | workflow | `-n workflow` |
| 2.2.5 | [ ] `.github/workflows/release-manager.yml` | workflow | `-n workflow` |
| 2.2.6 | [ ] `.github/actions/my-action/action.yml` | composite | `-n composite` |

### 2.3 Namespace isolation

| # | Check | Action | Expected |
|---|-------|--------|----------|
| 2.4.1 | [ ] Workflow file without `-n workflow` fails silently | `conftest test --parser yaml -p policies/conftest/github_actions/workflow workflows/common/dummy-workflow/workflow.yml` | 0 failures (wrong namespace — **must not** use in CI) |
| 2.4.2 | [ ] Workflow file with `-n workflow` | Same + `-n workflow` | Passes on dummy-workflow |
| 2.4.3 | [ ] Composite with `-n composite` | `conftest test --parser yaml -n composite -p policies/conftest/github_actions/composite actions/common/git-path-filter/action.yml` | Passes |
| 2.4.4 | [ ] Composite not evaluated by workflow rules | Action missing `set -euo pipefail` scanned with workflow namespace | Should **not** report CKV2_SPVS_2 (no `jobs`) |

---

## 3. Pre-commit hooks

Install hooks: `pre-commit install` (from repo root).

### 3.1 Hook registration

| # | Check | Command | Expected |
|---|-------|---------|----------|
| 3.1.1 | [ ] Hooks installed | `pre-commit run --help` / `.git/hooks/pre-commit` exists | Hook file present |
| 3.1.2 | [ ] All hooks listed | `pre-commit run --all-files --verbose` (or per-hook below) | shellcheck, bandit, actionlint, spvs-gha |

### 3.2 `spvs-gha` hook (`run_spvs_gha.sh`)

| # | Check | Action | Expected |
|---|-------|--------|----------|
| 3.2.1 | [ ] No args → skip | Hook with empty file list | Exit 0 immediately |
| 3.2.2 | [ ] Unrelated file → skip | `pre-commit run spvs-gha --files README.md` | Skipped / exit 0 |
| 3.2.3 | [ ] Action change scopes scan | Touch `actions/common/semver/action.yml`; run hook | Scans `actions/` tree (not entire unrelated dirs only) |
| 3.2.4 | [ ] Workflow change | Touch `workflows/common/dummy-workflow/workflow.yml` | Scans `workflows/` |
| 3.2.5 | [ ] `.github/workflows` change | Touch `.github/workflows/release-manager.yml` | Scans `.github/workflows` |
| 3.2.6 | [ ] Rego policy change triggers full rescan | Touch `policies/conftest/github_actions/workflow/steps.rego` | All four default roots scanned |
| 3.2.7 | [ ] Missing conftest | Unset PATH to conftest; run hook | Exit 2; install message |
| 3.2.8 | [ ] Introduced violation blocks commit | Add `run: echo no pipefail` to a step; stage file | Hook exit 1 |

**File pattern coverage** (must match `.pre-commit-config.yaml`):

- [ ] `actions/**`
- [ ] `workflows/**`
- [ ] `.github/workflows/**`
- [ ] `.github/actions/**`
- [ ] `policies/conftest/**`

### 3.3 `actionlint` hook

| # | Check | Action | Expected |
|---|-------|--------|----------|
| 3.3.1 | [ ] Valid workflow passes | `pre-commit run actionlint --files workflows/common/dummy-workflow/workflow.yml` | Pass |
| 3.3.2 | [ ] `.github/workflows` scanned | `pre-commit run actionlint --files .github/workflows/release-manager.yml` | Pass (or report real lint issues) |
| 3.3.3 | [ ] Composite action path skipped | `pre-commit run actionlint --files actions/common/git-path-filter/action.yml` | Skipped / no error |
| 3.3.4 | [ ] Syntax error caught | Introduce invalid `on:` key; run hook | Exit 1 |

### 3.4 `bandit` hook

| # | Check | Action | Expected |
|---|-------|--------|----------|
| 3.4.1 | [ ] Python in actions scanned | `pre-commit run bandit --files actions/common/git-path-filter/main.py` | Pass (or real findings) |
| 3.4.2 | [ ] Non-Python skipped | `pre-commit run bandit --files policies/scripts/hooks/run_spvs_gha.sh` | Skipped |

### 3.5 `shellcheck` hook

| # | Check | Action | Expected |
|---|-------|--------|----------|
| 3.5.1 | [ ] Shell scripts scanned | `pre-commit run shellcheck --files policies/scripts/hooks/run_spvs_gha.sh` | Pass |
| 3.5.2 | [ ] `set -euo pipefail` present in hook scripts | Manual review of `policies/scripts/**/*.sh` | All entry scripts use defensive bash |

### 3.6 Full pre-commit run

| # | Check | Command | Expected |
|---|-------|---------|----------|
| 3.6.1 | [ ] All files | `pre-commit run --all-files` | All hooks pass on current main |
| 3.6.2 | [ ] Staged-only (normal commit flow) | Stage one valid YAML change; `pre-commit run` | Pass |

---

## 4. Policy rule matrix — workflow namespace

For each rule: verify **deny on violation** and **pass on compliant fixture**.
Use `conftest test --parser yaml -n workflow -p policies/conftest/github_actions/workflow /path/to/fixture.yml`.

### 4.1 Official Checkov rules (CKV_GHA_*)

| ID | Rule | Violation fixture (must FAIL) | Compliant pattern (must PASS) |
|----|------|------------------------------|------------------------------|
| 4.1.1 | [ ] **CKV_GHA_1** | Job or step `env: ACTIONS_ALLOW_UNSECURE_COMMANDS: true` | Omit variable or set false |
| 4.1.2 | [ ] **CKV_GHA_2** | `run: echo "${{ github.event.issue.title }}"` | Map to `env:` first |
| 4.1.3 | [ ] **CKV_GHA_3** | Same line: `curl … secret` | Separate lines or no secrets in curl line |
| 4.1.4 | [ ] **CKV_GHA_4** | `run: nc 192.168.1.1 4444` | No netcat-to-IP pattern |

### 4.2 Official Checkov rules (CKV2_GHA_*)

| ID | Rule | Violation fixture | Compliant pattern |
|----|------|-------------------|-------------------|
| 4.2.1 | [ ] **CKV2_GHA_1** | `permissions: write-all` | Explicit read scopes |

### 4.3 SPVS permissions / workflow structure

| ID | Rule | Violation fixture | Compliant pattern |
|----|------|-------------------|-------------------|
| 4.3.1 | [ ] **CKV2_SPVS_1** | Job without `permissions:` | Every job has `permissions:` |
| 4.3.2 | [ ] **CKV2_SPVS_8** | Step `uses: aws-actions/configure-aws-credentials@…` without `id-token: write` | Job `permissions: id-token: write` |
| 4.3.3 | [ ] **CKV2_SPVS_9** | Workflow-level `permissions: contents: write` | Write only on specific jobs |
| 4.3.4 | [ ] **CKV2_SPVS_10** | `permissions: write-all` | Same as CKV2_GHA_1 |
| 4.3.5 | [ ] **CKV2_SPVS_11** | Job `contents: write` without `environment:` | Add `environment: staging` (etc.) |
| 4.3.6 | [ ] **CKV2_SPVS_12** | `runs-on: self-hosted` (bare) | `ubuntu-latest` or labeled runner |
| 4.3.7 | [ ] **CKV2_SPVS_15** | `on: pull_request_target:` | Use `pull_request:` instead |

### 4.4 SPVS step / supply chain (workflow jobs)

| ID | Rule | Violation fixture | Compliant pattern |
|----|------|-------------------|-------------------|
| 4.4.1 | [ ] **CKV2_SPVS_2** | `run: echo hi` (no pipefail) | `set -euo pipefail` in block |
| 4.4.2 | [ ] **CKV2_SPVS_3** | `run: set -x …` or `set -o xtrace` | No xtrace |
| 4.4.3 | [ ] **CKV2_SPVS_4** | `run: python3 script.py` (no `-u`) | `python3 -u` or `PYTHONUNBUFFERED` in env |
| 4.4.4 | [ ] **CKV2_SPVS_5** | `uses: actions/checkout@v4` (tag only) | 40-char SHA, `./`, `docker://`, or internal `/actions/` tag |
| 4.4.5 | [ ] **CKV2_SPVS_5B** | `uses: ../other-action` | `./.github/actions/…` or remote SHA |
| 4.4.6 | [ ] **CKV2_SPVS_6** | `run: echo "${{ inputs.foo }}"` | `env: INPUT_FOO: ${{ inputs.foo }}` |
| 4.4.7 | [ ] **CKV2_SPVS_7** | Step `env: AWS_ACCESS_KEY_ID: …` | OIDC / secrets manager |
| 4.4.8 | [ ] **CKV2_SPVS_13** | `curl … \| bash` or `wget … \| sh` | Download + checksum (see release-manager) |

### 4.5 Rego / YAML edge cases (workflow)

| # | Scenario | Expected |
|---|----------|----------|
| 4.5.1 | [ ] Multiline `run: \|` with leading whitespace before `set -euo pipefail` | PASS (matches after newline) |
| 4.5.2 | [ ] `run` on line 2+ of step (after `name:`, `shell:`) | PASS if pipefail present |
| 4.5.3 | [ ] Step with only `uses:` (no `run:`) | SPVS_2/3/4/6/13 not applied |
| 4.5.4 | [ ] `curl` + `\| sha256sum` (not `\| sh`) | PASS — not CKV2_SPVS_13 |
| 4.5.5 | [ ] `permissions["id-token"]` OIDC check | Uses bracket key, not `id-token` identifier |
| 4.5.6 | [ ] Multiple jobs; one bad | Only bad job reported in message |

---

## 5. Policy rule matrix — composite namespace

Use `conftest test --parser yaml -n composite -p policies/conftest/github_actions/composite /path/to/action.yml`.

| ID | Applies to composite? | Violation | Compliant |
|----|----------------------|-----------|-----------|
| 5.1 | [ ] CKV_GHA_1–4 | Same as §4.1 in `runs.steps[].run` / env | Same fixes |
| 5.2 | [ ] CKV2_SPVS_2–7, 13, 14, 5, 5B | Same step rules | Same fixes |
| 5.3 | [ ] CKV2_SPVS_1, 8, 9, 10, 11, 12, 15 | N/A (no jobs) | Must **not** fire on composite input |
| 5.4 | [ ] Non-composite action (`runs.using: node20`) | Policies skipped | No false denies from composite rules |
| 5.5 | [ ] Multiple steps; one missing pipefail | FAIL naming step context in message |

---

## 6. In-repository regression (known-good files)

Every file must pass a full scan after any policy edit.

### 6.1 Workflows

| File | [ ] Pass | Notes |
|------|----------|-------|
| `workflows/common/dummy-workflow/workflow.yml` | | Reusable workflow; pipefail + job permissions |
| `.github/workflows/release-manager.yml` | | curl + sha256sum (not pipe-to-sh); multi-job pipefail |

### 6.2 Composite actions

| File | [ ] Pass | Notes |
|------|----------|-------|
| `actions/common/git-path-filter/action.yml` | | Multi-step; python + PYTHONUNBUFFERED |
| `actions/common/semver/action.yml` | | |
| `actions/common/janitor-bot/action.yml` | | |
| `actions/common/prbot/action.yml` | | |
| `actions/common/drift-auditor/action.yml` | | |
| `actions/common/issues-bot/action.yml` | | |
| `actions/security/owasp-dependency-check/action.yml` | | |

### 6.3 Python / shell in components (non-Conftest but pre-commit)

| Component | [ ] Bandit | [ ] Shellcheck on `*.sh` |
|-----------|------------|--------------------------|
| `actions/common/git-path-filter/main.py` | | |
| Each `actions/*/run.sh` or hook script | | |

---

## 7. Release Manager CI (`mode: release`)

Run via `workflow_dispatch` on `.github/workflows/release-manager.yml` (or dry-run in a fork).

### 7.1 Security job — tool install

| # | Check | Expected in logs |
|---|-------|------------------|
| 7.1.1 | [ ] Bandit installs | `bandit --version` |
| 7.1.2 | [ ] Conftest installs (v0.56.0) | `conftest --version` |
| 7.1.3 | [ ] Checkov **not** installed | No `checkov --version` |
| 7.1.4 | [ ] Actionlint + Shellcheck + yq | All version lines present |

### 7.2 Security job — scans per component type

Test each row with a real component path:

| Component path | Actionlint | Conftest CLI | Bandit | Shellcheck |
|----------------|------------|--------------|--------|------------|
| 7.2.1 [ ] `actions/common/git-path-filter` | Skipped (action) | `conftest test -n composite … action.yml` | If `*.py` | If `*.sh` |
| 7.2.2 [ ] `actions/common/semver` | Skipped | Single `action.yml` scan | | |
| 7.2.3 [ ] `workflows/common/dummy-workflow` | Runs on `workflow.yml` | `conftest test -n workflow … workflow.yml` | N/A | N/A |
| 7.2.4 [ ] `actions/security/owasp-dependency-check` | Skipped | Pass | | |

### 7.3 Security job — failure propagation

| # | Inject violation | Expected |
|---|------------------|----------|
| 7.3.1 | [ ] Remove `set -euo pipefail` in component | Security job fails; release blocked |
| 7.3.2 | [ ] Unpinned third-party `uses:` | CKV2_SPVS_5 failure |
| 7.3.3 | [ ] Restore clean component | Security job green |

### 7.4 Promote mode (no Checkov cache)

| # | Check | Expected |
|---|-------|----------|
| 7.4.1 | [ ] `mode: promote` | No Checkov cache refresh step |
| 7.4.2 | [ ] Stable tag updated | Tag points to versioned release |

---

## 8. `conftest verify` — extend unit tests

Existing tests in `workflow_test.rego` / `composite_test.rego`. Add tests when touching rules.

| # | Test case | File | [ ] Covered |
|---|-----------|------|-------------|
| 8.1 | Missing job permissions | workflow_test.rego | ✓ (existing) |
| 8.2 | Missing pipefail | workflow_test.rego | ✓ |
| 8.3 | Minimal valid workflow | workflow_test.rego | ✓ |
| 8.4 | write-all | workflow_test.rego | ✓ |
| 8.5 | pull_request_target | workflow_test.rego | ✓ |
| 8.6 | Composite missing pipefail | composite_test.rego | ✓ |
| 8.7 | Composite valid | composite_test.rego | ✓ |
| 8.8 | Composite `../` uses | composite_test.rego | ✓ |
| 8.9 | [ ] CKV_GHA_2 injection pattern | *add test* | |
| 8.10 | [ ] CKV2_SPVS_8 OIDC | *add test* | |
| 8.11 | [ ] CKV2_SPVS_13 curl pipe | *add test* | |
| 8.12 | [ ] CKV2_SPVS_5 unpinned action | *add test* | |

After adding tests: `conftest verify -p policies/conftest/github_actions/{workflow,composite}`

---

## 9. Negative / failure-mode testing

| # | Scenario | Expected |
|---|----------|----------|
| 9.1 | [ ] Invalid YAML input | Conftest parse error (non-zero) |
| 9.2 | [ ] Empty YAML `{}` workflow | Multiple denies (permissions, jobs, etc.) |
| 9.3 | [ ] Workflow with `jobs:` empty | No step-level failures |
| 9.4 | [ ] Rego syntax error in policy | `conftest verify` fails at load |
| 9.5 | [ ] Duplicate `deny` messages | Acceptable (CKV2_GHA_1 + CKV2_SPVS_10 both fire on write-all) |

---

## 10. Migration / removal verification

| # | Check | Expected |
|---|-------|----------|
| 10.1 | [ ] `policies/github_actions/` absent | Directory deleted |
| 10.2 | [ ] `policies/scripts/checkov-gha.sh` absent | Deleted |
| 10.3 | [ ] `.checkov.yaml` absent | Deleted |
| 10.4 | [ ] `requirements-dev.txt` has no checkov/pytest | bandit + pre-commit only |
| 10.5 | [ ] `release-manager.yml` runs Conftest CLI directly | `conftest test` with `-n workflow` or `-n composite` and `-p …/lib` |
| 10.6 | [ ] `policies/scripts/conftest-gha.sh` absent | Deleted; use Conftest CLI or `run_tests.sh` |
| 10.7 | [ ] Pre-commit hook name | `SPVS GitHub Actions (Conftest)` |
| 10.8 | [ ] `.checkov.cache` not committed on promote | Promote block removed |

---

## 11. Performance & operability

| # | Check | Command | Expected |
|---|-------|---------|----------|
| 11.1 | [ ] Full scan duration | `time bash policies/tests/run_tests.sh` | < 30s on dev machine (9 files) |
| 11.2 | [ ] Single-component scan | `conftest test … actions/common/semver/action.yml` | Faster than full scan |
| 11.3 | [ ] Output readable | Manual | Check IDs (CKV_*) in messages |
| 11.4 | [ ] `CONFTEST_BIN` override | `CONFTEST_BIN=/path/to/conftest bash policies/tests/run_tests.sh` | Uses override |

---

## 12. Quick reference commands

```bash
# One-shot full local validation
bash policies/tests/run_tests.sh

# Policy unit tests only
conftest verify -p policies/conftest/github_actions/workflow \
  -p policies/conftest/github_actions/lib
conftest verify -p policies/conftest/github_actions/composite \
  -p policies/conftest/github_actions/lib

# Single workflow
conftest test --parser yaml -n workflow \
  -p policies/conftest/github_actions/workflow \
  -p policies/conftest/github_actions/lib \
  workflows/common/dummy-workflow/workflow.yml

# Single composite action
conftest test --parser yaml -n composite \
  -p policies/conftest/github_actions/composite \
  -p policies/conftest/github_actions/lib \
  actions/common/git-path-filter/action.yml

# Pre-commit (all hooks)
pre-commit run --all-files

# Install tooling
bash policies/scripts/install_hooks.sh
```

---

## 13. Sign-off

| Field | Value |
|-------|-------|
| Date | |
| Branch / commit | |
| Conftest version | |
| Tester | |
| Full scan (§1.4) | Pass / Fail |
| Pre-commit (§3.6) | Pass / Fail |
| Release Manager (§7) | Pass / Fail / N/A |
| Notes | |

---

## Appendix A — Minimal violation fixtures (copy-paste)

Save under `/tmp/spvs-fixtures/` for manual `conftest test` runs.

**workflow-violation-spvs2.yml** — missing pipefail:

```yaml
permissions:
  contents: read
jobs:
  bad:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - run: echo no pipefail
```

**composite-violation-spvs5b.yml**:

```yaml
name: Bad
runs:
  using: composite
  steps:
    - uses: ../other-action
```

**workflow-violation-write-all.yml**:

```yaml
permissions: write-all
jobs: {}
```

---

## Appendix B — Policy file map

| File | Responsibility |
|------|----------------|
| `policies/conftest/github_actions/workflow/lib.rego` | Shared regex, `uses_allowed`, `all_steps` |
| `policies/conftest/github_actions/workflow/permissions.rego` | CKV2_GHA_1, SPVS 1, 8, 9, 10, 11, 12, 15 |
| `policies/conftest/github_actions/workflow/steps.rego` | CKV_GHA_1–4, SPVS 2–7, 13, 14, 5, 5B |
| `policies/conftest/github_actions/workflow/workflow_test.rego` | Unit tests |
| `policies/conftest/github_actions/composite/lib.rego` | Composite helpers |
| `policies/conftest/github_actions/composite/steps.rego` | Step-level rules |
| `policies/conftest/github_actions/composite/composite_test.rego` | Unit tests |
| `policies/conftest/github_actions/lib/spvs_skip.rego` | SPVS_SKIP_POLICY skip helpers |
| `policies/scripts/hooks/run_spvs_gha.sh` | Pre-commit entry (Conftest CLI) |
