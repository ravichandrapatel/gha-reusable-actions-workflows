# maven-build-pipeline

Reusable workflow (`on: workflow_call`) for Maven applications — **maven-ui** (jsb-ui, jcr-ui, jsts-ui) and **maven-svc** (jsb-svc, jcr-svc, jsts-svc). Modeled on [`ng-ui-build-pipeline`](../ng-ui-build-pipeline/readme.md).

## Overview & context

- **Purpose**: Shared Maven CI — preprocess → build/test → OWASP → Sonar → POM/gate → artifacts (multi-module, release, Nexus Maven) → S2I image → email.
- **Scope**: `app_build_type` is always `maven`. Uses house [`maven`](../../actions/common/maven/readme.md) action and [`s2i-build-and-push`](../../actions/common/s2i-build-and-push/readme.md) for container images.
- **Primary users**: JVM apps with `pom.xml`, `project.values`, and `build.values`.
- **Success criteria**: Jobs honor preprocess booleans (`build_and_unit_test` / `owasp` / `sonar` / `snapshot_artifact` / `release_artifact` / `docker`). Preprocess uses local `./actions/common/build-preprocess`. `checkstyle_skip` appends `-Dcheckstyle.skip=true` when `CPGBUILD_APP_ORIGIN` is set. Optional `lib_01`/`lib_02`/`lib_03` are workflow outputs.

## Metadata dashboard

| Attribute | Value |
| --- | --- |
| **Owner / Lead** | DevOps Team |
| **Service Status** | Draft (initial scaffold) |
| **Repository / Code** | `workflows/programming/maven-build-pipeline` |
| **Dependencies** | build-preprocess (nests check-inventory/v1), maven, owasp-dependency-check, read-maven-pom, docker-login, s2i-build-and-push, notification-email |

## Jobs / dependency graph

```text
build-preprocess
       │
       ├──────────────────┐
       ▼                  ▼
build-and-unit-test     owasp
       │                  │
       └────────┬─────────┘
                ▼
        sonarqube
                │
                ▼
         read-maven-pom
                │
                ▼
           sonarqube-gate
                │
    ┌───────────┼───────────┐
    ▼           ▼           ▼
multi-module  release   nexus-maven
 artifacts   artifact   artifacts
    └───────────┬───────────┘
                ▼
           docker-build
                │
                ▼
        notification-email
```

| Job | Gate |
| --- | --- |
| `build-preprocess` | Nested `check-inventory@check-inventory/v1`, then branch allowlist; `app_build_type: maven` |
| `build-and-unit-test` | `./actions/common/maven` `clean verify` + coverage profile; uploads `maven-target` and `maven-coverage` |
| `owasp` | House OWASP action; `scan_profile: maven`; uploads `owasp-report` |
| `sonarqube` | Maven `sonar:sonar` (branch or PR, same as ng-ui); uploads `sonar-report-task` |
| `read-maven-pom` | `./actions/common/read-maven-pom` after Sonar; emits `version` / `packaging` / GAV |
| `sonarqube-gate` | Official quality-gate action using the uploaded report-task |
| `multi-module-artifacts` | Snapshot `mvn deploy` when `is_multi_module` is true |
| `nexus-maven-artifacts` | Single-module snapshot `deploy:deploy-file`; version/packaging from `read-maven-pom` |
| `release-artifact` | Maven release plugin to Nexus when `release_artifact` |
| `docker-build` | S2I after the three artifact jobs; `project_version` from `read-maven-pom` |
| `notification-email` | House `notification-email` with `if: always()` (skip with `skip_notification`) |

## Maven-ui vs maven-svc

App archetype (`*-ui` vs `*-svc`) lives in `application_name`. The pipeline always calls OWASP with `scan_profile: maven`.

## Inputs

