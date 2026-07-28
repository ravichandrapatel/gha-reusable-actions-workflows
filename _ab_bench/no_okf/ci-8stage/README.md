# CI 8-Stage Reusable Workflow

Reusable GitHub Actions workflow (`on: workflow_call`) that builds once, scans with OWASP Dependency-Check, imports the OWASP report into SonarQube, enforces a quality gate before publish, publishes to Nexus and/or Docker, then always sends a notification.

**Workflow file:** [`workflow.yml`](./workflow.yml)

## Stages (dependency graph)

```text
build-preprocess
       │
       ▼
build-test-lint  ──────────────────────────────┐
       │                                         │
       ▼                                         │
     owasp                                       │
       │                                         │
       ▼                                         │
  sonarqube  (imports OWASP JSON)                │
       │                                         │
       ▼                                         │
 sonarqube-gate  (blocks publish on fail)        │
       │                                         │
       ├────────────────┬────────────────────────┤
       ▼                ▼                        │
publish-to-nexus   docker-build-publish          │
       │                │                        │
       └────────┬───────┘                        │
                ▼                                │
        notification-email                       │
        (needs: all prior; if: always())   <─────┘
```

| Job | `needs` | Purpose |
|-----|---------|---------|
| `build-preprocess` | — | Toolchain setup, dependency download, warm caches |
| `build-test-lint` | `build-preprocess` | **Single** lint → build → test; upload build + test artifacts |
| `owasp` | `build-test-lint` | OWASP Dependency-Check; upload HTML/JSON/SARIF |
| `sonarqube` | `build-test-lint`, `owasp` | Sonar analysis + **OWASP JSON import** |
| `sonarqube-gate` | `sonarqube` | Poll quality gate; **fail blocks Nexus/Docker** |
| `publish-to-nexus` | `build-test-lint`, `sonarqube-gate` | Deploy built artifacts to Nexus (no rebuild) |
| `docker-build-publish` | `build-test-lint`, `sonarqube-gate` | Docker build using downloaded `ci-artifacts` |
| `notification-email` | all prior jobs | Summarize + email; **`if: always()`** |

## Artifact flow

| Artifact name | Produced by | Consumed by | Contents |
|---------------|-------------|-------------|----------|
| `build-output` | `build-test-lint` | `owasp` (optional), `publish-to-nexus`, `docker-build-publish` | Built binaries (`artifact-path`, default `target/*.jar`) |
| `test-reports` | `build-test-lint` | `sonarqube` | Surefire / JaCoCo / coverage (best-effort) |
| `owasp-dependency-check` | `owasp` | `sonarqube` | `dependency-check-report.json` (+ HTML/SARIF) |

Build once: compile/package runs only in `build-test-lint`. Later jobs download artifacts via `actions/download-artifact` instead of rebuilding.

OWASP → Sonar: Sonar is invoked with:

- `sonar.dependencyCheck.jsonReportPath=…/dependency-check-report.json`
- optional `sonar.dependencyCheck.htmlReportPath=…`

Quality gate → publish: `publish-to-nexus` and `docker-build-publish` both `needs: [build-test-lint, sonarqube-gate]` and run only when the gate job succeeds (`success()`).

Docker: artifacts land in `{docker-context}/ci-artifacts` and are passed as build-arg `CI_ARTIFACTS_DIR=ci-artifacts` (Dockerfile should `COPY ci-artifacts/ …`).

## Cache strategy

| Cache | Path(s) | Key basis | Jobs |
|-------|---------|-----------|------|
| Maven `~/.m2/repository` | `**/pom.xml` hash + `cache-key-suffix` | preprocess (save), build/sonar/nexus (restore) |
| Gradle caches/wrapper | gradle files + wrapper props | preprocess + build |
| npm / `node_modules` | lockfile hash | preprocess + build |
| OWASP DC data `~/.dependency-check` | lock/pom/gradle hash | preprocess + owasp |
| Docker layers | GHA cache (`type=gha`) scoped by `cache-key-suffix` | docker-build-publish |

Bump `cache-key-suffix` to invalidate all named caches.

## Inputs

| Input | Type | Default | Required | Description |
|-------|------|---------|----------|-------------|
| `java-version` | string | `17` | no | JDK for Maven/Gradle/scans |
| `node-version` | string | `20` | no | Node when `project-type` is `node`/`both` |
| `project-type` | string | `maven` | no | `maven` \| `gradle` \| `node` \| `both` |
| `build-command` | string | `""` | no | Override build command |
| `test-command` | string | `""` | no | Override test command |
| `lint-command` | string | `""` | no | Override lint command |
| `artifact-path` | string | `target/*.jar` | no | Globs under working-directory to upload |
| `docker-context` | string | `.` | no | Docker build context |
| `docker-file` | string | `Dockerfile` | no | Dockerfile path |
| `docker-image` | string | `""` | no | Image name without tag (required to enable push) |
| `docker-tag` | string | `latest` | no | Primary image tag |
| `nexus-repository-url` | string | `""` | no | Nexus deploy URL |
| `nexus-repository-id` | string | `nexus` | no | settings.xml `server-id` |
| `sonar-project-key` | string | — | **yes** | SonarQube project key |
| `sonar-host-url` | string | — | **yes** | SonarQube base URL |
| `sonar-sources` | string | `src` | no | Sonar sources |
| `owasp-nvd-api-key` | string | `""` | no | Unused placeholder; prefer secret `NVD_API_KEY` |
| `enable-nexus-publish` | boolean | `true` | no | Toggle Nexus job |
| `enable-docker-publish` | boolean | `true` | no | Toggle Docker job |
| `notification-to` | string | `""` | no | Email recipient(s) |
| `working-directory` | string | `.` | no | Project subdirectory |
| `cache-key-suffix` | string | `v1` | no | Cache bust segment |

