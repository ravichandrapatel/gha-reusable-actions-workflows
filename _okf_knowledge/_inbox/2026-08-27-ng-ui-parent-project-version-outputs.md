# Change close-out write-back: ng-ui-parent-project-version-outputs

**Evidence grade:** verified (Conftest workflow 52/52)
**Suggested destination:** vault/systems/gha-reusable-actions-workflows.md (ng-ui pipeline outputs) | MAINTAIN later

## What shipped / learned
- ng-ui `build-preprocess` job did not export `parent_version` / `project_version`, so docker-build received empty `project_version`.
- Job + `workflow_call` outputs now match Maven: `project_version` = `package.json` version; `parent_version` = `@test/components` (docker still falls back to `application_version` when that dep is absent).
