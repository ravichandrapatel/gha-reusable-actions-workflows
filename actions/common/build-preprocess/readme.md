# Build Preprocess

Composite action that allowlists the branch and emits CI stages. Inventory matching is a nested house action pinned at `@check-inventory/v1`.

## Overview & context

- **Purpose**: Resolve project metadata and `build_stages` for Maven / ng-ui / dotnet pipelines.
- **Scope**: Does not ship `inventory.json`. Repo allowlist lives in `actions/common/check-inventory` (populated by `tfvars-inventory-sync`). This composite calls that action at the stable tag, then runs `preprocess.py`.
- **Success criteria**: inventory step succeeds (caller listed); then branch/stage emission exits 0.

## Metadata dashboard

| Attribute | Value |
| --- | --- |
| **Owner / Lead** | DevOps Team |
| **Service Status** | Draft (pre-release) |
| **Repository / Code** | `actions/common/build-preprocess` |
| **Dependencies** | Python 3; composite step installs `requirements.txt` (`defusedxml`); nested `check-inventory@check-inventory/v1` |

## Inputs

| Input | Required | Default | Description |
| --- | --- | --- | --- |
| `inventory_file` | No | `inventory.json` | Passed through to `check-inventory`. |
| `repo` | No | `""` | Passed through to `check-inventory`. Empty uses `GITHUB_REPOSITORY`. |
| `branch` | No | `""` | Branch to allowlist. Empty uses `GITHUB_HEAD_REF` then `GITHUB_REF_NAME`. |
| `app_build_type` | Yes | — | `maven`, `ng-ui`, or `dotnet`. |
| `bot_name` | No | `""` | Actor treated as auto-commit bot. Other stages skip when `github.actor` matches. |

## Outputs

| Output | Description |
| --- | --- |
| `repos` | Compact JSON array of names (from `check-inventory`). |
| `matched` | `true` when listed (from `check-inventory`). |
| `repo` | Resolved caller repo used for the match (from `check-inventory`). |
| `branch` | Resolved branch used for the allowlist check. |
| `approved` | `true` when the branch matches an approved glob. |
| `build_stages` | JSON array of **enabled** stage names. Gate with `contains(fromJSON(needs.build-preprocess.outputs.build_stages), 'owasp')`. |
| `auto_commit` | `true` when `github.actor` matches `bot_name`. |
| `bot_name` | Configured auto-commit bot name. |
| `app_build_type` | Validated `maven`, `ng-ui`, or `dotnet`. |
| `template` | From `project.values` `TEMPLATE` (empty if absent). |
| `application_name` | From `project.values`. |
| `organization` | From `project.values`. |
| `product` | From `project.values`. |
| `project_description` | From `project.values`. |
| `cmdbidnpd` | From `project.values`. |
| `cmdbidprd` | From `project.values`. |
| `teamaadgroupnpg` | From `project.values`. |
| `teaaadgroupprd` | From `project.values`. |
| `builder_base_image` | From `build.values`. |
| `cpgbuild_app_origin` | From `build.values` `CPGBUILD_APP_ORIGIN` (fallback `CPGBUILD_APPORIGIN`), stripped. |
| `checkstyle_skip` | `true` when `cpgbuild_app_origin` is non-empty; `false` otherwise. |
| `lib_01` / `lib_02` / `lib_03` | Optional from `build.values` `LIB_01` / `LIB_02` / `LIB_03` (empty when unset or commented). |
| `is_library` | Maven/dotnet: `n` when `project.values` has `TEMPLATE`; `y` when `TEMPLATE` is missing. Empty for ng-ui. Docker is skipped when this value equals `y` (case-insensitive). |
| `sonar_inclusions` | `-Dsonar.inclusions=<list>` when `CPGBUILD_SONAR_INCLUSION_LIST` is set; empty otherwise. |
| `sonar_exclusions` | `-Dsonar.exclusions=<list>` when `CPGBUILD_SONAR_EXCLUSION_LIST` is set; empty otherwise. |
| `sonar_cli_args` | Joined inclusion and exclusion `-D` arguments. |
| `application_version` | ng-ui: `dependencies.@test/components` when declared (strips npm range markers like `^`/`~`), else `package.json` `version`. Maven: parent `<version>` when parent exists, else project `<version>`. Dotnet: `build/Build.csproj` `<Version>`, else `Directory.Build.props` `<Version>`. |
| `parent_version` | ng-ui: `@test/components` version when declared (range markers stripped). Maven: `parent/version`. Dotnet: `Directory.Build.props` `<Version>`. |
| `project_version` | ng-ui: `package.json` `version`. Maven: project `<version>`. Dotnet: `build/Build.csproj` `<Version>`. |
| `name` | From `pom.xml` `name` when `app_build_type` is `maven`. |
| `java_version` | From `pom.xml` `properties/java.version` when `app_build_type` is `maven`. |
| `node_version` | From `package.json` `engines.node`, or `.nvmrc` / `.node-version`, when `app_build_type` is `ng-ui`. |
| `dotnet_version` | From root `global.json` `sdk.version` when `app_build_type` is `dotnet`. |

