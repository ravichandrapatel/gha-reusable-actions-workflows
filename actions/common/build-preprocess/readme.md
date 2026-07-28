# Build Preprocess

1. Match a caller repo against the bundled inventory allowlist (`inventory.json`).
2. Resolve app-build metadata from root `build.values` / `project.values` (and type-specific project file).

## Inputs

| Input | Required | Default | Description |
| --- | --- | --- | --- |
| `repo` | yes | — | Exact repo/app id to match |
| `app_build_type` | yes | — | `maven-java` \| `dotnet` \| `ng-ui` (**only `ng-ui` implemented**) |
| `inventory_path` | no | `${ACTION_PATH}/inventory.json` | Override inventory JSON path |
| `soft` | no | `false` | On inventory miss: succeed with `matched=false` |
| `workspace` | no | `GITHUB_WORKSPACE` | Repo root containing values files |
| `branch` | no | `github.ref_name` | Must be `master`/`main`/`develop` or `feature`/`release`/`hotfix`/`bugfix` family |

## Outputs

| Output | Description |
| --- | --- |
| `matched` / `matched_id` | Inventory match result |
| `app_build_type` | Echo of resolved build type |
| `branch` | Validated branch name |
| `application_version` | From `package.json` `version` (`ng-ui`) |
| `node_version` | From `package.json` `engines.node` (`ng-ui`) |
| `build_and_unit_test` / `owasp` / `sonar` | Stage gates (always `true`) |
| `snapshot_artifact` | `true` if `develop` and not PR |
| `release_artifact` | `true` if `release`/`hotfix` and `workflow_dispatch` |
| `docker_image` | `true` if manual, not bot actor, and not PR |
| `BUILDER_BASE_IMAGE`, `LIB_01`…`LIB_03` | From `build.values` |
| `APPLICATION_NAME`, `ORGANIZATION`, `PRODUCT`, `PROJECT_DESCRIPTION`, `CMDBIDNPD`, `CMDBIDPRD`, `TEAMADGROUNPD`, `TEAMADGROUPPRD` | From `project.values` |

## Usage

```yaml
- name: Build preprocess
  id: preprocess
  uses: ./actions/common/build-preprocess
  with:
    repo: ${{ github.event.repository.name }}
    app_build_type: ng-ui
```

## Values files (repo root)

Key=value pairs. Blank lines and `#` comments (or keys starting with `#`) are ignored.

**`build.values` (required keys):** `BUILDER_BASE_IMAGE`, `LIB_01`, `LIB_02`, `LIB_03`

**`project.values` (required keys):** `APPLICATION_NAME`, `ORGANIZATION`, `PRODUCT`, `PROJECT_DESCRIPTION`, `CMDBIDNPD`, `CMDBIDPRD`, `TEAMADGROUNPD`, `TEAMADGROUPPRD`

## Python CLIs

### `check_inventory.py`

| Arg | Env default |
| --- | --- |
| `--repo` | `CALLER_REPO` |
| `--inventory-path` | `${ACTION_PATH}/inventory.json` |
| `--output` | `GITHUB_OUTPUT` |

### `preprocess.py`

| Arg | Env default |
| --- | --- |
| `--app-build-type` | `APP_BUILD_TYPE` |
| `--branch` | `GITHUB_REF_NAME` / `BRANCH` |
| `--workspace` | `GITHUB_WORKSPACE` (else cwd) |
| `--output` | `GITHUB_OUTPUT` |

**Allowed branches:** exact `master`, `main`, `develop`; prefixes `feature`, `release`, `hotfix`, `bugfix` (e.g. `feature/foo`, `hotfix-1`).

```bash
export APP_BUILD_TYPE=ng-ui
python3 actions/common/build-preprocess/preprocess.py \
  --workspace /path/to/app \
  --dry-run
```
