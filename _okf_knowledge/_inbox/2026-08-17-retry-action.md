# Change close-out write-back: retry-action

**Evidence grade:** verified
**Suggested destination:** vault/systems/gha-reusable-actions-workflows.md (list retry under actions) | MAINTAIN later

## What shipped / learned
- `actions/common/retry` is bash-only (`retry.sh`). `shell` input is `bash` or `sh`. Python helper removed.
- Retries `--command` via `bash -c` / `sh -c`. Defaults: 3 attempts, 5s delay between failures.
- Outputs: `attempts`, `exit_code`, `succeeded`, `timed_out`.
- Inputs: `retry_wait_seconds`, `timeout_seconds`/`timeout_minutes` (xor), `polling_interval_seconds`, `warning_on_retry`, `on_retry_command`, `new_command_on_retry`, `retry_on_exit_code`, `retry_on`, `shell`.
- `on_retry_command` must not clobber the failed attempt’s exit code.
