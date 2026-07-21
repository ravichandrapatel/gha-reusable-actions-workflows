## Context

Portable act platform: two runner images (Ubuntu, UBI9) shipped as a top-level kit any repo can bootstrap. This monorepo hosts the canonical kit and uses it itself.

## Goals / Non-Goals

**Goals:**

- Self-contained `act-platform/` (Dockerfiles, scripts, templates, README) with **no** dependency on house actions/policies/OKF.
- Tags: `gha-act-ubuntu:dev`, `gha-act-ubi9:dev` (machine-local, shared across repos).
- `bootstrap.sh` → full kit into `$TARGET/act-platform/` + root `.actrc` / `.act/` examples.
- Host OKF playbook for house operators; kit README for any consumer.

**Non-Goals:**

- GHCR publish; recipe batteries; OIDC; house CLIs inside images; Release Manager under act.

## Decisions

1. **Layout**
   ```
   act-platform/
     README.md                 # portable; any-repo
     bootstrap.sh              # ./bootstrap.sh [TARGET] [--force] [--build]
     build-images.sh
     templates/
       actrc
       act/events/README.md
       act/secrets.example
       act/vars.example
       gitignore.snippet
     image/ubuntu/Dockerfile
     image/ubi9/Dockerfile
   ```
   After bootstrap on host (`.`), also present at repo root: `.actrc`, `.act/**` (from templates). Kit remains at `act-platform/` (not duplicated path confusion: bootstrap into `.` installs root files and ensures `act-platform/` is the kit source — when TARGET is this repo, do not nest `act-platform/act-platform`; copy templates only + keep kit in place).

2. **Bootstrap semantics**
   - Args: `TARGET` (default `.`), `--force`, `--build`.
   - If TARGET ≠ kit’s parent: `rsync`/`cp -a` kit → `$TARGET/act-platform/`.
   - Always install templates → `$TARGET/.actrc`, `$TARGET/.act/...`; append gitignore snippet if missing markers.
   - Existing `.actrc` / `.act` without `--force` → exit non-zero with message.
   - `--build` → run `build-images.sh` (from kit path used for that target).

3. **Images**
   - Ubuntu: `FROM catthehacker/ubuntu:act-latest` (thin; labels only; **no** house CLI pins).
   - UBI9: `FROM registry.access.redhat.com/ubi9/ubi` + act prerequisites (git, node, basic utils).
   - `.actrc`: `-P ubuntu-latest=gha-act-ubuntu:dev` and `-P ubi9=gha-act-ubi9:dev`.

4. **Docs split**
   - `act-platform/README.md`: install act, bootstrap any repo, build images, `act --list` — generic.
   - OKF playbook: points to kit; adds host policy (no Release Manager via act; lint = pre-commit/policy tests; recipes follow-on).

5. **Mutation gate** — vault playbook ingest only.

## Risks / Trade-offs

- [UBI + act] → Document verify steps; known gaps vs GitHub-hosted Ubuntu.
- [Red Hat pull] → Network / optional registry login in kit README.
- [Bootstrap into self] → Special-case avoid nested kit copy.

## Migration Plan

1. Land `act-platform/` kit + scripts.
2. Bootstrap this repo; build both tags; `act --list`.
3. Document cross-repo: `./act-platform/bootstrap.sh /path/to/other-repo [--build]`.
4. Follow-on: recipes / optional GHCR.

## Open Questions

None — grill-me closed for this scope.
