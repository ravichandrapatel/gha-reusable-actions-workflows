# S2I Build and Push

Binary Source-to-Image build from a **pre-built** artifact using Red Hat **`s2i build`**, then retried `buildah push`. Log in first with `actions/common/docker-login`.

## Overview & context

- **Purpose**: Maven, .NET, and similar services whose jar/war or publish output was already produced in a prior job. Does not compile.
- **Scope**: `prepare.sh` stages the artifact as an S2I source directory. `s2i-build.sh` runs `s2i build SOURCE BUILDER IMAGE`. Tagging uses bundled `tag.sh`; push uses `actions/common/retry`.
- **Success criteria**: Source is non-empty; `s2i build` succeeds; push exits 0.

## Metadata dashboard

| Attribute | Value |
| --- | --- |
| **Owner / Lead** | DevOps Team |
| **Service Status** | Draft (pre-release) |
| **Repository / Code** | `actions/common/s2i-build-and-push` |
| **Dependencies** | bash, `s2i`, `buildah`, `actions/common/retry` |

## Inputs

| Input | Required | Default | Description |
| --- | --- | --- | --- |
| `builder_image` | Yes | — | S2I builder (`BUILDER_BASE_IMAGE`). |
| `artifact_path` | Yes | — | File or directory from the prior build job (after `download-artifact`). |
| `app_build_type` | Yes | — | `maven`, `dotnet`, or `other`. `ng-ui` is rejected. |
| `pull_policy` | No | `if-not-present` | Builder image pull policy for `s2i build`. |
| `log_level` | No | `1` | `s2i` log level (0–5). |
| `registry` | Yes | — | Nexus registry host. |
| `organization` | Yes | — | Org path segment. |
| `product` | Yes | — | Product path segment (`registry/org/product/app`). |
| `application` | Yes | — | Application name (final path segment). |
| `project_version` | Yes | — | Snapshot/project version from build-preprocess. |
| `parent_version` | Yes | — | Parent version (last tag segment). |
| `repo` | No | `""` | Used to derive `app_archetype` (last two hyphen parts). |
| `branch` | No | `""` | Empty uses `GITHUB_HEAD_REF` then `GITHUB_REF_NAME`. |
| `sha` | No | `""` | Empty uses `GITHUB_SHA`. |
| `build_number` | No | `""` | Empty uses `GITHUB_RUN_NUMBER`. |
| `tls_verify` | No | `true` | `s2i` / `buildah --tls-verify`. |
| `max_attempts` | No | `3` | Push retries. |
| `retry_wait_seconds` | No | `5` | Wait between failed pushes. |
| `timeout_seconds` | No | `300` | Per-attempt push timeout; `0` disables. |

## Outputs

Same image outputs as `docker-build-and-push`, plus:

| Output | Description |
| --- | --- |
| `source` | Staged S2I source directory passed to `s2i build`. |

## Usage

Caller downloads the prior-stage artifact, then:

```yaml
- uses: actions/download-artifact@3e5f45b2cfb9172054b4087a40e8e0b5a5461e7c # v8.0.1
  with:
    name: maven-artifact
    path: artifact

- uses: ravichandrapatel/gha-reusable-actions-workflows/actions/common/docker-login@docker-login/v1.2.0
  with:
    registry: ${{ vars.NEXUS_REGISTRY }}
    username: ${{ secrets.NEXUS_USERNAME }}
    password: ${{ secrets.NEXUS_PASSWORD }}

- uses: ravichandrapatel/gha-reusable-actions-workflows/actions/common/s2i-build-and-push@s2i-build-and-push/v1.0.0
  with:
    builder_image: ${{ needs.build-preprocess.outputs.builder_base_image }}
    artifact_path: artifact
    app_build_type: maven
    registry: ${{ vars.NEXUS_REGISTRY }}
    organization: ${{ needs.build-preprocess.outputs.organization }}
    product: ${{ needs.build-preprocess.outputs.product }}
    application: ${{ needs.build-preprocess.outputs.application_name }}
    project_version: ${{ needs.build-preprocess.outputs.project_version }}
    parent_version: ${{ needs.build-preprocess.outputs.parent_version }}
```

.NET: set `app_build_type: dotnet` and point `artifact_path` at the downloaded publish directory.

## Manual run

```bash
bash actions/common/s2i-build-and-push/prepare.sh \
  --artifact /tmp/app.jar \
  --app-build-type maven \
  --source /tmp/s2i-source

bash actions/common/s2i-build-and-push/s2i-build.sh \
  --source /tmp/s2i-source \
  --builder-image nexus.example.com/ubi8/openjdk-11:1.14 \
  --image nexus.example.com/org/product/my-app:tag
```

## Release

Tags after Release Manager: `s2i-build-and-push/v1.0.0` (versioned), `s2i-build-and-push/v1` (stable, after promote).
