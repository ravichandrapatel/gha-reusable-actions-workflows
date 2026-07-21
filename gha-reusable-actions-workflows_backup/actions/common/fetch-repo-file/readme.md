# Fetch Repo File

Download a single file from a GitHub repository using the **Contents API** (authenticated + retries). Prefer this over `raw.githubusercontent.com`, which can intermittently 404 under CDN/ref races.

## Overview

| Attribute | Value |
| --- | --- |
| Path | `actions/common/fetch-repo-file` |
| Runtime | Composite (`bash`, `gh`, `jq`) |
| Auth | `github_token` (default `github.token`) |

## Inputs

| Input | Required | Default | Description |
| --- | --- | --- | --- |
| `repository` | Yes | — | `owner/repo` |
| `path` | Yes | — | File path in that repo |
| `ref` | No | `main` | Branch, tag, or SHA |
| `destination` | Yes | — | Runner path to write |
| `github_token` | No | `${{ github.token }}` | Must have `contents:read` on `repository` |
| `max_attempts` | No | `5` | Retries for transient failures |
| `retry_sleep_seconds` | No | `2` | Initial backoff (doubles, capped at 60s) |

## Outputs

| Output | Description |
| --- | --- |
| `destination` | Path written on the runner |
| `sha` | Blob SHA from the Contents API |

## Usage (same monorepo path ref)

```yaml
- name: Fetch workspace matrix
  uses: ./actions/common/fetch-repo-file
  with:
    repository: my-org/gha-reusable-actions-workflows
    path: matrices/workspaces.json
    ref: main
    destination: ${{ runner.temp }}/workspaces.json
```

Released/consumed form (pin to a release tag SHA when calling across repos):

```yaml
- name: Fetch workspace matrix
  uses: my-org/gha-reusable-actions-workflows/actions/common/fetch-repo-file@<git-sha-or-tag>
  with:
    repository: my-org/gha-reusable-actions-workflows
    path: matrices/workspaces.json
    ref: main
    destination: ${{ runner.temp }}/workspaces.json
    github_token: ${{ secrets.MATRIX_READ_TOKEN }}  # if private / cross-repo
```

---

## Recipe: paste into build-preprocess

Use this inside your external **build-preprocess** composite (or as a workflow step before it) so every app pipeline loads the shared matrix without raw CDN URLs.

```yaml
# --- begin fetch-repo-file recipe (tfvars matrix) ---
- name: Fetch tfvars workspace matrix
  id: matrix
  uses: my-org/gha-reusable-actions-workflows/actions/common/fetch-repo-file@<pin>
  with:
    repository: my-org/gha-reusable-actions-workflows
    path: matrices/workspaces.json
    ref: main
    destination: ${{ github.workspace }}/.cache/workspaces.json
    # Optional when the matrix repo is private or github.token cannot read it:
    # github_token: ${{ secrets.MATRIX_READ_TOKEN }}

- name: Expose matrix path for later steps
  shell: bash
  run: |
    set -euo pipefail
    echo "WORKSPACES_JSON=${{ steps.matrix.outputs.destination }}" >> "${GITHUB_ENV}"
    jq -e '.workspaces | type == "array"' "${{ steps.matrix.outputs.destination }}"
# --- end fetch-repo-file recipe ---
```

Then in build-preprocess logic, read `"${WORKSPACES_JSON}"` (or the `destination` output) instead of curling `raw.githubusercontent.com`.

### Notes for 100+ consumers

- Fetch once per job; pass the local file path into matrix/strategy generation.
- Prefer `ref: main` after the sync PR auto-merges; pin `ref` to a SHA only if you need bit-for-bit freeze.
- Do **not** use `https://raw.githubusercontent.com/...` for this file.

## Related

- Producer: [`workflows/common/tfvars-matrix-sync`](../../../workflows/common/tfvars-matrix-sync/readme.md)
