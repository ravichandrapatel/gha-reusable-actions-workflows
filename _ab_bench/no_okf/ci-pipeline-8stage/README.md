# CI Pipeline 8-Stage (reusable workflow)

Reusable GitHub Actions workflow (`on: workflow_call`) that builds once, shares artifacts, caches dependencies, runs OWASP Dependency-Check, imports the report into SonarQube, enforces a quality gate before publish, then publishes to Nexus and Docker, and always sends a notification.

**Workflow file:** [`workflow.yml`](./workflow.yml)

## Stages and dependency graph

```text
build-preprocess
       │
       ▼
build-test-lint ─────────────────────────┐
       │                                 │
       ▼                                 │
     owasp                               │
       │                                 │
       ▼                                 │
  sonarqube  (imports OWASP XML/HTML/JSON)
       │                                 │
       ▼                                 │
 sonarqube-gate  (blocks on non-OK)      │
       │                                 │
       ├──────────────┬──────────────────┤
       ▼              ▼                  │
publish-to-nexus   docker-build-publish◄─┘  (downloads build artifacts)
       │              │
       └──────┬───────┘
              ▼
     notification-email  (if: always())
```

| Job | `needs` | Purpose |
|-----|---------|---------|
| `build-preprocess` | — | Metadata, toolchain setup, dependency / OWASP data caches |
| `build-test-lint` | `build-preprocess` | **Single build**, test, optional lint; upload `build-output` |
| `owasp` | `build-preprocess`, `build-test-lint` | Dependency-Check; upload `owasp-dependency-check` |
| `sonarqube` | `build-test-lint`, `owasp` | Sonar scan with OWASP report import |
| `sonarqube-gate` | `sonarqube` | Poll quality gate; **fail blocks publish** |
| `publish-to-nexus` | `build-test-lint`, `sonarqube-gate` | Deploy only after gate OK |
| `docker-build-publish` | `build-preprocess`, `build-test-lint`, `sonarqube-gate` | Image build using downloaded build artifacts |
| `notification-email` | all prior jobs | Summary + optional SMTP; `if: always()` |

## Artifact flow

| Artifact name | Produced by | Consumed by |
|---------------|-------------|-------------|
| `build-output` | `build-test-lint` | `owasp`, `sonarqube`, `publish-to-nexus`, `docker-build-publish` |
| `owasp-dependency-check` | `owasp` | `sonarqube` (XML/HTML/JSON via `sonar.dependencyCheck.*`) |
| `preprocess-meta` | `build-preprocess` | Optional workspace stamp (short retention) |

Build products are staged under `.ci-artifacts/` from `artifact-path`, uploaded once, then downloaded in later jobs so compile/package is not repeated.

Docker places `.ci-artifacts/` inside `docker-context` and passes `BUILD_ARTIFACT_DIR=.ci-artifacts` as a build-arg (Dockerfile should `COPY` from that directory).

## Caching

| Cache | Key material | Jobs |
|-------|--------------|------|
| Maven `~/.m2/repository` | `pom.xml` hash + `cache-key-suffix` | preprocess, build-test-lint |
| Gradle caches/wrapper | Gradle files hash | preprocess, build-test-lint |
| npm `~/.npm` | `package-lock.json` hash | preprocess, build-test-lint |
| OWASP DC data `~/.dependency-check/data` | lock/manifest hashes | preprocess, owasp |
| Docker layer cache | GHA cache backend (`type=gha`) | docker-build-publish |

## Inputs

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `java-version` | no | `17` | JDK for Maven/Gradle/OWASP/Sonar |
| `node-version` | no | `20` | Node for npm/yarn/pnpm |
| `package-manager` | no | `maven` | `maven` \| `gradle` \| `npm` \| `yarn` \| `pnpm` |
| `build-command` | no | `""` | Override build; empty uses toolchain default |
| `test-command` | no | `""` | Override tests |
| `lint-command` | no | `""` | Optional lint (skipped if empty) |
| `artifact-path` | no | `target/*.jar` | Glob(s) copied into build artifact |
| `docker-context` | no | `.` | Docker build context |
| `docker-file` | no | `Dockerfile` | Dockerfile path |
| `docker-image` | **yes** | — | Image name (no registry/tag) |
| `docker-registry` | no | `docker.io` | Registry host |
| `image-tag` | no | `""` → `github.sha` | Image tag |
| `nexus-repository-url` | **yes** | — | Nexus deploy URL |
| `nexus-repository-id` | no | `nexus` | Server id for credentials |
| `sonar-host-url` | **yes** | — | SonarQube URL |
| `sonar-project-key` | **yes** | — | Sonar project key |
| `sonar-sources` | no | `src` | Sources path for scanner |
| `owasp-fail-on-cvss` | no | `11` | DC `--failOnCVSS` (11 ≈ never fail job on CVSS alone) |
| `working-directory` | no | `.` | Project subdirectory |
| `notification-to` | no | `""` | Email recipient (SMTP skipped if empty) |
| `cache-key-suffix` | no | `v1` | Bust/restore cache namespace |

