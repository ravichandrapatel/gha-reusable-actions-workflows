# Change close-out write-back: maven-drop-github-packages-release

**Evidence grade:** verified (Conftest workflow scan)
**Suggested destination:** vault/systems/gha-reusable-actions-workflows.md | MAINTAIN later

## What shipped / learned
- Removed `release-github-packages` from `maven-build-pipeline`. Snapshot `github-packages` (gated by `publish-to-github-packages`) and Nexus `release-nexus-artifacts` remain. Nexus release still uses the App token for jgit SCM.
