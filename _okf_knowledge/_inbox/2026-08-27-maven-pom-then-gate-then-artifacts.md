# Change close-out write-back: maven-pom-then-gate-then-artifacts

**Evidence grade:** verified (Conftest workflow 26/26)
**Suggested destination:** vault/systems/gha-reusable-actions-workflows.md | MAINTAIN later

## What shipped / learned
- Maven pipeline job order after scan: `read-maven-pom` → `sonar-gate` → artifacts.
- Quality gate moved out of `sonar` / `sonar-pr` (those upload `report-task.txt`; gate job polls it).
- Snapshot file lookup and image `project_version` use `read-maven-pom` `version` + `packaging` only (not preprocess `project_version`). File glob also matches `*-${version}-SNAPSHOT.*`.
