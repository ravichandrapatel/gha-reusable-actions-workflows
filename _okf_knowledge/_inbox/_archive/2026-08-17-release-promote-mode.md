# Change close-out write-back: release-promote-mode

**Evidence grade:** provided
**Suggested destination:** vault/concepts/release-manager-modes.md (ingested this turn)

## What shipped / learned
- New Release Manager `mode: release-promote` — full security, versioned `{safe_name}/v{X.Y.Z}`, then stable `{safe_name}/v1` in one run.
- Execute environment is `production` (stable tag mutation); `release` alone stays `sandbox`.
