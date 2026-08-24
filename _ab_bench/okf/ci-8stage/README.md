# ci-8stage — Reusable GitHub Actions CI pipeline

Reusable workflow (`on: workflow_call`) with eight stages: preprocess → build once → OWASP → SonarQube → quality gate → Nexus publish → Docker build/push → always-on email notification.

Compliance pins and SPVS rules come from OKF Prompt Cards (not from freestyle `@vN` tags).

## Jobs / dependency graph

```text
build-preprocess
       │
       ▼
build-test-lint  ──uploads──► artifact: <artifact-name>
       │
       ▼
     owasp  ──uploads──► artifact: owasp-report
       │
       ▼
  sonarqube  (downloads build + OWASP; imports OWASP XML into Sonar)
       │
       ▼
sonarqube-gate  ──FAIL blocks publish──┐
       │                               │
       ├──────────────► publish-to-nexus
       │                               │
       └──────────────► docker-build-publish
                                       │
                                       ▼
                         notification-email (if: always())
```

| Job | `needs` | Gate behavior |
| --- | --- | --- |
| `build-preprocess` | — | Inventory / metadata via `./actions/common/build-preprocess` |
| `build-test-lint` | `build-preprocess` | Single build; cache; upload build artifact |
| `owasp` | `build-test-lint` | `./actions/security/owasp-dependency-check`; upload report |
| `sonarqube` | `build-test-lint`, `owasp` | Scan + `sonar.dependencyCheck.xmlReportPath` |
| `sonarqube-gate` | `sonarqube` | Blocks Nexus + Docker on failure |
| `publish-to-nexus` | `sonarqube-gate`, `build-test-lint` | Only if gate `success`; downloads build artifact |
| `docker-build-publish` | `sonarqube-gate`, `build-test-lint` | Only if gate `success`; consumes build artifact |
| `notification-email` | all prior jobs | `if: always()` |

## Inputs

| Input | Required | Default | Purpose |
| --- | --- | --- | --- |
| `java-version` | no | `17` | Cache key dimension |
| `build-command` | no | `./mvnw -B verify` | One-shot build/test/lint |
| `cache-path` | no | `~/.m2/repository` | `actions/cache` paths |
| `cache-key-prefix` | no | `maven` | Cache key prefix |
| `artifact-name` | no | `build-output` | Shared build artifact name |
| `artifact-path` | no | `target` | Upload / download path |
| `owasp-project` | no | `""` → `github.repository` | OWASP project name |
| `owasp-scan-path` | no | `.` | Scan path |
| `owasp-report-dir` | no | `reports/owasp` | OWASP output dir |
| `sonar-project-key` | **yes** | — | Sonar project key |
| `sonar-host-url` | **yes** | — | Sonar server URL |
| `sonar-dependency-check-report` | no | `reports/owasp/dependency-check-report.xml` | XML path imported by Sonar |
| `nexus-url` | **yes** | — | Nexus base URL |
| `nexus-repository` | **yes** | — | Target repository |
| `nexus-artifact-path` | no | `target/*.jar` | Glob under workspace after download |
| `docker-image` | **yes** | — | `registry/org/name` (no tag) |
| `docker-context` | no | `.` | Build context |
| `docker-file` | no | `Dockerfile` | Dockerfile path |
| `docker-tags` | no | `latest` | Single tag appended to image |
| `notification-to` | **yes** | — | Mail recipient |
| `notification-from` | no | `ci-noreply@example.com` | Mail sender |
| `deploy-environment` | no | `ci-publish` | GitHub Environment for write jobs |
| `runner` | no | `ubuntu-latest` | Runner label (Podman required for OWASP) |
| `app-repo` | no | `""` → `github.repository` | Preprocess inventory id |
| `app-build-type` | no | `maven-java` | Preprocess build type |

## Outputs

| Output | Source |
| --- | --- |
| `build-artifact-name` | `build-test-lint` |
| `sonar-quality-gate` | `sonarqube-gate` |
| `nexus-publish-url` | `publish-to-nexus` |
| `docker-digest` | `docker-build-publish` |

## Secrets

