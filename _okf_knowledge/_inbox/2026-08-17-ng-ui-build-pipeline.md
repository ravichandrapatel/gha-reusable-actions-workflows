# Change close-out write-back: ng-ui-build-pipeline

**Evidence grade:** provided
**Suggested destination:** MAINTAIN later — system doc `vault/systems/gha-reusable-actions-workflows.md` should list `workflows/programming/ng-ui-build-pipeline` when ingested.

## What shipped / learned

- Reusable workflow lives at `workflows/programming/ng-ui-build-pipeline/` (category `programming`, not `common`).
- Jobs gated on preprocess outputs: `stages` (build_and_unit_test, owasp, sonar), `snapshot_artifact` / `release_artifact` for `npx --no-install semantic-release`, `docker` for house buildah push.
- No notification-email job.
- Publish is semantic-release (Nexus npm + GitHub), not GitHub Pages. Caller owns `.releaserc` (develop prerelease; release/hotfix release).
- When the caller is not `house_repository`, jobs checkout house at `github.workflow_sha` into `.gha-house` and symlink `actions/` so `./actions/*` and nested `./actions/common/retry` resolve.
- Conftest workflow scan: 26 passed on `workflow.yml`.
