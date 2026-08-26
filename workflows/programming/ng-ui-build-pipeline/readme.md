# ng-ui-build-pipeline

Reusable workflow (`on: workflow_call`) for Angular/ng-ui apps. Preprocess emits stages; later jobs run only when those outputs say so.

## Overview & context

- **Purpose**: Shared ng-ui CI — preprocess → lint/test/build → OWASP → Sonar (branch or PR) → semantic-release and/or docker.
- **Scope**: `app_build_type` is always `ng-ui`. No email notification.
- **Primary users**: ng-ui application repositories in the org.
- **Success criteria**: Jobs honor preprocess booleans (`build_and_unit_test` / `owasp` / `sonar` / `snapshot_artifact` / `release_artifact` / `docker`); SPVS Conftest passes. Preprocess uses local `./actions/common/build-preprocess`; optional `lib_01`/`lib_02`/`lib_03` and `checkstyle_skip` are workflow outputs.

## Metadata dashboard

| Attribute | Value |
| --- | --- |
| **Owner / Lead** | DevOps Team |
| **Service Status** | Draft (pre-release) |
| **Repository / Code** | `workflows/programming/ng-ui-build-pipeline` |
| **Dependencies** | House composites: build-preprocess, owasp-dependency-check, sonar-scan, docker-login, docker-build-and-push |
| **Slack / Support** | Platform / DevOps |

## Jobs / dependency graph

```text
build-preprocess
       │
       ▼
build-and-unit-test-lint   if build_and_unit_test == true
       │  uploads ng-ui-dist (+ ng-ui-coverage when lcov exists)
       ▼
     owasp                 if stages contains owasp
       │  uploads owasp-report (format ALL → reports/)
       ├──────────────────┐
       ▼                  ▼
  sonarqube          sonarqube-pr
  (not PR)           (pull_request)
       │                  │
       └────────┬─────────┘
                ├──────────────► publish     if snapshot_artifact or release_artifact
                └──────────────► docker-build if docker == true
```

| Job | Gate |
| --- | --- |
| `build-preprocess` | Inventory + branch allowlist; `app_build_type: ng-ui` |
| `build-and-unit-test-lint` | `npm ci`, `npm run lint`, `npm test`, `npm run build` |
| `owasp` | House OWASP action; `out: reports` |
| `sonarqube` | Branch analysis via house `sonar-scan` |
| `sonarqube-pr` | PR analysis (`pr_key` / `pr_branch` / `pr_base`) |
| `publish` | `npx --no-install semantic-release` after quality gate |
| `docker-build` | House docker-login + docker-build-and-push after quality gate |

**Publish:** caller owns `.releaserc` / `release.config.js` (prerelease on `develop`, release on `release/*` and `hotfix/*`). Preprocess sets `snapshot_artifact` on develop (non-PR) and `release_artifact` on `push` or `workflow_dispatch` of `release/*` or `hotfix/*`. semantic-release must be in the caller `package.json` (no floating `npx` latest).

**Docker:** enabled on `push` or `workflow_dispatch` (not PRs / libraries). `project_version` is the ng-ui `application_version` (package.json). Requires `docker_registry` plus `NEXUS_USERNAME` / `NEXUS_PASSWORD`.

## Inputs

| Input | Required | Default | Purpose |
| --- | --- | --- | --- |
| `runner` | no | `ubuntu-latest` | Runner label (Podman required for OWASP) |
| `bot_name` | no | `""` | Auto-commit actor; other stages skip when it matches |
| `sonar_host_url` | **yes** | — | SonarQube URL |
| `sonar_project_key` | no | `""` → `application_name` | Sonar project key |
| `sonar_platform` | no | `cap` | Tag `platform-<value>` |
| `npm_registry` | no | `""` | Nexus npm registry for `.npmrc` |
| `docker_registry` | no | `""` | Required when the docker stage runs |
| `docker_file` | no | `Dockerfile` | Dockerfile path |
| `docker_context` | no | `""` | Build context (workspace if empty) |
| `deploy_environment` | no | `ci-publish` | GitHub Environment for publish |

