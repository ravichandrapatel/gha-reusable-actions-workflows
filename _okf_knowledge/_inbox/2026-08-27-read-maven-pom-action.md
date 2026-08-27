# Change close-out write-back: read-maven-pom-action

**Evidence grade:** verified (unittest 6/6; Conftest composite 14/14)
**Suggested destination:** vault/systems/gha-reusable-actions-workflows.md (add `actions/common/read-maven-pom`) | MAINTAIN later

## What shipped / learned
- New composite `actions/common/read-maven-pom`: argparse + defusedxml; outputs `group_id`, `artifact_id`, `packaging`, `version`.
- Inheritance: `groupId`/`version` fall back to `<parent>`; `artifactId` is project-only; omitted `<packaging>` defaults to `jar` (Maven spec; matches maven-build-pipeline grep fallback).
- Does not interpolate `${property}` / `${revision}`. Not yet wired into maven-build-pipeline (still greps packaging inline).
