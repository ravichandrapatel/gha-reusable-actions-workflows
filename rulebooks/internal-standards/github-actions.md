---
type: internal_standard
tool: github-actions
authority: internal_governance
---

# Internal Standard: GitHub Actions

This document defines the mandatory standards for writing and testing GitHub Actions and workflows within our organization.

## 1. Repository Architecture and Lifecycle

- **Monorepo Structure**: All components live in a single repository:
    - **Composite Actions**: `actions/{category}/{name}/`
    - **Reusable Workflows**: `workflows/{category}/{name}/`
    - **Security Policies**: `policies/conftest/github_actions/`
- **Component Lifecycle**: Develop on `main` → **Release** (versioned tag + security scans) → **Promote** (stable `v1` tag) or **Rollback**.
- **Commit Messages**: All commits must include a **ticket prefix** and **conventional keyword** (e.g., `DCDT-1234 feat: add capability`). This drives versioning and release.

## 2. Writing Actions and Workflows

### 2.1 Naming and Documentation
- **Naming Standards**: Use lowercase **kebab-case** for categories and component names (e.g., `actions/common/prbot`).
- **Mandatory Documentation**: Every action and workflow MUST include a `readme.md` (lowercase) with:
    - Purpose and scope.
    - Metadata (Owner, Status, Dependencies).
    - Inputs and Outputs (documented).
    - Runnable YAML examples.
    - Requirements (tokens, runners).

### 2.2 Security and Permissions
- **Least Privilege**: Every job MUST have an explicit `permissions:` block. Default to `contents: read` at the top level and for each job.
- **Explicit Permissions Only (No Anchors)**: Declare `permissions:` explicitly per job. NEVER use YAML anchors/aliases for `permissions` — schema validation and SPVS-style audits must see the exact scope without resolving references. Anchors are acceptable only for non-security repeated blocks (e.g. checkout steps).
- **Secrets Masking**: If a step generates a sensitive value dynamically, call `echo "::add-mask::$VALUE"` immediately.
- **Untrusted Inputs**: NEVER interpolate `${{ github.event... }}` or `${{ inputs... }}` directly in a `run:` block. Map them to environment variables first.
- **SHA Pinning**: Pin third-party actions by their full **40-character commit SHA**.
- **OIDC**: Use OIDC for cloud deployments (`id-token: write` + cloud login actions) instead of static secrets.
- **Prohibited Patterns**: No `curl | bash` (or `wget | sh`) without checksum verification; no hardcoded tokens/secrets; no workflow-level `permissions: write-all`.

### 2.3 Hardening and Reliability
- **Shell Hardening**: Start every bash `run:` block with `set -euo pipefail`.
- **Timeout**: Always specify a `timeout-minutes` for jobs.
- **Workflow Constraints**: Only one `.yml`/`.yaml` file is allowed per workflow component directory.
- **Write Operations**: Jobs with `permissions.contents: write` must set an `environment:`.

### 2.4 Commit Messages
- Use conventional commits with a ticket prefix (e.g. `DCDT-1234 feat: ...`); this drives versioning/release.
- Do NOT include bot names (e.g. "cursor-bot") in commit messages, and do NOT add tool trailers (e.g. `Made-with: ...`).

> **Policy enforcement:** These rules are automatically verified by Conftest/SPVS policies. See the
> [Conftest Standard](./conftest.md) for the full check catalog and the skip mechanism.

## 3. Testing and Validation

### 3.1 Local Development
- **Git Hooks**: Mandatory use of `pre-commit` hooks. Run `bash policies/scripts/install_hooks.sh` for setup.
- **Security Scans**: Local hooks include **Shellcheck** (shell), **Bandit** (python), **Actionlint** (GHA syntax), and **Conftest** (SPVS policies).
- **Manual Verification**: Run `pre-commit run --all-files` or targeted `conftest test` before opening a PR.

### 3.2 CI Verification
- Every component MUST have a dedicated test workflow in `.github/workflows/` that exercises it end-to-end.
- **Release Manager**: Use the `release-manager.yml` workflow for automated release, promotion, and rollback.

## 4. Policy Exceptions (Skips)

- **Documented Exceptions**: Use policy skips only for reviewed exceptions.
- **Implementation**: Set `SPVS_SKIP_POLICY` (comma-separated IDs) and `SPVS_SKIP_REASON` (justification) in the same `env` block.
- **Rationale**: All skips must be documented in the component's `readme.md`.
