# Change close-out write-back: maven-artifacts-then-image-then-notify

**Evidence grade:** verified (Conftest workflow 26/26)
**Suggested destination:** vault/systems/gha-reusable-actions-workflows.md | MAINTAIN later

## What shipped / learned
- Maven pipeline artifact jobs after `sonar-gate`: `multi-module-artifacts` (`mvn deploy` when `is_multi_module`), `nexus-maven-artifacts` (single-module `deploy:deploy-file`), `release-artifact` (Maven release plugin to Nexus).
- `image-build` waits for those three (`success || skipped`), then `notification-email` (`if: always()`, skip via `skip-notification`).
- Optional `github-packages` remains for single-module snapshots only; not on the image critical path.
