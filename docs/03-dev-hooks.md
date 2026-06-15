# Chapter 3 — Local Git Hooks

> **Part III — Local development**

This chapter covers installing and using the repository’s **pre-commit** and **commit-msg** hooks. They align with **OWASP SPVS** and run the same class of checks as the Release Manager security stage (Checkov, Actionlint, Bandit, Shellcheck).

---

## What the hooks do

| Hook | When it runs | What it checks |
| :--- | :--- | :--- |
| **pre-commit** | Before `git commit` completes | SPVS security scans on staged files |
| **commit-msg** | After you write the message | Ticket prefix + conventional commit keyword |

### Pre-commit scans (`pre_commit_spvs.sh`)

Scans are **scoped to what you changed**, except when policy or Checkov config changes trigger a full rescan.

| Tool | Targets |
| :--- | :--- |
| **Checkov** | `actions/*/*` and `workflows/*/*` YAML changes; `.github/workflows/` when those files change |
| **Shellcheck** | Changed `*.sh` files |
| **Actionlint** | Changed workflow YAML |
| **Bandit** | Changed `*.py` files |

Commit message rules: [README — Commit Message Format](../README.md#commit-message-format).

---

## Prerequisites

1. **Python 3.12+** with `venv` support (or **pipx**).
2. **Global** git hooks directory (required by the default installer):

   ```bash
   git config --global core.hooksPath ~/.git-global-compliance/hooks
   mkdir -p ~/.git-global-compliance/hooks
   ```

3. **Optional system packages** (installed automatically when possible): `shellcheck`, `actionlint`, `yq`.

---

## Installation

From the repository root:

```bash
bash policies/scripts/install_dev_hooks.sh
source .env
```

The installer:

1. Creates `.venv/` (default) and installs `pre-commit`, `checkov`, `bandit`.
2. Installs or caches **shellcheck**, **actionlint**, and **yq** (unless skipped).
3. Writes **`.env`** with `PATH` and SPVS variables.
4. Updates **global** `core.hooksPath` hooks for repos that contain `policies/scripts/`.

### Install options

| Option | Purpose |
| :--- | :--- |
| `--mode venv` | Use `.venv/` (default) |
| `--mode pipx` | Install Python CLIs with pipx |
| `--skip-system` | Skip shellcheck / actionlint / yq installation |
| `--skip-hooks` | Tools and `.env` only; skip global hook install |

---

## Daily usage

### 1. Load the environment

```bash
source .env
```

### 2. Stage and commit

```bash
git add actions/common/semver/action.yml
git commit -m "DCDT-1234 feat(release): add semver bump helper"
```

Valid subject examples:

```text
DCDT-1234 feat(scope): add hook
SCTASK99: fix(janitor) correct path
INC42: feat() add capability
DCDT-1234 fix(): resolve null pointer
```

### 3. Fix failures and retry

Read tool output, fix the issue, re-stage, and commit again.

---

## Alternative hook setups

### Repo-local hooks (`.githooks/`)

Sample hooks ship in this repository:

```bash
git config core.hooksPath .githooks
```

These apply **only to this clone** and source `.env` automatically when present.

### pre-commit framework

```bash
source .env
pre-commit install --hook-type pre-commit --hook-type commit-msg
pre-commit run --all-files
```

Configuration: [`.pre-commit-config.yaml`](../.pre-commit-config.yaml).

---

## Manual runs

```bash
source .env

mapfile -d '' -t STAGED < <(git diff --cached --name-only -z --diff-filter=ACMR)
bash policies/scripts/pre_commit_spvs_wrapper.sh "${STAGED[@]}"

bash policies/scripts/validate_commit_message.sh /path/to/commit-msg-file
```

---

## Environment variables

| Variable | Default | Effect |
| :--- | :--- | :--- |
| `SPVS_HOOK_VERBOSE` | `0` | `1` = verbose output |
| `SPVS_HOOK_SKIP_CHECKOV` | `0` | `1` = skip Checkov only |
| `SPVS_REPO_ROOT` | set by `.env` | Repository root |

```bash
SPVS_HOOK_VERBOSE=1 git commit -m "DCDT-1234 chore: debug hook output"
SPVS_HOOK_SKIP_CHECKOV=1 git commit -m "DCDT-1234 docs: update hook docs"
```

---

## Troubleshooting

| Symptom | Fix |
| :--- | :--- |
| `Global core.hooksPath is not set` | Configure global hooks path, re-run installer |
| `Required command not found` | `source .env` from repo root |
| Checkov fails on composite actions | Ensure **mikefarah/yq** is on PATH |
| Commit message rejected | See [README — Commit format](../README.md#commit-message-format) |

Verification:

```bash
source .env
command -v pre-commit checkov bandit shellcheck actionlint yq
bash policies/tests/run_tests.sh
```

---

**Navigation:** ← [Writing components](02-writing-components.md) | [Contents](README.md) | [Next: Testing →](04-local-testing.md)