## Outputs

| Output | Source |
| --- | --- |
| `stages` | preprocess |
| `application_name` | preprocess |
| `parent_version` | preprocess |
| `quality_gate_status` | sonarqube or sonarqube-pr |
| `docker_image` | docker-build |

## Secrets

Do not declare `workflow_call` secrets. Callers pass **`secrets: inherit`** so org/repo secrets are available automatically.

| Secret | Required | Used by |
| --- | --- | --- |
| `SONAR_TOKEN` | **yes** | sonarqube, sonarqube-pr |
| `NPM_TOKEN` | no | publish (Nexus npm) |
| `NEXUS_USERNAME` / `NEXUS_PASSWORD` | no | docker-build |
| `GH_TOKEN` | no | publish + checkout; falls back to `github.token` |

## Artifact flow

1. Build uploads `ng-ui-dist` from `dist/` and optional `ng-ui-coverage` from `coverage/lcov.info`.
2. OWASP writes `reports/` (HTML + JSON names expected by sonar-scan ng-ui properties) and uploads `owasp-report`.
3. Sonar jobs download coverage and OWASP reports (warn/continue if missing).
4. Docker downloads `ng-ui-dist` into `dist/` (no rebuild).

## Caller requirements

- `project.values`, `build.values`, `package.json` (`version`; `engines.node` or `.nvmrc` for `setup-node`)
- npm scripts: `lint`, `test`, `build`
- `semantic-release` as a dependency when publish runs
- Branch config in the app repo: develop = prerelease; `release/*` and `hotfix/*` = release

House composites are referenced by full repo path and release ref (never a second checkout of this repository):

| Component | `uses` |
| --- | --- |
| build-preprocess | `./actions/common/build-preprocess` |
| owasp-dependency-check | `.../actions/security/owasp-dependency-check@491b152c7dee57a80990de413f445c1fdeac1890` |
| sonar-scan | `.../actions/security/sonar-scan@sonar-scan/v1.2.0` |
| docker-login | `.../actions/common/docker-login@docker-login/v1.2.0` |
| docker-build-and-push | `.../actions/common/docker-build-and-push@docker-build-and-push/v1.4.0` |

Node.js setup uses `./actions/common/resolve-node-version` (YAML anchor `&resolve_node_version_step`) plus `actions/setup-node` (`&setup_node_step`). Preprocess emits the raw range; the action resolves it (for example `>=18.20.0 <22.0.0` → `21`), then `setup-node` installs it.

## Usage

```yaml
name: app-ci

on:
  push:
    branches: [develop, release/**, hotfix/**]
  pull_request:
  workflow_dispatch:

jobs:
  pipeline:
    uses: ravichandrapatel/gha-reusable-actions-workflows/.github/workflows/ng-ui-build-pipeline.yml@<sha>
    with:
      sonar_host_url: https://sonar.example.com
      docker_registry: nexus.example.com
      npm_registry: https://nexus.example.com/repository/npm/
      runner: arc-podman
    secrets: inherit
```

Pin the reusable workflow to a commit SHA (never a floating `@vN` tag). After Release Manager `mode: release`, the synced copy is `.github/workflows/ng-ui-build-pipeline.yml`.

## Release layout

| Location | Role |
| --- | --- |
| `workflows/programming/ng-ui-build-pipeline/workflow.yml` | **Source** |
| `workflows/programming/ng-ui-build-pipeline/readme.md` | Usage documentation |
| `.github/workflows/ng-ui-build-pipeline.yml` | **Synced copy** after Release Manager `mode: release` |

Tags after Release Manager: `ng-ui-build-pipeline/v1.0.0` (versioned), `ng-ui-build-pipeline/v1` (stable, after promote).
