# Retry

Composite action that runs a command until it succeeds, hits `max_attempts`, or a retry filter says stop.

## Overview & context

- **Purpose**: Retry flaky CLI steps with wait, per-attempt timeout, and optional cleanup/replacement commands.
- **Scope**: `bash` or `sh` via `-c`. Timeout `124` matches GNU `timeout`.
- **Success criteria**: Exit 0 if an attempt exits 0; otherwise exit with the last attempt’s code.

## Metadata dashboard

| Attribute | Value |
| --- | --- |
| **Owner / Lead** | DevOps Team |
| **Service Status** | Draft (pre-release) |
| **Repository / Code** | `actions/common/retry` |
| **Dependencies** | bash (or `sh` when `shell: sh`) |

## Inputs

| Input | Required | Default | Description |
| --- | --- | --- | --- |
| `command` | Yes | — | First-attempt command. |
| `max_attempts` | No | `3` | Tries (>= 1). |
| `retry_wait_seconds` | No | `5` | Sleep after a failed attempt, except the last. |
| `timeout_seconds` | No | `0` | Per-attempt timeout in seconds. `0` means none. Do not set with `timeout_minutes`. |
| `timeout_minutes` | No | `0` | Per-attempt timeout in minutes. `0` means none. Do not set with `timeout_seconds`. |
| `polling_interval_seconds` | No | `1` | How often to check whether the command finished or timed out. |
| `warning_on_retry` | No | `true` | Print a warning before each retry. |
| `on_retry_command` | No | `""` | Run after a failed attempt, before the wait. Failure is a warning only. |
| `new_command_on_retry` | No | `""` | Command used for every attempt after the first failure. |
| `retry_on_exit_code` | No | `""` | Comma-separated codes that are retryable. Empty uses `retry_on`. |
| `retry_on` | No | `error` | `error` (non-timeout failures), `timeout`, or `any`. |
| `shell` | No | `bash` | `bash` or `sh`. |

## Outputs

| Output | Description |
| --- | --- |
| `attempts` | How many times the command ran. |
| `exit_code` | Last attempt exit code (`124` on timeout). |
| `succeeded` | `true` when an attempt exited 0. |
| `timed_out` | `true` when the last attempt hit the timeout. |

## Usage

```yaml
- uses: ./actions/common/retry
  with:
    command: npm test
    max_attempts: 3
    retry_wait_seconds: 10
    timeout_seconds: 120
    polling_interval_seconds: 1
    warning_on_retry: true
    on_retry_command: rm -rf .cache
    new_command_on_retry: npm test -- --onlyFailures
    retry_on_exit_code: 1,2
    retry_on: any
    shell: bash
```

## Manual run

```bash
bash actions/common/retry/retry.sh --command 'false' --max-attempts 2 --retry-wait-seconds 0
bash actions/common/retry/retry.sh \
  --command 'sleep 5' \
  --timeout-seconds 1 \
  --polling-interval-seconds 1 \
  --retry-on timeout \
  --max-attempts 2 \
  --retry-wait-seconds 0
```

## Release

Tags after Release Manager: `retry/v1.0.0` (versioned), `retry/v1` (stable, after promote).
