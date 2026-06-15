# Dummy Reusable Workflow

Minimal **reusable workflow** used as the SPVS reference implementation and Release Manager test fixture. Echoes a caller-provided message.

## Overview & context

- **Purpose**: Demonstrate a compliant `workflow_call` workflow and validate release/sync behavior.
- **Scope**: Single job, read-only permissions, one optional input.
- **Primary users**: Platform engineers testing Release Manager; authors learning workflow conventions.
- **Success criteria**: Caller receives echoed message in job logs; passes all Checkov SPVS policies.

## Metadata dashboard

| Attribute | Value |
| --- | --- |
| **Owner / Lead** | DevOps Team |
| **Service Status** | Production (reference) |
| **Repository / Code** | `workflows/common/dummy-workflow` |
| **Dependencies** | None (bash only) |
| **Slack / Support** | Platform / DevOps |

## What it does

- Accepts optional `message` input (default: `Hello from Dummy Workflow`).
- Runs one job on `ubuntu-latest` with `contents: read`.
- Echoes the message using env-mapped input (SPVS-compliant pattern).

## Inputs (`workflow_call`)

| Input | Required | Default | Description |
| --- | --- | --- | --- |
| `message` | No | `Hello from Dummy Workflow` | Text echoed by the workflow. |

## Usage examples

### Call from another workflow (same org)

```yaml
jobs:
  demo:
    uses: my-org/gha-reusable-actions-workflows/.github/workflows/dummy-workflow.yml@v1
    with:
      message: "Smoke test from caller repo"
```

### Call from this monorepo (path reference)

```yaml
jobs:
  demo:
    uses: ./.github/workflows/dummy-workflow.yml
    with:
      message: "Local integration test"
```

## Release layout

| Location | Role |
| --- | --- |
| `workflows/common/dummy-workflow/workflow.yml` | **Source** (authoring) |
| `workflows/common/dummy-workflow/readme.md` | Usage documentation |
| `.github/workflows/dummy-workflow.yml` | **Synced copy** after Release Manager `mode: release` |

Tags: `dummy-workflow-1.0.0` (versioned), `dummy-workflow-v1` (stable).

## Requirements

- Callers need `contents: read` (or broader) to reference the reusable workflow.
- No secrets or special runners required.
