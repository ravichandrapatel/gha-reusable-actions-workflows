# maven-build-pipeline

Reusable workflow (`on: workflow_call`) for Maven applications — **maven-ui** (jsb-ui, jcr-ui, jsts-ui) and **maven-svc** (jsb-svc, jcr-svc, jsts-svc). Modeled on [`ng-ui-build-pipeline`](../ng-ui-build-pipeline/readme.md).

## Overview & context

- **Purpose**: Shared Maven CI — preprocess → build/test → OWASP → Sonar → Nexus deploy and/or S2I docker.
- **Scope**: `app_build_type` is always `maven`. Uses house [`maven`](../../actions/common/maven/readme.md) action and [`s2i-build-and-push`](../../actions/common/s2i-build-and-push/readme.md) for container images.
- **Primary users**: JVM apps with `pom.xml`, `project.values`, and `build.values`.
- **Success criteria**: Jobs honor preprocess `stages` / `snapshot_artifact` / `release_artifact` / `docker`.

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
| `java_setup` | no | `auto` | Maven Java selection on self-hosted runners |
| `scan_profile` | no | `auto` | OWASP profile |
| `maven_build_args` | no | `clean verify -DskipTests` | Build/test Maven goals |
| `maven_publish_args` | no | `deploy -DskipTests` | Nexus publish goals |
| `settings_file` | no | `""` | Maven `settings.xml` path (`mvn -s`) |
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

## Caller requirements

- `project.values`, `build.values`, root `pom.xml` with `artifactId`, `version`, `properties/java.version`
- `BUILDER_BASE_IMAGE` in `build.values` when docker stage runs
- Maven `distributionManagement` or `settings.xml` for Nexus publish
- **`bot_name`:** optional override. When empty, preprocess auto-detects actors ending in `[bot]` and skips publish/docker on those runs.
- **`java_setup`:** on self-hosted runners the Maven action selects `JAVA_HOME` from `pom.xml` `java.version`. GitHub-hosted runners use `actions/setup-java` automatically.
- Branch policy: `develop` → snapshot deploy; `workflow_dispatch` on `release/*` / `hotfix/*` → release deploy + docker

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
      settings_file: .mvn/settings.xml
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
- [ ] Caller `.mvn/settings.xml` example for Nexus server credentials
- [ ] Release Manager tag `maven-build-pipeline/v1.0.0`
