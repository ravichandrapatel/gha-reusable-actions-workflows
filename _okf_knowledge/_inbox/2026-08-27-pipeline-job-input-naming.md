# Change close-out write-back: pipeline-job-input-naming

**Evidence grade:** verified (Conftest workflow 52/52 on maven + ng-ui)
**Suggested destination:** vault/concepts/gha-ci-pipeline-recipe.md | MAINTAIN later

## What shipped / learned
- Shared naming: job id = `name:` kebab-case; workflow_call inputs snake_case (`runner`, `bot_name`, `deploy_environment`, `skip_*`); preprocess `build_stages` tokens stay snake_case (`build_and_unit_test`, `owasp`, `sonar`, `docker`, …).
- Maven aligned to ng-ui: `build-and-unit-test`, `owasp`, `sonarqube` / `sonarqube-pr`, `sonarqube-gate`, `docker-build`; `runs-on` JSON input → `runner`.
- ng-ui job `build-and-unit-test-lint` renamed to `build-and-unit-test` (lint still runs inside the job).
