# Build Preprocess

Composite action that ships `inventory.json` (repo names derived from `*.tfvars`) and matches the caller repo against that list.

## Overview & context

- **Purpose**: Versioned inventory consumed by CI after `tfvars-inventory-sync` writes `inventory.json` and Release Manager tags this action.
- **Scope**: Read-only; does not discover tfvars. Discovery lives in `workflows/common/tfvars-inventory-sync`. Match logic is `checkInventory.py` (stdlib JSON + argparse); the composite launches `python3 -u` with CLI args.
- **Success criteria**: hard mode exits 0 only when the caller is listed; `--soft` exits 0 on a miss with `matched=false`.

## Metadata dashboard

| Attribute | Value |
| --- | --- |
| **Owner / Lead** | DevOps Team |
| **Service Status** | Draft (pre-release) |
| **Repository / Code** | `actions/common/build-preprocess` |
| **Dependencies** | Python 3; composite step installs `requirements.txt` (`defusedxml`) |

## JSON shape

```json
{
  "repos": ["dev", "prod", "staging"]
}
```

## Inputs

| Input | Required | Default | Description |
| --- | --- | --- | --- |
| `inventory_file` | No | `inventory.json` | Basename under this action directory. |
| `repo` | No | `""` | Caller `owner/repo` or repo name to match. Empty uses `GITHUB_REPOSITORY`. |
| `branch` | No | `""` | Branch to allowlist. Empty uses `GITHUB_HEAD_REF` then `GITHUB_REF_NAME`. |
| `app_build_type` | Yes | — | `maven`, `ng-ui`, or `dotnet`. |
| `bot_name` | No | `""` | Actor treated as auto-commit bot. Other stages skip when `github.actor` matches. |
| `soft` | No | `false` | If `true`, inventory or branch miss writes `false` and the step succeeds. |

Match is exact against each inventory entry, the caller’s repo name (`owner/repo` → `repo`), or the last path segment of an inventory `owner/repo` entry.

If the caller is not listed and `soft` is false, the action **exits 1**. With `soft: true` it writes `matched=false` and **exits 0**.

## Outputs

| Output | Description |
| --- | --- |
| `repos` | Compact JSON array of names. |
| `matched` | `true` when listed; `false` on a `--soft` miss. |
| `repo` | Resolved caller repo used for the match. |
| `branch` | Resolved branch used for the allowlist check. |
| `approved` | `true` when the branch matches an approved glob. |
| `stages` | Comma-separated stages to run. |
| `snapshot_artifact` | `true` when not auto-commit, branch is `develop`, and not a pull request. |
| `release_artifact` | `true` when not auto-commit, `push` or `workflow_dispatch` on `release/*` or `hotfix/*`, and not a pull request. |
| `docker` | `true` when not auto-commit, not a library, `push` or `workflow_dispatch`, and not a pull request. |
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
| `cpgbuild_app_origin` | From `build.values`. |
| `checks_type_skip` | `false` when `cpgbuild_app_origin` is empty; `true` otherwise. |
| `is_library` | Maven only: `n` when `project.values` has `TEMPLATE`; `y` when `TEMPLATE` is missing. Empty for other types. |
| `sonar_inclusions` | `-Dsonar.inclusions=<list>` when `CPGBUILD_SONAR_INCLUSION_LIST` is set; empty otherwise. |
| `sonar_exclusions` | `-Dsonar.exclusions=<list>` when `CPGBUILD_SONAR_EXCLUSION_LIST` is set; empty otherwise. |
| `sonar_cli_args` | Joined inclusion and exclusion `-D` arguments. |
| `application_version` | ng-ui: `dependencies.@test/components` when declared (strips npm range markers like `^`/`~`), else `package.json` `version`. Maven: parent `<version>` when parent exists, else project `<version>`. Dotnet: `build/Build.csproj` `<Version>`, else `Directory.Build.props` `<Version>`. |
| `parent_version` | ng-ui: `@test/components` version when declared (range markers stripped). Maven: `parent/version`. Dotnet: `Directory.Build.props` `<Version>`. |
| `project_version` | ng-ui: `package.json` `version`. Maven: project `<version>`. Dotnet: `build/Build.csproj` `<Version>`. |
| `artifact_id` | Maven: `pom.xml` `artifactId`. Dotnet: `build/Build.csproj` `AssemblyName` or filename stem. |
| `name` | From `pom.xml` `name` when `app_build_type` is `maven`. |
| `java_version` | From `pom.xml` `properties/java.version` when `app_build_type` is `maven`. |
| `node_version` | From `package.json` `engines.node`, or `.nvmrc` / `.node-version`, when `app_build_type` is `ng-ui`. |
| `dotnet_version` | From root `global.json` `sdk.version` when `app_build_type` is `dotnet`. |

Dotnet layout is fixed (no `APPLICATION_NAME` → csproj matching): root `Directory.Build.props` + `global.json`, and `build/Build.csproj`.

## Usage

```yaml
- name: Load repo inventory
  id: preprocess
  uses: my-org/gha-reusable-actions-workflows/actions/common/build-preprocess@build-preprocess/v1
```

Override the matched name (still fails if not in inventory):

```yaml
- uses: my-org/gha-reusable-actions-workflows/actions/common/build-preprocess@build-preprocess/v1
  with:
    repo: my-app
    app_build_type: maven
    bot_name: github-actions[bot]
    soft: true
```

Local path (this monorepo):

```yaml
- uses: ./actions/common/build-preprocess
```

## Manual run

```bash
python3 -u actions/common/build-preprocess/checkInventory.py --repo my-app
python3 -u actions/common/build-preprocess/checkInventory.py \
  --action-path actions/common/build-preprocess \
  --inventory-file inventory.json \
  --repo org/my-app \
  --soft
```

Inventory is always `{action-path}/{inventory-file}`. `--action-path` defaults to `ACTION_PATH`, then `GITHUB_ACTION_PATH`, then the script directory. `--inventory-file` is a basename (default `inventory.json`). Omit `--output` to print compact JSON to stdout. Hard miss exits `1`; `--soft` writes `matched=false` / `approved=false` and exits `0`.

```bash
python3 -u actions/common/build-preprocess/preprocess.py --branch main --app-build-type maven
python3 -u actions/common/build-preprocess/preprocess.py --branch feature/foo --app-build-type ng-ui --soft
```

Every build type reads `project.values` and `build.values` from the caller repo root (`GITHUB_WORKSPACE` after checkout, else the current directory). Missing files fail the step.

- Auto-commit (`github.actor` equals `bot_name`, or actor ends with `[bot]` when `bot_name` is empty): `stages` is empty and snapshot/release/docker are `false`.
- `snapshot_artifact`: not auto-commit, branch is `develop`, and the event is not a pull request.
- `release_artifact`: not auto-commit, `push` or `workflow_dispatch` on `release/*` or `hotfix/*`, and not a pull request.
- `docker`: not auto-commit, not a library (`is_library` is not `y`), `push` or `workflow_dispatch`, and not a pull request.
- `build_and_unit_test`, `owasp`, `sonar`: included when not auto-commit.
- `stages` is the comma-separated subset of `BUILD_STAGES` that should run.

Approved branches: `main`, `master`, `develop`, `feature/**`, `release/**`, `hotfix/**`, `bugfix/**`.

## Release

Tags after Release Manager: `build-preprocess/v1.0.0` (versioned), `build-preprocess/v1` (stable, after promote).
