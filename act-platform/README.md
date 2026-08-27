# act-platform

Portable local [nektos/act](https://github.com/nektos/act) platform for **any** GitHub Actions repository.

- Two runner images: **Ubuntu** (`gha-act-ubuntu:dev`) and **UBI9** (`gha-act-ubi9:dev`)
- Bootstrap copies this kit + installs `.actrc` / `.act/` examples into a target repo
- No dependency on a specific monorepo’s actions, policies, or tooling

## Requirements

- Docker
- [act](https://github.com/nektos/act#installation) on your `PATH`
- Network to pull base images (`catthehacker` Ubuntu act image; Red Hat UBI9)

## Quick start (this repo)

```bash
# From repository root (kit already present as ./act-platform)
./act-platform/bootstrap.sh . --force   # install/refresh root .actrc + .act/
./act-platform/build-images.sh          # once per machine (or bootstrap --build)

# One command — auto-syncs workflows/ → .github/workflows/ when stale
./act-platform/act.sh --list
./act-platform/act.sh -W workflows/programming/ng-ui-build-pipeline --list
./act-platform/act.sh -W workflows/programming/ng-ui-build-pipeline -e workflow_dispatch
./act-platform/act.sh -W .act/callers/retry-smoke.yml
```

You no longer need a separate `sync-workflows-for-act.sh` step for normal local runs.

## Use in another repository

```bash
# From a clone that contains act-platform/
./act-platform/bootstrap.sh /path/to/other-repo [--build]

cd /path/to/other-repo
# Images are machine-local tags — build once per machine if skipped --build
./act-platform/build-images.sh
act --list
```

`bootstrap.sh` refuses to overwrite an existing `.actrc` or `.act/` unless you pass `--force`.

## Platform maps (`.actrc`)

| `runs-on` | Image tag |
| --- | --- |
| `ubuntu-latest` | `gha-act-ubuntu:dev` |
| `ubi9` | `gha-act-ubi9:dev` |

Workflows that only use `ubuntu-latest` stay on the Ubuntu image. To exercise UBI9, set `runs-on: ubi9` or override with `act -P …`.

## Secrets / vars

```bash
cp .act/secrets.example .secrets   # gitignored
cp .act/vars.example .vars         # optional; gitignored
```

Use `act -s` / `--secret-file` / `--var-file` as needed for your workflows.

## Layout

```
act-platform/
  act.sh              # preferred entry — auto-sync + tag map + act
  act-lib.sh
  bootstrap.sh
  build-images.sh
  run-tagged-act.sh   # alias → act.sh --tagged
  sync-workflows-for-act.sh
  README.md
  templates/          # source for root .actrc + .act/
  image/ubuntu/
  image/ubi9/
```

## Dual workflow layout (do not collapse)

| Path | Role |
| --- | --- |
| `workflows/{category}/{name}/workflow.yml` | **Source** (author here) |
| `.github/workflows/{name}.yml` | **Live** — what GitHub Actions and **act** execute / callers `uses:` |

Release Manager `mode: release` copies source → live. For local act, **`act.sh` syncs automatically** when files are stale:

```bash
./act-platform/act.sh -W workflows/common/dummy-workflow --list
./act-platform/sync-workflows-for-act.sh --check   # optional drift check in CI
```

Manual sync remains available for inspection:

```bash
./act-platform/sync-workflows-for-act.sh --dry-run
./act-platform/sync-workflows-for-act.sh --if-stale
```

**Composite actions** (`actions/...`) need no sync — reference `./actions/...` from any workflow under `.github/workflows/` (or `act -W path/to/smoke.yml`). Do not run Release Manager via act.

## Tagged method (local)

Consumers use `{safe_name}/v{X.Y.Z}` (and stable `{safe_name}/v1`). **`act.sh` maps those refs to this clone** and creates local tags when missing:

```bash
./act-platform/act.sh -W .act/callers/retry-smoke.yml
./act-platform/act.sh --component workflows/programming/ng-ui-build-pipeline --dryrun
```

`run-tagged-act.sh` is a backward-compatible alias for `act.sh --tagged`.

Throwaway ng-ui app under gitignored `temp/` (any source; stub npm scripts):

```bash
export GITHUB_TOKEN   # from `gh auth token` so act can fetch setup-node / artifacts
./act-platform/seed-ng-ui-temp.sh
./act-platform/act.sh \
  --component workflows/programming/ng-ui-build-pipeline \
  --app-dir temp/ng-ui-act-fixture \
  --map-dir temp/gha-local-map \
  -e push \
  -j pipeline
```

House inventory is patched only in `temp/gha-local-map/actions/common/check-inventory/inventory.json` (not the real catalog file). `push` on `main` runs build/owasp/sonar, not docker/publish.

