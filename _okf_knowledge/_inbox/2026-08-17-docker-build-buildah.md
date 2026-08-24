# Change close-out write-back: docker-build-and-push

**Evidence grade:** verified
**Suggested destination:** vault/systems/gha-reusable-actions-workflows.md | MAINTAIN later

## What shipped / learned
- Tag: `{YYYYMMDD}-{project_version}-{build:5}-{branch:0:3}-{sha:0:5}-{application_name}-{application_version}`.
- Snapshot is `project_version` from build-preprocess. Application name is `APPLICATION_NAME`. Application version is preprocess `application_version`.
- Build is 5 chars (zero-padded). Branch `[0:3]`. Commit `[0:5]`. No `-build-` token.
- Image: `{nexus}/{organization}/production/{application}:{tag}`.
