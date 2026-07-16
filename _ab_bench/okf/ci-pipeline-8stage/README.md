# CI Pipeline 8-Stage (reusable workflow)

Reusable `workflow_call` pipeline that **builds once**, shares artifacts, imports OWASP into SonarQube, blocks publish on quality gate failure, then publishes to Nexus and Docker, and always emails a summary.

## Jobs / dependency graph

```text
build-preprocess
       │
       ▼
build-test-lint  ──uploads──►  artifact: build-output
       │
       ├──────────────────────┐
       ▼                      ▼
     owasp ──uploads──► artifact: owasp-report
       │
       ▼
  sonarqube  (downloads build-output + owasp-report; imports OWASP JSON/HTML/SARIF)
       │
       ▼
 sonarqube-gate  ──fail closes──► blocks Nexus + Docker
       │
       ├──────────────────────┐
       ▼                      ▼
publish-to-nexus      docker-build-publish
       │                      │
       └──────────┬───────────┘
                  ▼
         notification-email  (if: always())
```

| Job | `needs` | Role |
| --- | --- | --- |
| `build-preprocess` | — | Validate inputs; emit cache key |
| `build-test-lint` | preprocess | Single build + test/lint; upload `build-output` |
| `owasp` | build-test-lint | Scan; upload `owasp-report` |
| `sonarqube` | build-test-lint, owasp | Scan with OWASP import paths |
| `sonarqube-gate` | sonarqube | Quality gate; must succeed before publish |
| `publish-to-nexus` | sonarqube-gate, build-test-lint | Deploy shared build artifact |
| `docker-build-publish` | sonarqube-gate, build-test-lint | Image from shared build artifact |
| `notification-email` | all prior | SMTP summary; `if: always()` |

## Artifact flow

1. **`build-output`** — produced once by `build-test-lint` from `artifact-path`; consumed by `owasp`, `sonarqube`, `publish-to-nexus`, and `docker-build-publish` (no rebuild).
2. **`owasp-report`** — HTML/JSON/SARIF from Dependency-Check; downloaded by `sonarqube` and passed via:
   - `sonar.dependencyCheck.jsonReportPath`
   - `sonar.dependencyCheck.htmlReportPath`
   - `sonar.sarifReportPaths`

## Cache

| Cache | Where | Key material |
| --- | --- | --- |
| Maven/Gradle deps | `setup-java` `cache:` | language defaults |
| npm | `setup-node` `cache: npm` | lockfile path |
| Build toolchain dirs | `actions/cache` in `build-test-lint` | `build-${{ package-manager }}-${{ cache-key-suffix }}-${{ sha }}` |
| OWASP NVD data | `.owasp-data` | `owasp-data-${{ cache-key-suffix }}` |
| Docker layers | GHA cache via buildx | `cache-from/to: type=gha` |

## Inputs

| Input | Required | Default | Description |
| --- | --- | --- | --- |
| `java-version` | no | `17` | JDK for Maven/Gradle/OWASP/Sonar |
| `node-version` | no | `20` | Node when `package-manager=npm` |
| `package-manager` | no | `maven` | `maven` \| `gradle` \| `npm` |
| `build-command` | no | `""` | Override single build command |
| `test-lint-command` | no | `""` | Override test/lint command |
| `artifact-path` | no | `dist/` | Build output path (shared artifact) |
| `working-directory` | no | `.` | Project root |
| `sonar-project-key` | yes | — | SonarQube project key |
| `sonar-host-url` | yes | — | SonarQube URL |
| `nexus-url` | yes | — | Nexus base URL |
| `nexus-repository` | yes | — | Nexus repo name |
| `docker-image` | yes | — | Image name without tag |
| `docker-registry` | yes | — | Registry host for login |
| `docker-context` | no | `.` | Docker context |
| `dockerfile` | no | `Dockerfile` | Dockerfile path |
| `notify-to` | yes | — | Email recipient |
| `environment-name` | no | `production` | Environment for publish jobs |
| `cache-key-suffix` | no | `v1` | Cache busting suffix |

## Secrets

| Secret | Used by |
| --- | --- |
| `SONAR_TOKEN` | `sonarqube`, `sonarqube-gate` |
| `NEXUS_USERNAME` / `NEXUS_PASSWORD` | `publish-to-nexus` |
| `DOCKER_USERNAME` / `DOCKER_PASSWORD` | `docker-build-publish` |
| `SMTP_HOST` / `SMTP_PORT` / `SMTP_USERNAME` / `SMTP_PASSWORD` | `notification-email` |

## Outputs

| Output | Source |
| --- | --- |
| `build-artifact-name` | `build-test-lint` |
| `sonar-quality-gate` | `sonarqube-gate` |
| `nexus-publish-url` | `publish-to-nexus` |
| `docker-image-tag` | `docker-build-publish` |

## Usage

```yaml
name: App CI

on:
  push:
    branches: [main]

jobs:
  pipeline:
    uses: org/gha-reusable-actions-workflows/.github/workflows/ci-pipeline-8stage.yml@main
    with:
      package-manager: maven
      artifact-path: target/
      sonar-project-key: my-app
      sonar-host-url: https://sonar.example.com
      nexus-url: https://nexus.example.com
      nexus-repository: maven-releases
      docker-image: ghcr.io/org/my-app
      docker-registry: ghcr.io
      notify-to: release-train@example.com
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
```

## Policy notes

- Workflow `permissions` are read-only at top level; each job declares `permissions`.
- Publish jobs use `environment:` and consume the shared build artifact only after `sonarqube-gate` succeeds.
- Third-party `uses:` are pinned to 40-character SHAs; shell steps use `set -euo pipefail` and map inputs via `env`.