| Secret | Used by |
| --- | --- |
| `SONAR_TOKEN` | `sonarqube`, `sonarqube-gate` |
| `NEXUS_USERNAME` / `NEXUS_PASSWORD` | `publish-to-nexus` |
| `DOCKER_USERNAME` / `DOCKER_PASSWORD` | `docker-build-publish` |
| `SMTP_HOST` / `SMTP_USERNAME` / `SMTP_PASSWORD` | `notification-email` (`SMTP_HOST` may be `host:port`) |

## Artifact flow

1. **Build once** in `build-test-lint`; upload `<artifact-name>` from `artifact-path`.
2. **OWASP** downloads the build artifact, writes XML under `owasp-report-dir`, uploads `owasp-report`.
3. **SonarQube** downloads build + OWASP artifacts; sets `-Dsonar.dependencyCheck.xmlReportPath` so the OWASP report is imported; uploads `.scannerwork/report-task.txt` as `sonar-scannerwork`.
4. **sonarqube-gate** downloads `sonar-scannerwork` and polls the quality gate (failure blocks Nexus + Docker).
5. **Nexus** and **Docker** download the same build artifact after the quality gate passes (no rebuild).

## Cache strategy

- Action: `actions/cache` (SHA-pinned per Prompt Card catalog).
- Key: `${{ runner.os }}-<cache-key-prefix>-<java-version>-<hashFiles(lock/manifests)>`.
- Restore keys degrade from version-specific → prefix-only so dependency dirs warm across minor lockfile churn.
- Cache is restored only on the build job (build-once model); later jobs consume artifacts, not the toolchain cache.

## Action pins / house composites (from Prompt Cards)

| Use | Ref |
| --- | --- |
| checkout | `actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1` |
| cache | `actions/cache@55cc8345863c7cc4c66a329aec7e433d2d1c52a9 # v6.1.0` |
| upload-artifact | `actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a # v7.0.1` |
| download-artifact | `actions/download-artifact@3e5f45b2cfb9172054b4087a40e8e0b5a5461e7c # v8.0.1` |
| sonarqube-scan | `SonarSource/sonarqube-scan-action@22918119ff8e1ca75a623e15c8296b6ea4fbe28f # v8.2.1` |
| sonarqube-quality-gate | `SonarSource/sonarqube-quality-gate-action@7a5fffe8e523c40e0c740b6bc2712ab503e52efa # v1.2.1` |
| docker/login | `docker/login-action@dbcb813823bdd20940b903addbd779551569679f # v4.6.0` |
| docker/build-push | `docker/build-push-action@53b7df96c91f9c12dcc8a07bcb9ccacbed38856a # v7.3.0` |
| OWASP | `./actions/security/owasp-dependency-check` |
| preprocess | `./actions/common/build-preprocess` |

Nexus publish and email notification use in-job `bash`/`python3` (no `@vN`); catalog had no SHA pins for those actions.

## Usage example

```yaml
name: app-ci

on:
  push:
    branches: [main, develop]
  pull_request:

jobs:
  pipeline:
    uses: org/gha-reusable-actions-workflows/_ab_bench/okf/ci-8stage/workflow.yml@<sha>
    with:
      sonar-project-key: my-app
      sonar-host-url: https://sonar.example.com
      nexus-url: https://nexus.example.com
      nexus-repository: maven-releases
      docker-image: ghcr.io/example/my-app
      notification-to: team@example.com
      build-command: ./mvnw -B verify
      runner: arc-podman
    secrets:
      SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
      NEXUS_USERNAME: ${{ secrets.NEXUS_USERNAME }}
      NEXUS_PASSWORD: ${{ secrets.NEXUS_PASSWORD }}
      DOCKER_USERNAME: ${{ secrets.DOCKER_USERNAME }}
      DOCKER_PASSWORD: ${{ secrets.DOCKER_PASSWORD }}
      SMTP_HOST: ${{ secrets.SMTP_HOST }}
      SMTP_USERNAME: ${{ secrets.SMTP_USERNAME }}
      SMTP_PASSWORD: ${{ secrets.SMTP_PASSWORD }}
```

Pin the reusable workflow itself to a commit SHA (never a floating `@vN` tag).
