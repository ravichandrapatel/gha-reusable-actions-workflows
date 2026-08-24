# Sonar Scan

First generate `sonar-project.properties`, then run the official SonarQube scan, merge project tags, and poll the quality gate.

Desired tags:

- `organizations-<organization>`
- `product-<product>`
- `platform-<platform>` (`platform` defaults to `cap`)

## Overview & context

- **Purpose**: House wrapper that writes scanner properties, then runs official scan + quality-gate actions and idempotent project tagging.
- **Scope**: Properties → scan → tag merge → quality gate in one composite.
- **Success criteria**: Properties are printed; scanner exits 0; each desired tag is present; quality gate is polled. A failed gate fails the action unless `continue_on_error` is `true`.

## Metadata dashboard

| Attribute | Value |
| --- | --- |
| **Owner / Lead** | DevOps Team |
| **Service Status** | Draft (pre-release) |
| **Repository / Code** | `actions/security/sonar-scan` |
| **Dependencies** | Official scan pin v8.2.1, quality-gate pin v1.2.1, Python 3, SonarQube Web API |

## Inputs

| Input | Required | Default | Description |
| --- | --- | --- | --- |
| `sonar_token` | Yes | — | SonarQube token (map from a secret). Needs **Administer** on the project to set tags. |
| `sonar_host_url` | Yes | — | SonarQube base URL. |
| `project_key` | Yes | — | SonarQube project key (`[A-Za-z0-9_.:-]+`). |
| `organization` | Yes | — | Value for `organizations-<value>`. |
| `product` | Yes | — | Value for `product-<value>`. |
| `platform` | No | `cap` | Value for `platform-<value>`. |
| `application_name` | No | `project_key` | `sonar.projectName`. |
| `app_build_type` | No | `""` | `maven`, `ng-ui`, or `dotnet`. |
| `pr_key` | No | `""` | `sonar.pullrequest.key`. Must be set with `pr_branch` and `pr_base`. |
| `pr_branch` | No | `""` | `sonar.pullrequest.branch`. |
| `pr_base` | No | `""` | `sonar.pullrequest.base`. |
| `args` | No | `""` | Extra sonar-scanner CLI arguments. For `ng-ui`, `-Dsonar.inclusions=...` is stripped so the generated file wins. |
| `project_base_dir` | No | `.` | Passed through as `projectBaseDir`; properties are written here. |
| `scanner_version` | No | `8.1.0.6389` | Sonar Scanner CLI version used by the official action. |
| `continue_on_error` | No | `false` | If `true`, a failed quality gate does not fail this action. |
| `polling_timeout_sec` | No | `300` | Seconds to poll for the quality gate status. |

## Generated properties (`ng-ui`)

Always: `sonar.projectKey`, `sonar.projectName=<application_name>`.

When `app_build_type` is `ng-ui`:

- `sonar.sources=apps,package-lock.json`
- `sonar.inclusions=apps/**,package-lock.json` (replaces preprocess `sonar.inclusions`)
- `sonar.dependencyCheck.htmlReportPath=reports/dependency-check-report.html`
- `sonar.dependencyCheck.jsonReportPath=reports/dependency-check-report.json`
- `sonar.javascript.lcov.reportPaths=coverage/lcov.info` only if that file exists

When `pr_key`, `pr_branch`, and `pr_base` are all set:

- `sonar.pullrequest.key` / `branch` / `base`

The step prints the file contents.

## Outputs

| Output | Description |
| --- | --- |
| `properties_path` | Path of the generated `sonar-project.properties`. |
| `properties` | File contents. |
| `tags` | Tags on the project after the merge. |
| `tags_added` | Desired tags that were missing and written. |
| `tags_matched` | Desired tags that already existed. |
| `tags_updated` | `true` when at least one tag was written. |
| `quality_gate_status` | `PASSED`, `WARN`, or `FAILED`. |

## Usage

```yaml
- uses: ./actions/security/sonar-scan
  with:
    sonar_token: ${{ secrets.SONAR_TOKEN }}
    sonar_host_url: ${{ vars.SONAR_HOST_URL }}
    project_key: ${{ steps.prep.outputs.application_name }}
    application_name: ${{ steps.prep.outputs.application_name }}
    app_build_type: ng-ui
    organization: ${{ steps.prep.outputs.organization }}
    product: ${{ steps.prep.outputs.product }}
    platform: cap
    pr_key: ${{ github.event.pull_request.number }}
    pr_branch: ${{ github.event.pull_request.head.ref }}
    pr_base: ${{ github.event.pull_request.base.ref }}
    args: ${{ steps.prep.outputs.sonar_cli_args }}
    continue_on_error: false
```

Pass `platform` when it is not `cap`. Set `continue_on_error: true` when a failed gate should not fail the job. Tagging runs after the scan and before the gate, so tags are still applied if the gate fails.

## Manual run

```bash
python3 -u actions/security/sonar-scan/generate_properties.py \
  --dry-run \
  --project-key my-app \
  --application-name SnapShip \
  --app-build-type ng-ui \
  --pr-key 12 \
  --pr-branch feature/x \
  --pr-base develop

python3 -u actions/security/sonar-scan/ensure_tags.py \
  --dry-run \
  --project-key my-app \
  --organization shipping \
  --product snapship \
  --platform cap
```

## Release

Tags after Release Manager: `sonar-scan/v1.0.0` (versioned), `sonar-scan/v1` (stable, after promote).
