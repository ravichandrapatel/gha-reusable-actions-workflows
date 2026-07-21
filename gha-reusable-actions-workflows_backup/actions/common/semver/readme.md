# Custom SemVer Action

Derives the next **semantic version** from ticket-prefixed conventional commits since the last component tag. Used by Release Manager when `mode: release` and no explicit version is supplied.

## Overview & context

- **Purpose**: Calculate `major.minor.patch` bumps from commit history (`feat` → minor, `fix`/`chore` → patch).
- **Scope**: Composite action; reads git history and `policies/scripts/commit_message_lib.sh`.
- **Primary users**: Release Manager validate stage; reusable in other release pipelines.
- **Success criteria**: Outputs `next_version` or fails when no bump-worthy commits exist since the last tag.

## Metadata dashboard

| Attribute | Value |
| --- | --- |
| **Owner / Lead** | Platform Team |
| **Service Status** | Production |
| **Repository / Code** | `actions/common/semver` |
| **Dependencies** | Git, bash, `commit_message_lib.sh` |
| **Slack / Support** | Platform / DevOps |

## What it does

- Resolves the last versioned tag as `{safe_name}-{current_version}`.
- Collects commits since that tag (or all commits if no tag exists).
- Maps each commit subject through ticket strip + conventional keyword classification.
- Applies highest bump: **minor** beats **patch**; `docs`, `refactor`, `perf`, `test`, `style` do not bump.
- Sets `next_version` to `1.0.0` when `current_version` is `0.0.0`.

## Inputs

| Input | Required | Default | Description |
| --- | --- | --- | --- |
| `current_version` | Yes | — | Current semver (e.g. `1.0.0`). |
| `safe_name` | Yes | — | Component tag prefix (directory basename, e.g. `semver`, `prbot`). |

## Outputs

| Output | Description |
| --- | --- |
| `next_version` | Calculated semver string (e.g. `1.1.0`). |

## Usage examples

### Release Manager (same repo)

```yaml
- name: Calculate Next Version
  id: semver
  uses: ./actions/common/semver
  with:
    current_version: ${{ steps.validate_init.outputs.current_version }}
    safe_name: ${{ steps.validate_init.outputs.safe_name }}
```

### Consumer repository

```yaml
- uses: my-org/gha-reusable-actions-workflows/actions/common/semver@v1
  with:
    current_version: "1.2.3"
    safe_name: "my-component"
```

## Requirements

- **Checkout** with sufficient `fetch-depth` to reach the last tag and intermediate commits.
- **`commit_message_lib.sh`** must exist at `${GITHUB_WORKSPACE}/policies/scripts/commit_message_lib.sh` when run in this monorepo.
- Commit subjects must follow [ticket + conventional keyword](../../../README.md#commit-message-format) rules.
