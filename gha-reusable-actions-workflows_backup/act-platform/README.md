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

## Notes

- This kit is **platform-only**. Per-workflow event payloads and recipes are optional and repo-specific (see `.act/events/`).
- Image contents intentionally omit org-specific CLIs so the kit stays portable.
- `act --list` works once `.actrc` is installed; `build-images.sh` needs a running Docker daemon (skip image build until Docker is available).
