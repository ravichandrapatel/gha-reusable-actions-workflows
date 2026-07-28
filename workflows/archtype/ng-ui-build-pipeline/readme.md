# NG-UI Build Pipeline

Reusable `workflow_call` pipeline for Angular/`ng-ui` apps.

## Jobs

```text
preprocess → build_and_unit_test → owasp (optional)
                               └→ sonar + quality gate (optional)
                               └→ publish (semantic-release + snapshot/release gates)
```

Deferred: docker image, email.

**Publish rules** (when `semantic-release` is true):

| Preprocess gate | Command |
| --- | --- |
| `snapshot_artifact` | `npm publish --tag prerelease --registry $NEXUS_HOST_URL` |
| `release_artifact` | `npm publish --registry $NEXUS_HOST_URL` |

## Inputs

| Input | Default |
| --- | --- |
| `runs-on` | `["self-hosted","el9"]` (JSON string) |
| `build-command` | `npm run build` |
| `lint-command` | `npm run lint:prod` |
| `test-command` | `npm run test:cov` |
| `semantic-release` | `true` (enables publish job with preprocess artifact gates) |
| `enable_sonar` | `true` |
| `enable_owasp` | `true` |
| `sonar_host_url` | `''` (required when Sonar runs) |
| `owasp_suppression_file` | `''` (path under `.owasp-suppression/` or workspace; empty = none) |

## Secrets (all optional)

`SONARQUBE_TOKEN`, `OWASP_DEPENDENCY_CHECK_NVD_API_KEY`, `NEXUS_HOST_URL`, `NEXUS_DOCKER_*`, `NEXUS_ARTIFACT_*`, `EMAIL_TOKEN`, `REDHAT_REGISTRY_*`, `DEVSECOPS_*`, `NODE_AUTH_TOKEN`

## Caller requirements

- Repo root: `build.values`, `project.values`, `package.json` (`version`, `engines.node`)
- Inventory allowlist membership via house preprocess action
- Prefer `sonar-project.properties` for Sonar project key/settings
- OWASP job expects Podman on the runner (house OWASP action)

## Usage

```yaml
jobs:
  pipeline:
    uses: <org>/gha-reusable-actions-workflows/.github/workflows/ng-ui-build-pipeline.yaml@<sha>
    with:
      sonar_host_url: https://sonar.example.com
    secrets:
      SONARQUBE_TOKEN: ${{ secrets.SONARQUBE_TOKEN }}
      NODE_AUTH_TOKEN: ${{ secrets.NODE_AUTH_TOKEN }}
      OWASP_DEPENDENCY_CHECK_NVD_API_KEY: ${{ secrets.OWASP_DEPENDENCY_CHECK_NVD_API_KEY }}
```

House actions are checked out from the reusable workflow’s repository (parsed from `github.workflow_ref`) into `.platform-actions/`.
