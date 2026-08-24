# Docker Build and Push

Generate a Nexus image tag, `buildah bud`, then retried `buildah push`. Log in first with `actions/common/docker-login`.

## Overview & context

- **Purpose**: Build and push `{registry}/{organization}/production/{application}:{tag}`.
- **Tag**: `{date}-{snapshot}-{build:5}-{branch:0:3}-{commit:0:5}-{application_name}-{application_version}` (UTC `YYYYMMDD`, sanitized).
- **Scope**: Tag via `tag.sh`; `buildah bud` in bash; push via `ravichandrapatel/gha-reusable-actions-workflows/actions/common/retry@retry/v1.2.0`.
- **Success criteria**: `buildah bud` succeeds and push exits 0 within `max_attempts`.

## Metadata dashboard

| Attribute | Value |
| --- | --- |
| **Owner / Lead** | DevOps Team |
| **Service Status** | Draft (pre-release) |
| **Repository / Code** | `actions/common/docker-build-and-push` |
| **Dependencies** | bash, `buildah`, `actions/common/retry` |

## Inputs

| Input | Required | Default | Description |
| --- | --- | --- | --- |
| `registry` | Yes | — | Nexus registry host. |
| `organization` | Yes | — | Org path segment. |
| `application` | Yes | — | Application name from build-preprocess. |
| `project_version` | Yes | — | Snapshot/project version from build-preprocess. |
| `application_version` | Yes | — | Application version from build-preprocess. |
| `environment` | No | `production` | Path segment after org. |
| `repo` | No | `""` | `owner/repo` or repo name. Empty uses `GITHUB_REPOSITORY`. |
| `branch` | No | `""` | Empty uses `GITHUB_HEAD_REF` then `GITHUB_REF_NAME`. Tag uses `[0:3]`. |
| `sha` | No | `""` | Empty uses `GITHUB_SHA`. Tag uses `[0:5]`. |
| `build_number` | No | `""` | Empty uses `GITHUB_RUN_NUMBER`. Tag uses 5 chars, zero-padded. |
| `file` | No | `Dockerfile` | Dockerfile relative to context. |
| `context` | No | `""` | Empty uses `GITHUB_WORKSPACE`. |
| `tls_verify` | No | `true` | `buildah --tls-verify`. |
| `max_attempts` | No | `3` | Push retries. |
| `retry_wait_seconds` | No | `5` | Wait between failed pushes. |
| `timeout_seconds` | No | `300` | Per-attempt push timeout; `0` disables. |

## Outputs

| Output | Description |
| --- | --- |
| `tag` | Generated tag. |
| `image` | Full `registry/org/env/app:tag`. |
| `app_archetype` | Last two hyphen parts of the repo name. |
| `application_name` | Sanitized application name in the tag. |
| `project_version` | Snapshot/project version in the tag. |
| `application_version` | Application version in the tag. |
| `short_branch` | First 3 of the sanitized branch. |
| `short_sha` | First 5 of the SHA. |
| `build_number` | 5-character build number. |
| `succeeded` | `true` when push succeeded. |

## Usage

```yaml
- uses: ravichandrapatel/gha-reusable-actions-workflows/actions/common/docker-login@docker-login/v1.2.0
  with:
    registry: ${{ vars.NEXUS_REGISTRY }}
    username: ${{ secrets.NEXUS_USERNAME }}
    password: ${{ secrets.NEXUS_PASSWORD }}

- uses: ravichandrapatel/gha-reusable-actions-workflows/actions/common/docker-build-and-push@docker-build-and-push/v1.4.0
  with:
    registry: ${{ vars.NEXUS_REGISTRY }}
    organization: ${{ steps.preprocess.outputs.organization }}
    application: ${{ steps.preprocess.outputs.application_name }}
    project_version: ${{ steps.preprocess.outputs.project_version }}
    application_version: ${{ steps.preprocess.outputs.application_version }}
```

## Manual run (tag only)

```bash
bash actions/common/docker-build-and-push/tag.sh \
  --registry nexus.example.com \
  --organization ccmo \
  --application snapshipadmin-jsb-ui \
  --project-version 2.7.18-SNAPSHOT \
  --application-version 2.7.18 \
  --repo ccmo-shippingtools-snapshipadmin-jsb-ui \
  --branch feature/foo \
  --sha abcdef1234567890 \
  --build-number 42 \
  --date 20260817
```

## Release

Tags after Release Manager: `docker-build-and-push/v1.0.0` (versioned), `docker-build-and-push/v1` (stable, after promote).
