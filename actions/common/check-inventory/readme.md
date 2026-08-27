# Check Inventory

Composite action that ships `inventory.json` (repo names derived from `*.tfvars`) and matches the caller repo against that list.

## Overview & context

- **Purpose**: Versioned inventory consumed by CI after `tfvars-inventory-sync` writes `inventory.json` and Release Manager tags this action. `build-preprocess` calls the stable tag `@check-inventory/v1`.
- **Scope**: Read-only; does not discover tfvars. Discovery lives in `workflows/common/tfvars-inventory-sync`. Match logic is `checkInventory.py` (stdlib JSON + argparse); the composite launches `python3 -u` with CLI args.
- **Success criteria**: exits 0 only when the caller is listed; a miss exits 1.

## Metadata dashboard

| Attribute | Value |
| --- | --- |
| **Owner / Lead** | DevOps Team |
| **Service Status** | Draft (pre-release) |
| **Repository / Code** | `actions/common/check-inventory` |
| **Dependencies** | Python 3 stdlib |

## JSON shape

```json
[
  "reponame",
  "repo"
]
```

Top-level JSON array of repo names (no `repos` wrapper).

## Inputs

| Input | Required | Default | Description |
| --- | --- | --- | --- |
| `inventory_file` | No | `inventory.json` | Basename under this action directory. |
| `repo` | No | `""` | Caller `owner/repo` or repo name to match. Empty uses `GITHUB_REPOSITORY`. |

Match is exact against each inventory entry, the caller’s repo name (`owner/repo` → `repo`), or the last path segment of an inventory `owner/repo` entry.

If the caller is not listed, the action **exits 1**.

## Outputs

| Output | Description |
| --- | --- |
| `repos` | Compact JSON array of names. |
| `matched` | `true` when listed. |
| `repo` | Resolved caller repo used for the match. |

## Usage

```yaml
- name: Match caller against inventory
  id: inventory
  uses: ravichandrapatel/gha-reusable-actions-workflows/actions/common/check-inventory@check-inventory/v1
```

Override the matched name (still fails if not in inventory):

```yaml
- uses: ravichandrapatel/gha-reusable-actions-workflows/actions/common/check-inventory@check-inventory/v1
  with:
    repo: my-app
```

Local path (this monorepo):

```yaml
- uses: ./actions/common/check-inventory
```

## Manual run

```bash
python3 -u actions/common/check-inventory/checkInventory.py --repo my-app
python3 -u actions/common/check-inventory/checkInventory.py \
  --action-path actions/common/check-inventory \
  --inventory-file inventory.json \
  --repo org/my-app
```

Inventory is always `{action-path}/{inventory-file}`. `--action-path` defaults to `ACTION_PATH`, then `GITHUB_ACTION_PATH`, then the script directory. `--inventory-file` is a basename (default `inventory.json`). Omit `--output` to print compact JSON to stdout. A miss exits `1`.

## Release

Tags after Release Manager: `check-inventory/v1.0.0` (versioned), `check-inventory/v1` (stable, after promote). Promote this action before `build-preprocess` can resolve `@check-inventory/v1`.
