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
./act-platform/build-images.sh          # or: ./act-platform/bootstrap.sh . --force --build
act --list
```

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
  bootstrap.sh
  build-images.sh
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

Release Manager `mode: release` copies source → live. For local act **without** changing that architecture:

```bash
# Preview
./act-platform/sync-workflows-for-act.sh --dry-run

# Copy source → live (local only; commit only if you intend to ship the sync)
./act-platform/sync-workflows-for-act.sh
# or one component:
./act-platform/sync-workflows-for-act.sh workflows/common/dummy-workflow

# Then
act --list
act -l -W .github/workflows/dummy-workflow.yml
```

Detect drift (CI/local):

```bash
./act-platform/sync-workflows-for-act.sh --check
```

**Composite actions** (`actions/...`) need no sync — reference `./actions/...` from any workflow under `.github/workflows/` (or `act -W path/to/smoke.yml`). Do not run Release Manager via act.

## Tagged method (local)

Consumers use `{safe_name}/v{X.Y.Z}` (and stable `{safe_name}/v1`). Keep those refs in YAML. For act, map them onto this clone instead of cloning GitHub:

```bash
# WSL: Docker Desktop / engine socket (not containerd)
export DOCKER_HOST=unix:///var/run/docker.sock

# 1) Smoke a tagged composite (retry/v1.2.0)
./act-platform/run-tagged-act.sh -W .act/callers/retry-smoke.yml

# 2) Reusable workflow via live copy + tag ng-ui-build-pipeline/v1
./act-platform/run-tagged-act.sh \
  --component workflows/programming/ng-ui-build-pipeline \
  --list
./act-platform/run-tagged-act.sh \
  --component workflows/programming/ng-ui-build-pipeline \
  --dryrun
```

The helper:

- copies `workflows/.../workflow.yml` → `.github/workflows/{name}.yml` (same as Release Manager sync)
- creates **local** tags when missing (`retry/v1.2.0`, `ng-ui-build-pipeline/v1`, …) — not pushed
- passes `act --local-repository owner/repo@ref=$PWD` for every house `@ref`
- if `gha-act-ubuntu:dev` is absent, uses `catthehacker/ubuntu:act-latest`

Throwaway ng-ui app under gitignored `temp/` (any source; stub npm scripts):

```bash
export DOCKER_HOST=unix:///var/run/docker.sock
export GITHUB_TOKEN   # from `gh auth token` so act can fetch setup-node / artifacts
./act-platform/seed-ng-ui-temp.sh
./act-platform/run-tagged-act.sh \
  --component workflows/programming/ng-ui-build-pipeline \
  --app-dir temp/ng-ui-act-fixture \
  --map-dir temp/gha-local-map \
  -e push \
  -j pipeline
```

House inventory is patched only in `temp/gha-local-map` (not the real `inventory.json`). `push` on `main` runs build/owasp/sonar, not docker/publish.

