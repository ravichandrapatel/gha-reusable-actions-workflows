# maven-build-pipeline

Reusable workflow (`on: workflow_call`) for Maven applications — **maven-ui** (jsb-ui, jcr-ui, jsts-ui) and **maven-svc** (jsb-svc, jcr-svc, jsts-svc). Modeled on [`ng-ui-build-pipeline`](../ng-ui-build-pipeline/readme.md).

## Overview & context

- **Purpose**: Shared Maven CI — preprocess → build/test → OWASP → Sonar → Nexus deploy and/or S2I docker.
- **Scope**: `app_build_type` is always `maven`. Uses house [`maven`](../../actions/common/maven/readme.md) action and [`s2i-build-and-push`](../../actions/common/s2i-build-and-push/readme.md) for container images.
- **Primary users**: JVM apps with `pom.xml`, `project.values`, and `build.values`.
- **Success criteria**: Jobs honor preprocess booleans (`build_and_unit_test` / `owasp` / `sonar` / `snapshot_artifact` / `release_artifact` / `docker`). Preprocess uses local `./actions/common/build-preprocess`. `checkstyle_skip` appends `-Dcheckstyle.skip=true` when `CPGBUILD_APP_ORIGIN` is set. Optional `lib_01`/`lib_02`/`lib_03` are workflow outputs.

## Metadata dashboard

| Attribute | Value |
| --- | --- |
| **Owner / Lead** | DevOps Team |
| **Service Status** | Draft (initial scaffold) |
| **Repository / Code** | `workflows/programming/maven-build-pipeline` |
| **Dependencies** | build-preprocess, maven, owasp-dependency-check, sonar-scan, docker-login, s2i-build-and-push |

## Jobs / dependency graph

```text
build-preprocess
       │
       ├──────────────────┐
       ▼                  ▼
build-and-unit-test     owasp
  (mvn verify)     (maven-ui / maven-svc profile)
       │                  │
       └────────┬─────────┘
                ▼
           sonarqube
                │
       ├────────┴────────┐
       ▼                 ▼
   publish           docker-build
 (mvn deploy)         (S2I + jar)
```

| Job | Gate |
| --- | --- |
| `build-preprocess` | Inventory + branch allowlist; `app_build_type: maven` |
| `build-and-unit-test` | `./actions/common/maven` with `maven_build_args` (default `clean verify -DskipTests`) |
| `owasp` | House OWASP action; profile `maven-ui` or `maven-svc` (auto from `application_name` suffix) |
| `sonarqube` | House `sonar-scan` with `app_build_type: maven` |
| `publish` | `mvn deploy` when `snapshot_artifact` or `release_artifact` |
| `docker-build` | S2I image from built jar when preprocess `docker == true` |

## Maven-ui vs maven-svc

| Archetype | `APPLICATION_NAME` hint | OWASP `scan_profile` |
| --- | --- | --- |
| **maven-ui** | `*-ui` (jsb-ui, jcr-ui, jsts-ui) | `maven-ui` — Jar + Node analyzers |
| **maven-svc** | `*-svc` or other | `maven-svc` — Jar only |

Set `scan_profile: auto` (default) to derive from `application_name`, or pass `maven-ui` / `maven-svc` explicitly.

## Inputs

| Input | Required | Default | Purpose |
| --- | --- | --- | --- |
| `runner` | no | `ubuntu-latest` | Runner label (Podman for OWASP) |
| `bot_name` | no | `""` | Optional auto-commit bot override; `[bot]` actors auto-detected when empty |
| `maven_version` | no | `""` | Optional Apache Maven CLI version; empty auto-detects from `pom.xml` `<maven.version>` |
| `scan_profile` | no | `auto` | OWASP profile |
| `maven_build_args` | no | `clean verify -DskipTests` | Build/test Maven goals |
| `maven_publish_args` | no | `deploy -DskipTests` | Nexus publish goals |
- **Publish:** maven action always writes `$GITHUB_WORKSPACE/maven/settings.xml` from [`settings.xml.tmpl`](../../../actions/common/maven/settings.xml.tmpl) (edit that file for Nexus/jgit `<id>`s). Secrets: `NEXUS_*` + `GIT_TOKEN` (falls back to `github.token`).
| `sonar_host_url` | **yes** | — | SonarQube URL |
| `sonar_project_key` | no | `""` → `application_name` | Sonar project key |
| `sonar_platform` | no | `cap` | Sonar tag |
| `docker_registry` | no | `""` | Required when docker stage runs |
| `docker_environment` | no | `production` | Image path segment |
| `deploy_environment` | no | `ci-publish` | GitHub Environment for publish |

## Secrets

Callers pass **`secrets: inherit`**.

| Secret | Required | Used by |
| --- | --- | --- |
| `SONAR_TOKEN` | **yes** | sonarqube |
| `NVD_API_KEY` | no | owasp (recommended) |
| `NEXUS_USERNAME` / `NEXUS_PASSWORD` | no | publish, docker-build |
| `GIT_TOKEN` | no | publish settings.xml jgit/scm (defaults to `github.token`) |

## Caller requirements

- `project.values`, `build.values`, root `pom.xml` with `artifactId`, `version`, `properties/java.version`
- `BUILDER_BASE_IMAGE` in `build.values` when docker stage runs
- Maven `distributionManagement` / repository `<id>` values in `pom.xml` (used when generating settings for publish)
- Publish generates `settings.xml` from `actions/common/maven/settings.xml.tmpl` (edit server `<id>`s to match your `pom.xml` / jgit config). Job needs `contents: write` for tag push.
- **`bot_name`:** optional override. When empty, preprocess auto-detects actors ending in `[bot]` and skips publish/docker on those runs.
- **`maven_version`:** optional Apache Maven CLI pin. Empty → `pom.xml` `<maven.version>`, else `3.9.9`. Java is always configured with `actions/setup-java` using `java_version` from preprocess.
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
      docker_registry: nexus.example.com
      scan_profile: auto
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

- [ ] PR Sonar job (mirror ng-ui `sonarqube-pr` when PR analysis is needed)
- [ ] Conftest / SPVS policy bundle for this workflow
- [ ] Release Manager tag `maven-build-pipeline/v1.0.0`
