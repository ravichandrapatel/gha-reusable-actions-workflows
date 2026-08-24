---
type: Concept
title: Python CLI Args
description: House Python scripts MUST use argparse so they run standalone outside GitHub Actions.
tags: [standard, python, argparse, gha, cli]
timestamp: 2026-08-17T00:00:00Z
status: active
pack_force_when: [python, argparse, checkInventory, composite action, standalone script]
---

# Python CLI Args

House Python (composite helpers and other runnable scripts) **MUST** expose a CLI via `argparse` so the file can be executed individually, not only from a GitHub Actions `run:` block.

## MUST

1. Parse inputs with `argparse` (`--kebab-case` flags). Do not require env vars as the only interface.
2. Composite `action.yml` maps `${{ inputs.* }}` to `env`, then passes those values as CLI args to `python3 -u`.
3. Defaults that enable a local run: `--action-path` (else `ACTION_PATH` / `GITHUB_ACTION_PATH` / script dir) plus a basename; omit `--output` to print JSON/results to stdout.
4. Env fallbacks (`GITHUB_REPOSITORY`) are optional convenience for Actions, never the sole way to pass data.

## FORBIDDEN

1. Logic that can only run when `GITHUB_ACTION_PATH` / `GITHUB_OUTPUT` are set.
2. Reading `${{ inputs.* }}` from Python, or treating undocumented env names as the public API.

## Example

```bash
python3 -u actions/common/build-preprocess/checkInventory.py --repo my-app
```

## Prompt Card

```text
Python helpers MUST use argparse so they run standalone.
action.yml: map inputs via env, then python3 -u script.py --flag "$ENV".
Do not require GITHUB_* env as the only interface; omit --output to print stdout.
FORBIDDEN: env-only scripts; interpolating inputs in Python.
```

# Related

- Standard: [GHA SPVS YAML](/standards/gha-spvs-yaml.md), [Metadata Headers](/standards/metadata-headers.md)
- Playbook: [Author GHA Composite Action](/vault/playbooks/author-gha-composite-action.md)
