# Change close-out write-back: maven-ng-ui-sync

**Evidence grade:** verified (Conftest workflow 52/52 on maven + ng-ui)
**Suggested destination:** vault/concepts/gha-ci-pipeline-recipe.md | MAINTAIN later

## What shipped / learned

- Shared **caller contract** with ng-ui: required `sonar_host_url`; `SONAR_TOKEN`; `NVD_API_KEY`; docker + Maven deploy use `NEXUS_USERNAME` / `NEXUS_PASSWORD` (not `NEXUS_DOCKER_*` / `NEXUS_ARTIFACT_*`).
- Shared **artifact names** (stable kebab, no repo/run suffix): `maven-target` + `maven-coverage` + `owasp-report` (ng-ui: `ng-ui-dist` + `ng-ui-coverage` + `owasp-report`).
- Shared **job YAML order**: `name` → `needs` → `if` → `runs-on` → `permissions`.
- One `sonarqube` job (branch vs PR args inside the job). Maven still keeps `read-maven-pom` / `sonarqube-gate` / three artifact jobs / `notification-email` — those have no ng-ui twin.
- Authoring source remains `workflows/programming/*/workflow.yml`. `.github/workflows/maven-build-pipeline.yml` is the Release Manager copy and stays stale until release.

## Lookup gap

Pack for “github actions reusable workflow maven ng-ui naming…” returned platform-idp cards, not GHA pipeline-recipe. Promote this note so the next naming pass packs the CI recipe.
