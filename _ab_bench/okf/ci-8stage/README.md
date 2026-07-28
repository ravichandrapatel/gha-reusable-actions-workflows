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
| checkout | `actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683` |
| cache | `actions/cache@5a3ec84eff668545956fd18022155c47e93e2684` |
| upload-artifact | `actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02` |
| download-artifact | `actions/download-artifact@95815c38cf2ff2164869cbab79da8d1f422bc89e` |
| sonarqube-scan | `SonarSource/sonarqube-scan-action@7451daf950bc136c497f29045f2b4d4f9f7ba43a` |
| sonarqube-quality-gate | `SonarSource/sonarqube-quality-gate-action@8e9b0ca0a7273d6f16986388d98393efdfcf56fd` |
| docker/login | `docker/login-action@c66a8fcb2472d4283042d726b2a061b43b3f49ab` |
| docker/build-push | `docker/build-push-action@cb941d0b895b09c17fa011d41c411b33c752cf28` |
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
