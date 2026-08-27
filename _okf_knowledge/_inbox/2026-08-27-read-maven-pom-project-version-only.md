# Change close-out write-back: read-maven-pom-project-version-only

**Evidence grade:** verified (unittest 7/7)
**Suggested destination:** vault/systems/gha-reusable-actions-workflows.md | MAINTAIN later (supersedes parent-version fallback in 2026-08-27-read-maven-pom-action)

## What shipped / learned
- `version` is the project `<version>` only. Parent `<version>` is never used (missing project version fails).
- Trailing `-SNAPSHOT` is stripped: `1.0.0-SNAPSHOT` → `1.0.0`. `groupId` may still inherit from parent.
