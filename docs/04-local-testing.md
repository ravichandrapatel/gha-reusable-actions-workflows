# Chapter 4 — Local Testing

> **Part III — Local development**

This chapter describes how to run **unit tests**, **Conftest SPVS scans**, and **pre-commit hooks** locally before opening a PR or triggering Release Manager.

For Release Manager E2E verification, see [Chapter 5 — Release checklist](05-release-checklist.md).

---

## Quick start

```bash
bash policies/scripts/install_hooks.sh
bash policies/tests/run_tests.sh
pre-commit run --all-files
```

---

## Unit tests (shell)

Policy and hook helpers are tested under `policies/tests/`.

```bash
bash policies/tests/run_tests.sh
```

| Script | Covers |
| :--- | :--- |
| `run_tests.sh` | `conftest verify` (workflow + composite), full repo scan, inline skip tests |
| `test_conftest_inline_skip.sh` | `# spvs:skip=` / `# checkov:skip=` post-filtering |
| `test_commit_message_lib.sh` | Ticket validation, commit formats, SemVer classification |

Individual suites:

```bash
bash policies/tests/test_conftest_inline_skip.sh
bash policies/tests/test_commit_message_lib.sh
```

Unit tests do **not** run Actionlint, Bandit, or Shellcheck against project files (those run via pre-commit).

---

## Security scans (hooks)

### Prerequisites

```bash
bash policies/scripts/install_hooks.sh
command -v pre-commit conftest bandit shellcheck actionlint
```

### Option A — pre-commit framework

```bash
pre-commit run --all-files
```

Hooks (from [`.pre-commit-config.yaml`](../.pre-commit-config.yaml)):

| Hook | Entry |
| :--- | :--- |
| Shellcheck | `shellcheck` |
| Bandit | `bandit` |
| Actionlint | `policies/scripts/hooks/run_actionlint.sh` |
| SPVS GHA | `policies/scripts/hooks/run_spvs_gha.sh` → `conftest-gha.sh` |

### Option B — invoke Conftest directly

Full repository scan (default roots):

```bash
bash policies/scripts/conftest-gha.sh
```

Scan specific paths:

```bash
bash policies/scripts/conftest-gha.sh -d actions/common/semver -d workflows/common/dummy-workflow
```

Low-level Conftest (requires correct namespace):

```bash
conftest test --parser yaml -n workflow \
  -p policies/conftest/github_actions/workflow \
  workflows/common/dummy-workflow/workflow.yml

conftest test --parser yaml -n composite \
  -p policies/conftest/github_actions/composite \
  actions/common/semver/action.yml
```

Policy Rego: `policies/conftest/github_actions/{workflow,composite}/`.

### Option C — policy unit tests only

```bash
conftest verify -p policies/conftest/github_actions/workflow
conftest verify -p policies/conftest/github_actions/composite
```

See [Chapter 3 — Git hooks](03-dev-hooks.md) for installation.

---

## Test matrix

| You changed… | Run |
| :--- | :--- |
| `commit_message_lib.sh` | `test_commit_message_lib.sh` |
| `conftest-gha.sh`, Rego policies | `run_tests.sh` |
| `actions/*` or `workflows/*` YAML | `pre-commit run --all-files` or `conftest-gha.sh -d …` |
| `policies/conftest/*` | Full rescan (`pre-commit run --all-files`) |
| Release Manager behavior | [Chapter 5](05-release-checklist.md) |

---

## CI parity

Local hooks approximate Release Manager **Stage 2: Security**:

- **Local:** changed paths only (unless `policies/conftest/` changed).
- **Release:** full security job on selected component (`mode: release`).
- **Promote:** skips scans (assumes release passed).

---

## Troubleshooting test failures

| Failure | Action |
| :--- | :--- |
| Unit test `FAIL` | Check [commit format](../README.md#commit-message-format) |
| `conftest not found` | `bash policies/scripts/install_hooks.sh` |
| Conftest `CKV2_SPVS_*` / `CKV_GHA_*` | See [README policies](../README.md#security-policies-spvs--conftest) |
| Actionlint / Bandit / Shellcheck | Fix reported file; re-run hook |

Hook install issues: [Chapter 3](03-dev-hooks.md).

---

**Navigation:** ← [Git hooks](03-dev-hooks.md) | [Contents](README.md) | [Next: Release checklist →](05-release-checklist.md)
