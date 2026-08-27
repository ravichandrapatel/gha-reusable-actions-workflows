# Change close-out write-back: maven-remove-github-packages

**Evidence grade:** verified (Conftest workflow 26/26)
**Suggested destination:** vault/systems/gha-reusable-actions-workflows.md | MAINTAIN later

## What shipped / learned
- Removed snapshot `github-packages` job and `publish-to-github-packages` input from `maven-build-pipeline`.
- Maven release still mints a GitHub App token (`github-app-token`) for jgit SCM on `release-artifact` only. Artifact path is Nexus-only: multi-module, Nexus Maven, release.