| Input | Required | Default | Purpose |
| --- | --- | --- | --- |
| `runner` | no | `ubuntu-latest` | Runner label (Podman for OWASP) |
| `bot_name` | no | `""` | Optional auto-commit bot override; `[bot]` actors auto-detected when empty |
| `sonar_host_url` | **yes** | — | SonarQube URL (same required input as ng-ui) |
| `sonar_project_key` | no | `""` → `application_name` | Sonar project key |
| `sonar_platform` | no | `cap` | Caller parity with ng-ui (`sonar-scan` tags; Maven `sonar:sonar` does not apply API tags) |
| `skip_sonar` | no | `false` | Skip Sonar scan and quality gate |
| `skip_owasp` | no | `false` | Skip OWASP |
| `skip_quality_gate_check` | no | `false` | Skip `sonarqube-gate` |
| `skip_notification` | no | `false` | Skip the final `notification-email` job |
| `build_artifact_retention_days` | no | `1` | Retention for `maven-target` |
| `coverage_report_retention_days` | no | `1` | Retention for `maven-coverage` |
| `owasp_report_retention_days` | no | `30` | Retention for `owasp-report` |
| `deploy_environment` | no | `ci-publish` | **GitHub Environment** on `release-artifact` |

## Secrets

Callers pass **`secrets: inherit`**.

| Secret / var | Required | Used by |
| --- | --- | --- |
| `SONAR_TOKEN` | **yes** (when Sonar runs) | sonarqube / sonarqube-gate |
| `NVD_API_KEY` | no | owasp |
| `NEXUS_USERNAME` / `NEXUS_PASSWORD` | no | artifact jobs + docker-build |
| `vars.NEXUS_HOST_URL` | no | Nexus deploy URL |
| `vars.NEXUS_DOCKER_REGISTRY_DEV` | no | docker-build / OWASP image |
| `SMTP_HOST` / `SMTP_USERNAME` / `SMTP_PASSWORD` / `SMTP_FROM` | no | notification-email |
| `ORG_READ_TOKEN` | no | notification-email team expand (`read:org`); falls back to `github.token` |
| `vars.NOTIFICATION_EMAIL_DOMAIN` | no | `{login}@{domain}` fallback |

## Artifact flow

1. Build uploads `maven-target` from `target/` and `maven-coverage` from `target/site/`.
2. OWASP uploads `owasp-report` (HTML + XML under `target/`).
3. Sonar downloads `maven-target` and `owasp-report`, then uploads `sonar-report-task`.
4. Docker downloads `maven-target` (no rebuild).

## Caller requirements

- `project.values`, `build.values`, root `pom.xml` with `artifactId`, `version`, `properties/java.version`
- `BUILDER_BASE_IMAGE` in `build.values` when docker stage runs
- Maven `distributionManagement` / repository `<id>` values in `pom.xml` (used when generating settings for publish)
- Publish generates `settings.xml` from `actions/common/maven/settings.xml.tmpl` (edit server `<id>`s to match your `pom.xml` / jgit config). Job needs `contents: write` for tag push.
- **`bot_name`:** optional override. When empty, preprocess auto-detects actors ending in `[bot]` and skips publish/docker on those runs.
- Branch policy: `develop` push → snapshot + docker; `release/*` / `hotfix/*` push or dispatch → release artifact + docker

## Usage

```yaml
name: app-ci

on:
  push:
    branches: [develop]
  workflow_dispatch:

jobs:
  pipeline:
    uses: ravichandrapatel/gha-reusable-actions-workflows/.github/workflows/maven-build-pipeline.yml@<sha>
    with:
      sonar_host_url: https://sonar.example.com
      runner: arc-podman
    secrets: inherit
```

## Release layout

| Location | Role |
| --- | --- |
| `workflows/programming/maven-build-pipeline/workflow.yml` | **Source** |
| `workflows/programming/maven-build-pipeline/readme.md` | This file |
| `.github/workflows/maven-build-pipeline.yml` | **Synced copy** after Release Manager `mode: release` |

## TODO / follow-ups

- [ ] Conftest / SPVS policy bundle for this workflow
- [ ] Release Manager tag `maven-build-pipeline/v1.0.0`
