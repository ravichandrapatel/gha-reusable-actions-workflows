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
| `run_tests.sh` | `conftest verify`, full repo `conftest test`, env skip tests |
| `test_conftest_env_skip.sh` | `SPVS_SKIP_POLICY` / `SPVS_SKIP_REASON` — see [Chapter 6](06-inline-policy-skips.md) |
| `test_commit_message_lib.sh` | Ticket validation, commit formats, SemVer classification |

Individual suites:

```bash
bash policies/tests/test_conftest_env_skip.sh
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
| SPVS GHA | `policies/scripts/hooks/run_spvs_gha.sh` → **Conftest CLI** |

### Option B — Conftest CLI (recommended)

Policy paths (always include `lib` for skip helpers):

| Variable | Path |
| :--- | :--- |
| Workflow policies | `policies/conftest/github_actions/workflow` |
| Composite policies | `policies/conftest/github_actions/composite` |
| Shared skip lib | `policies/conftest/github_actions/lib` |

**Full repository scan:**

```bash
bash policies/tests/run_tests.sh
```

**Single workflow:**

```bash
conftest test --parser yaml -n workflow \
  -p policies/conftest/github_actions/workflow \
  -p policies/conftest/github_actions/lib \
  workflows/common/dummy-workflow/workflow.yml
```

**Single composite action** (`action.yml` or `action.yaml`):

```bash
conftest test --parser yaml -n composite \
  -p policies/conftest/github_actions/composite \
  -p policies/conftest/github_actions/lib \
  actions/common/semver/action.yml
```

**Release Manager parity** — same commands as the security job (one component file, correct namespace).

Policy Rego: `policies/conftest/github_actions/{workflow,composite,lib}/`.

### Option C — policy unit tests only

```bash
conftest verify -p policies/conftest/github_actions/workflow \
  -p policies/conftest/github_actions/lib
conftest verify -p policies/conftest/github_actions/composite \
  -p policies/conftest/github_actions/lib
```

See [Chapter 3 — Git hooks](03-dev-hooks.md) for installation.

---

## Test matrix

| You changed… | Run |
| :--- | :--- |
| `commit_message_lib.sh` | `test_commit_message_lib.sh` |
| Rego policies or hooks | `run_tests.sh` |
| `actions/*` or `workflows/*` YAML | `pre-commit run --all-files` or targeted `conftest test` (Option B) |
| `policies/conftest/*` | Full rescan (`pre-commit run --all-files`) |
| Release Manager behavior | [Chapter 5](05-release-checklist.md) |

---

## CI parity

Local hooks approximate Release Manager **Stage 2: Security**:

- **Local:** changed paths only (unless `policies/conftest/` changed).
- **Release:** Conftest CLI on the selected component file only (`mode: release`).
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
