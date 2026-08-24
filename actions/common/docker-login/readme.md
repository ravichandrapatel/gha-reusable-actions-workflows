# Docker Login

Composite action that logs in to a container registry with **buildah login**, retried through `actions/common/retry`.

## Overview & context

- **Purpose**: Registry auth for buildah/podman builds. Password is passed on stdin, not on the process command line.
- **Scope**: Requires `buildah` on PATH. Nested retry is `ravichandrapatel/gha-reusable-actions-workflows/actions/common/retry@retry/v1.2.0`. Password stays in env and is piped to `--password-stdin`.
- **Success criteria**: `buildah login` exits 0 within `max_attempts`.

## Metadata dashboard

| Attribute | Value |
| --- | --- |
| **Owner / Lead** | DevOps Team |
| **Service Status** | Draft (pre-release) |
| **Repository / Code** | `actions/common/docker-login` |
| **Dependencies** | bash, `buildah`, `actions/common/retry` |

## Inputs

| Input | Required | Default | Description |
| --- | --- | --- | --- |
| `registry` | Yes | — | Registry host. |
| `username` | Yes | — | Registry username. |
| `password` | Yes | — | Password or token from a secret. |
| `tls_verify` | No | `true` | `true` or `false` for `buildah --tls-verify`. |
| `max_attempts` | No | `3` | Login retries. |
| `retry_wait_seconds` | No | `5` | Wait between failed attempts. |
| `timeout_seconds` | No | `60` | Per-attempt timeout; `0` disables. |

## Outputs

| Output | Description |
| --- | --- |
| `attempts` | Login attempts run. |
| `exit_code` | Last attempt exit code. |
| `succeeded` | `true` when login succeeded. |
| `timed_out` | `true` when the last attempt timed out. |

## Usage

```yaml
- uses: ravichandrapatel/gha-reusable-actions-workflows/actions/common/docker-login@docker-login/v1.2.0
  with:
    registry: ${{ vars.REGISTRY_HOST }}
    username: ${{ secrets.REGISTRY_USERNAME }}
    password: ${{ secrets.REGISTRY_PASSWORD }}
    tls_verify: true
    max_attempts: 5
    retry_wait_seconds: 10
    timeout_seconds: 60
```

Password is never a CLI flag. Do not enable `set -x`.

## Release

Tags after Release Manager: `docker-login/v1.0.0` (versioned), `docker-login/v1` (stable, after promote).
