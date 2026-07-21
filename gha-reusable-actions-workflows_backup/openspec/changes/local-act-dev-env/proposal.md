## Why

Developers need a **plug-and-play** local act platform (Ubuntu + UBI9 runner images) that any GitHub Actions repo can adopt without depending on this monorepo’s actions, policies, or OKF. Lint and Release Manager stay out of scope for act; recipes/e2e come later.

## What Changes

- Add top-level **`act-platform/`** kit (self-contained, zero house deps):
  - `image/ubuntu/Dockerfile` → tag `gha-act-ubuntu:dev`
  - `image/ubi9/Dockerfile` → tag `gha-act-ubi9:dev`
  - `build-images.sh`, `bootstrap.sh`, templates (`.actrc`, `.act/*` examples), standalone `README.md`
- **`bootstrap.sh [TARGET]`** copies the full kit into `$TARGET/act-platform/` and installs root `.actrc` + `.act/` examples + gitignore hints (refuse overwrite unless `--force`). Optional `--build` runs image build.
- Apply bootstrap to **this** monorepo (`.`) so host root is immediately usable.
- OKF playbook `vault/playbooks/run-gha-local-act.md` (host-repo governance: build/verify, FORBIDDEN Release Manager under act, lint via pre-commit; points at kit README for portable usage).
- Host README pointer; playbooks index; `log.md`; `compile`/`lint`.

**Deferred:** per-workflow recipes; GHCR publish.

## Capabilities

### New Capabilities

- `local-act-dev-env`: Portable nektos/act platform kit (`act-platform/`) with dual images (Ubuntu + UBI9), bootstrap into any repo, and host OKF playbook.

### Modified Capabilities

- (none)

## Non-goals

- Coupling the kit to `./actions/*`, Conftest, or OKF.
- Per-workflow act recipes / e2e in this change.
- Release Manager under act; replacing pre-commit.
- OIDC / Environment parity; registry publish (v1 = local tags).

## OKF Prompt Pack

Keywords: `act local platform portable plug-and-play ubuntu ubi9 docker bootstrap`

Cards: bootstrap-spvs-dev-environment, run-gha-local-policy-tests, gha-component-layout, gha-reusable-actions-workflows.

## Grill-me decisions

- Platform first; recipes later; ignore Release Manager; pre-commit = lint.
- Two custom images: Ubuntu + UBI9; labels `ubuntu-latest` / `ubi9`.
- Plug-and-play for **any** repo: no house deps in the kit.
- Kit path: top-level **`act-platform/`**.
- Bootstrap: **full kit copy** into target + root `.actrc`/`.act/`; host repo bootstrapped too.
- Machine-local shared tags; images have no house CLIs.

## Deviations from user request (OKF auto-correct)

None. Host playbook may mention house lint/Release Manager policy; the **kit README** stays generic.

## Impact

- New `act-platform/**`, bootstrapped root `.actrc` / `.act/**`, `.gitignore`, OKF playbook + indexes + `log.md`, host README pointer.
