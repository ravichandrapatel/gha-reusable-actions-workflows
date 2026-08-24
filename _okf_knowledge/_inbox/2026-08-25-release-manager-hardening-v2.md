# Change close-out: release-manager v1.13.0 scan/tag alignment

**Evidence grade:** verified (shellcheck, unit tests, conftest 26/26)

## What shipped

- Rollback `scan_commit` = previous versioned tag commit (deploy target), not rollback-from tag.
- `release_manager_assert_release_tag_commit`: actions require HEAD==scan; workflows allow only `.github/workflows/{name}.yml` delta.
- Execute verifies promote/rollback target commit matches `scan_commit` (promote-only; release-promote exempt).
- `component_path` rejects `..`.
- Shared `scripts/release-manager-lib.sh` + `policies/tests/test_release_manager_execute.sh`.
- OKF `release-manager-modes` + `okf compile` prompt card sync.
