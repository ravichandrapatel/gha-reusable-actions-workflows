## ADDED Requirements

### Requirement: Portable act-platform kit

The repository MUST provide a top-level `act-platform/` kit that is usable with any GitHub Actions repository and MUST NOT require that consumer’s adoption of house actions, Conftest policies, or OKF.

#### Scenario: Kit is self-contained

- **WHEN** a developer inspects `act-platform/`
- **THEN** it includes Ubuntu and UBI9 Dockerfiles, `build-images.sh`, `bootstrap.sh`, templates, and a standalone README
- **AND** the kit README documents usage without referencing house Release Manager or Conftest as prerequisites

### Requirement: Bootstrap installs full kit into any target repo

`act-platform/bootstrap.sh` MUST copy the full kit into `$TARGET/act-platform/` (when the target is not already the kit host) and install root `.actrc` plus `.act/` examples from templates, refusing to overwrite existing root act files unless `--force` is passed.

#### Scenario: Bootstrap another repo

- **WHEN** a developer runs `./act-platform/bootstrap.sh /path/to/other-repo`
- **THEN** that path contains `act-platform/` and root `.actrc` mapping `ubuntu-latest` and `ubi9` to the custom image tags
- **AND** real secret files are not created (examples only)

#### Scenario: Bootstrap refuses clobber

- **WHEN** the target already has `.actrc` and the developer runs bootstrap without `--force`
- **THEN** the command exits non-zero and leaves existing files unchanged

### Requirement: Dual custom images Ubuntu and UBI9

The kit MUST provide buildable Dockerfiles producing `gha-act-ubuntu:dev` and `gha-act-ubi9:dev` with no Release Manager configuration and no house-specific CLI pins required inside the images.

#### Scenario: Both images build locally

- **WHEN** a developer runs the kit `build-images.sh` with Docker available
- **THEN** both tags exist locally
- **AND** `.actrc` maps `ubuntu-latest` → Ubuntu image and `ubi9` → UBI9 image

### Requirement: Host playbook for local act platform

The host repository MUST provide an OKF playbook that points at `act-platform/`, covers build/verify (`act --list`), states recipes are follow-on, states lint remains pre-commit/policy tests, and states Release Manager MUST NOT be run via act.

#### Scenario: Playbook covers portable kit and house policy

- **WHEN** a host developer reads the local-act playbook
- **THEN** it references bootstrap/build from `act-platform/`
- **AND** it forbids Release Manager under act while keeping kit consumers free of that dependency