## Secrets

| Secret | Required | Used by |
|--------|----------|---------|
| `SONAR_TOKEN` | **yes** | `sonarqube`, `sonarqube-gate` |
| `NEXUS_USERNAME` | no* | `publish-to-nexus` |
| `NEXUS_PASSWORD` | no* | `publish-to-nexus` |
| `DOCKER_USERNAME` | no* | `docker-build-publish` |
| `DOCKER_PASSWORD` | no* | `docker-build-publish` |
| `DOCKER_REGISTRY` | no | Registry host for `docker/login-action` |
| `SMTP_HOST` | no | `notification-email` |
| `SMTP_PORT` | no | `notification-email` (default 587) |
| `SMTP_USERNAME` | no | `notification-email` |
| `SMTP_PASSWORD` | no | `notification-email` |
| `NVD_API_KEY` | no | OWASP Dependency-Check (rate limits) |

\*Required when the corresponding publish path is enabled and configured.

## Outputs

| Output | Source job | Description |
|--------|------------|-------------|
| `build-artifact-name` | `build-test-lint` | Uploaded build artifact name (`build-output`) |
| `sonar-quality-gate-status` | `sonarqube-gate` | Gate status (`OK` / `WARN` / `ERROR` / …) |
| `nexus-publish-status` | `publish-to-nexus` | `published` / `skipped` / `failed` |
| `docker-image-digest` | `docker-build-publish` | Image digest from push |
| `pipeline-conclusion` | `notification-email` | `success` or `failure` |

## Usage example

Place the reusable workflow in your actions repo (or call by path in the same repo):

```yaml
# .github/workflows/ci.yml
name: Application CI

on:
  push:
    branches: [main]
  pull_request:

jobs:
  pipeline:
    uses: ./.github/workflows/ci-8stage.yml   # or org/repo/.github/workflows/workflow.yml@v1
    with:
      project-type: maven
      java-version: "17"
      artifact-path: "target/*.jar"
      sonar-project-key: my-org_my-app
      sonar-host-url: https://sonar.example.com
      nexus-repository-url: https://nexus.example.com/repository/maven-releases/
      nexus-repository-id: nexus
      docker-image: registry.example.com/my-org/my-app
      docker-tag: ${{ github.sha }}
      enable-nexus-publish: true
      enable-docker-publish: true
      notification-to: team@example.com
      cache-key-suffix: v1
    secrets:
      SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}
      NEXUS_USERNAME: ${{ secrets.NEXUS_USERNAME }}
      NEXUS_PASSWORD: ${{ secrets.NEXUS_PASSWORD }}
      DOCKER_USERNAME: ${{ secrets.DOCKER_USERNAME }}
      DOCKER_PASSWORD: ${{ secrets.DOCKER_PASSWORD }}
      DOCKER_REGISTRY: registry.example.com
      SMTP_HOST: ${{ secrets.SMTP_HOST }}
      SMTP_PORT: ${{ secrets.SMTP_PORT }}
      SMTP_USERNAME: ${{ secrets.SMTP_USERNAME }}
      SMTP_PASSWORD: ${{ secrets.SMTP_PASSWORD }}
      NVD_API_KEY: ${{ secrets.NVD_API_KEY }}
```

Copy [`workflow.yml`](./workflow.yml) to `.github/workflows/ci-8stage.yml` (or reference it from a shared workflows repository) before calling `uses:`.

### Dockerfile note

```dockerfile
ARG CI_ARTIFACTS_DIR=ci-artifacts
COPY ${CI_ARTIFACTS_DIR}/ /app/artifacts/
# … runtime image uses /app/artifacts instead of rebuilding inside Docker
```

## Functional checklist

- [x] `on: workflow_call` with documented inputs / secrets / outputs  
- [x] Eight named stages with explicit `needs:`  
- [x] Build once; later stages use artifacts  
- [x] Dependency / Docker / OWASP caches  
- [x] OWASP report imported into SonarQube  
- [x] Quality gate blocks Nexus and Docker  
- [x] Docker consumes build artifacts under `ci-artifacts`  
- [x] `notification-email` uses `if: always()`  
