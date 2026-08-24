# Change close-out: release-manager hardening

**Evidence grade:** verified (shellcheck + conftest local)

## What shipped

- `validate` emits `resolved_sha` + `scan_commit`; security checks out `scan_commit` for all modes.
- `promote` / `rollback` now run full security against target versioned-tag commit.
- Execute logic moved to `scripts/release-manager-execute.sh`: retry pull, drift guard, pre-tag pull, peeled stable tags, rollback wf path from tag.
- Semver input validated (`X.Y.Z`, optional `v` prefix stripped).
- Pinned Shellcheck 0.10.0; Bandit excludes tests; `spvs_conftest_run.sh` preserves stderr on tool errors.

**Suggested destination:** already updated `vault/concepts/release-manager-modes.md`.
