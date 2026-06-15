# Chapter 4 — Local Testing

> **Part III — Local development**

This chapter describes how to run **unit tests**, **hook/security scans**, and **Checkov staging** locally before opening a PR or triggering Release Manager.

For Release Manager E2E verification, see [Chapter 5 — Release checklist](05-release-checklist.md).

---

## Quick start

```bash
bash policies/scripts/install_dev_hooks.sh
source .env
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
| `test_pre_commit_spvs.sh` | Path resolution, policy-change detection, YAML/repo workflow detection |
| `test_commit_message_lib.sh` | Ticket validation, commit formats, SemVer classification |

Individual suites:

```bash
bash policies/tests/test_commit_message_lib.sh
bash policies/tests/test_pre_commit_spvs.sh
```

Unit tests do **not** run Checkov, Actionlint, Bandit, or Shellcheck against project files.

---

## Security scans (hooks)

### Prerequisites

```bash
source .env
command -v pre-commit checkov bandit shellcheck actionlint yq
```

### Option A — pre-commit framework

```bash
pre-commit run --all-files
```

### Option B — invoke scripts directly

```bash
mapfile -d '' -t STAGED < <(git diff --cached --name-only -z --diff-filter=ACMR)
bash policies/scripts/pre_commit_spvs_wrapper.sh "${STAGED[@]}"

SPVS_HOOK_VERBOSE=1 bash policies/scripts/pre_commit_spvs_wrapper.sh policies/scripts/pre_commit_spvs.sh
SPVS_HOOK_SKIP_CHECKOV=1 bash policies/scripts/pre_commit_spvs_wrapper.sh policies/scripts/stage_component.sh
```

### Option C — real commit

```bash
git commit -m "DCDT-1234 test(hooks): verify local hook pipeline"
```

See [Chapter 3 — Git hooks](03-dev-hooks.md) for installation.

---

## Checkov staging and cache

### Stage a component (shell)

```bash
STAGING=$(mktemp -d)
bash policies/scripts/stage_component.sh \
  --component-path actions/common/semver \
  --staging-root "${STAGING}"
```

With repo workflows:

```bash
bash policies/scripts/stage_component.sh \
  --component-path actions/common/semver \
  --staging-root "${STAGING}" \
  --include-repo-workflows
```

### Stage a component (Python — used in CI)

```bash
python3 policies/scripts/stage_component.py \
  --component-path actions/common/semver \
  --staging-root /tmp/checkov-stage \
  --include-repo-workflows
```

### Run Checkov manually

```bash
source .env
export CKV_CACHE_DIR="${PWD}/.checkov.cache/ckv"
mkdir -p "${CKV_CACHE_DIR}"

checkov -d "${STAGING}" \
  --config-file .checkov.yaml \
  --framework github_actions
```

Policies: `policies/github_actions/*.yaml`. Config: [`.checkov.yaml`](../.checkov.yaml).

### Refresh Checkov cache

```bash
bash policies/scripts/update_checkov_cache.sh \
  --component-path actions/common/semver \
  --include-repo-workflows
```

---

## Test matrix

| You changed… | Run |
| :--- | :--- |
| `commit_message_lib.sh` | `test_commit_message_lib.sh` |
| `pre_commit_spvs.sh`, staging scripts | `run_tests.sh` + hook scan |
| `actions/*` or `workflows/*` YAML | `pre-commit run --all-files` |
| `policies/github_actions/*` or `.checkov.yaml` | Full rescan (`pre-commit run --all-files`) |
| Release Manager behavior | [Chapter 5](05-release-checklist.md) |

---

## CI parity

Local hooks approximate Release Manager **Stage 2: Security**:

- **Local:** changed paths only (unless policies/config changed).
- **Release:** full security job on selected component (`mode: release`).
- **Promote:** skips scans (assumes release passed).

---

## Troubleshooting test failures

| Failure | Action |
| :--- | :--- |
| Unit test `FAIL` | Check [commit format](../README.md#commit-message-format) |
| `Required command not found` | `source .env`; re-run installer |
| Checkov `CKV2_SPVS_*` | See [README policies](../README.md#security-policies-spvs--checkov) |
| Actionlint / Bandit / Shellcheck | Fix reported file; re-run hook |

Hook install issues: [Chapter 3](03-dev-hooks.md).

---

**Navigation:** ← [Git hooks](03-dev-hooks.md) | [Contents](README.md) | [Next: Release checklist →](05-release-checklist.md)