## Secrets

| Secret | Required | Used by |
|--------|----------|---------|
| `SONAR_TOKEN` | yes | `sonarqube`, `sonarqube-gate` |
| `NEXUS_USERNAME` | yes | `publish-to-nexus` |
| `NEXUS_PASSWORD` | yes | `publish-to-nexus` |
| `DOCKER_USERNAME` | yes | `docker-build-publish` |
| `DOCKER_PASSWORD` | yes | `docker-build-publish` |
| `SMTP_HOST` | no | `notification-email` |
| `SMTP_PORT` | no | `notification-email` (default 587) |
| `SMTP_USERNAME` | no | `notification-email` |
| `SMTP_PASSWORD` | no | `notification-email` |
| `SMTP_FROM` | no | `notification-email` |

## Outputs

| Output | Source | Description |
|--------|--------|-------------|
| `build-artifact-name` | `build-test-lint` | Uploaded build artifact name |
| `image-uri` | `docker-build-publish` | Published image URI |
| `sonar-quality-gate` | `sonarqube-gate` | Gate status (`OK`, `ERROR`, …) |
| `pipeline-conclusion` | `notification-email` | `success` or `failure` |

## Quality gate and publish rules

1. `build-test-lint` builds **once** and uploads artifacts.
2. `owasp` scans and uploads Dependency-Check reports.
3. `sonarqube` imports the OWASP XML (and HTML/JSON) via `sonar.dependencyCheck.*`.
4. `sonarqube-gate` polls `/api/qualitygates/project_status`; non-`OK` fails the job.
5. `publish-to-nexus` and `docker-build-publish` both `need` `sonarqube-gate`, so Nexus/Docker run only after the gate passes.
6. `notification-email` uses `if: always()` so it runs on success or failure.

## Usage

Copy `workflow.yml` to e.g. `.github/workflows/ci-pipeline-8stage.yml` in a workflows repository (or call it by path in the same repo).

Caller workflow:

```yaml
name: Application CI

on:
  push:
    branches: [main]
  pull_request:

jobs:
  pipeline:
    uses: ./.github/workflows/ci-pipeline-8stage.yml
    with:
      package-manager: maven
      artifact-path: target/*.jar
      docker-image: my-org/my-service
      docker-registry: registry.example.com
      nexus-repository-url: https://nexus.example.com/repository/maven-releases/
      sonar-host-url: https://sonar.example.com
      sonar-project-key: my-org_my-service
      notification-to: team@example.com
    secrets:
      SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
      NEXUS_USERNAME: ${{ secrets.NEXUS_USERNAME }}
      NEXUS_PASSWORD: ${{ secrets.NEXUS_PASSWORD }}
      DOCKER_USERNAME: ${{ secrets.DOCKER_USERNAME }}
      DOCKER_PASSWORD: ${{ secrets.DOCKER_PASSWORD }}
      SMTP_HOST: ${{ secrets.SMTP_HOST }}
      SMTP_PORT: ${{ secrets.SMTP_PORT }}
      SMTP_USERNAME: ${{ secrets.SMTP_USERNAME }}
      SMTP_PASSWORD: ${{ secrets.SMTP_PASSWORD }}
      SMTP_FROM: ${{ secrets.SMTP_FROM }}
```

### Dockerfile note

Ensure the image build can consume CI artifacts, for example:

```dockerfile
ARG BUILD_ARTIFACT_DIR=.ci-artifacts
COPY ${BUILD_ARTIFACT_DIR}/ /app/
```

### Sonar Dependency-Check plugin

The SonarQube server should have the Dependency-Check plugin (or equivalent) installed so `sonar.dependencyCheck.xmlReportPath` is recognized. Without it, analysis may ignore the OWASP import properties.
