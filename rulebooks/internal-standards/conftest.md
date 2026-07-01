---
type: internal_standard
tool: conftest
authority: internal_governance
---

# Internal Standard: Conftest (SPVS Policy Checking)

This document defines the mandatory standards for the Conftest/OPA (Rego) policies that enforce
OWASP SPVS-aligned security on our GitHub Actions and composite actions. It is the "Law" for how
policy checks are authored, run, and skipped.

## 1. Intent
- Enforce **artifact integrity, least privilege, and supply-chain safety** on every workflow and
  composite action at author time (pre-commit) and in CI (Release Manager `security` stage).
- Policies live in `policies/conftest/github_actions/` and are the enforcement counterpart to the
  [GitHub Actions Standard](./github-actions.md).

## 2. Policy Structure
- **Packages**: `workflow` (checked with `-n workflow`) and `composite` (checked with `-n composite`).
- **Shared helpers**: `policies/conftest/github_actions/lib/` (`gha_common.rego`, `spvs_skip.rego`).
- **Meta policy**: `skip_meta.rego` enforces that every skip carries a reason (`SPVS_META_1`).
- **Authoring rule**: Every `deny` rule MUST call `lib.policy_active(check_id, scopes)` before
  emitting a failure, so the skip mechanism (Section 4) is honored uniformly.

## 3. Policy Catalog
### 3.1 Permissions & IAM (workflow)
| ID | Rule |
| :--- | :--- |
| `CKV2_SPVS_9` | Workflow must declare explicit top-level `permissions`; must not grant write scopes |
| `CKV2_SPVS_1` | Every job must declare an explicit `permissions` block |
| `CKV2_SPVS_10` | No `write-all` in any `permissions` block (workflow or job) |
| `CKV2_GHA_1` | Top-level `permissions` must not be `write-all` |
| `CKV2_SPVS_11` | Jobs with `contents: write` must declare an `environment` |
| `CKV2_SPVS_8` | Jobs using cloud OIDC actions require `permissions.id-token: write` |
| `CKV2_SPVS_12` | Bare `runs-on: self-hosted` is prohibited |
| `CKV2_SPVS_15` | The `pull_request_target` trigger is prohibited |

### 3.2 Steps, Shell & Supply Chain
| ID | Rule |
| :--- | :--- |
| `CKV2_SPVS_2` | `run:` blocks must include `set -euo pipefail` |
| `CKV2_SPVS_3` | `run:` blocks must not enable `xtrace` (`set -x`) |
| `CKV2_SPVS_4` | Python invocations must use `-u` or `PYTHONUNBUFFERED` |
| `CKV2_SPVS_5` | Actions must be pinned: SHA (40-char), `./`, `docker://`, or internal `/actions/` tag |
| `CKV2_SPVS_5B` | No `../` parent-path local action references |
| `CKV2_SPVS_6` | Map `inputs`/`github.event.inputs` to `env`; never interpolate in `run:` |
| `CKV2_SPVS_7` | No static cloud credentials in `env` (AWS/GCP/Azure keys) |
| `CKV2_SPVS_13` | No `curl`/`wget` piped into a shell |
| `CKV_GHA_1` | Must not set `ACTIONS_ALLOW_UNSECURE_COMMANDS` |
| `CKV_GHA_2` | `run:` must not be vulnerable to shell injection (untrusted `github.event.*`) |
| `CKV_GHA_3` | No suspicious `curl` with secrets on the same line |
| `CKV_GHA_4` | No netcat reverse-shell pattern |

### 3.3 Meta
| ID | Rule |
| :--- | :--- |
| `SPVS_META_1` | When `SPVS_SKIP_POLICY` is set, `SPVS_SKIP_REASON` must be non-empty in the same `env` block |

## 4. Skips (Documented Exceptions Only)
- Skips are enforced **natively in Rego** — Conftest reads `SPVS_SKIP_POLICY` / `SPVS_SKIP_REASON`
  from the parsed YAML `env` block.
- **`SPVS_SKIP_POLICY`**: comma-separated check IDs. **`SPVS_SKIP_REASON`**: non-empty justification
  in the **same** `env` block (required by `SPVS_META_1`).
- **Inheritance**: union across scope chain (workflow → job → step, or composite root → step). If
  any scope lists the ID, the violation is suppressed. `CKV2_SPVS_5`/`CKV2_SPVS_5B` are paired —
  listing either suppresses both.
- **Placement**: prefer **workflow or job `env`**. Do NOT place skip vars on `uses:` steps — they
  leak into the called action.
- **Documentation**: every skip MUST also be documented in the component's `readme.md`.

```yaml
env:
  SPVS_SKIP_POLICY: CKV2_SPVS_11
  SPVS_SKIP_REASON: "internal automation job, no deployable environment; documented in readme.md"
```

## 5. Running Conftest
```bash
# Workflow file
conftest test --parser yaml -n workflow \
  -p policies/conftest/github_actions/workflow \
  -p policies/conftest/github_actions/lib \
  path/to/workflow.yml

# Composite action file
conftest test --parser yaml -n composite \
  -p policies/conftest/github_actions/composite \
  -p policies/conftest/github_actions/lib \
  path/to/action.yml
```
- **Pre-commit**: the `spvs-gha` hook runs these automatically (`bash policies/scripts/install_hooks.sh`).
- **CI**: the Release Manager `security` stage runs the SPVS scan on the released component.

## 6. Testing Policies
- Policy changes MUST keep the Rego unit tests green:
  - `bash policies/tests/run_tests.sh`
  - `bash policies/tests/test_conftest_env_skip.sh`
- Add or update `*_test.rego` cases when introducing or changing a `deny` rule.