Dotnet layout is fixed (no `APPLICATION_NAME` → csproj matching): root `Directory.Build.props` + `global.json`, and `build/Build.csproj`.

## Usage

```yaml
- name: Build preprocess
  id: preprocess
  uses: ravichandrapatel/gha-reusable-actions-workflows/actions/common/build-preprocess@build-preprocess/v1
  with:
    app_build_type: maven
```

Override the matched name (still fails if not in inventory):

```yaml
- uses: ravichandrapatel/gha-reusable-actions-workflows/actions/common/build-preprocess@build-preprocess/v1
  with:
    repo: my-app
    app_build_type: maven
    bot_name: github-actions[bot]
```

Local path (this monorepo):

```yaml
- uses: ./actions/common/build-preprocess
```

The nested inventory step always uses `ravichandrapatel/gha-reusable-actions-workflows/actions/common/check-inventory@check-inventory/v1`. Release and promote `check-inventory` first so that tag exists.

## Manual run

```bash
python3 -u actions/common/build-preprocess/preprocess.py --branch main --app-build-type maven
python3 -u actions/common/build-preprocess/preprocess.py --branch feature/foo --app-build-type ng-ui
```

Inventory matching is standalone on the inventory action:

```bash
python3 -u actions/common/check-inventory/checkInventory.py --repo my-app
```

Every build type reads `project.values` and `build.values` from the caller repo root (`GITHUB_WORKSPACE` after checkout, else the current directory). Missing files fail the step.

- Auto-commit (`github.actor` equals `bot_name`, or actor ends with `[bot]` when `bot_name` is empty): `build_stages` is `[]`.
- Otherwise `build_stages` includes `build_and_unit_test`, `owasp`, and `sonar`.
- Branch names are normalized (`refs/heads/` stripped, whitespace trimmed) before stage checks; `main` / `master` / `develop` comparisons are case-insensitive.
- `snapshot_artifact` is included when branch is `develop` and the event is not a pull request.
- `release_artifact` is included for `push` / `workflow_dispatch` on `release/*` or `hotfix/*` (child segment required; bare `release` / `hotfix` do not match). For **ng-ui**, also on `main` / `master`.
- `docker` is included for `push` / `workflow_dispatch` when not a library (`is_library` is not `y`/`Y`) and not a PR.

Example job gate:

```yaml
if: contains(fromJSON(needs.build-preprocess.outputs.build_stages), 'owasp')
```

Approved branches: `main`, `master`, `develop`, `feature/**`, `release/**`, `hotfix/**`, `bugfix/**`.

## Release

Tags after Release Manager: `build-preprocess/v1.0.0` (versioned), `build-preprocess/v1` (stable, after promote).
