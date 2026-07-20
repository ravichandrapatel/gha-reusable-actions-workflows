# Git Path Filter

![Git Path Filter logo](logo.png)

A robust, Python-based GitHub Composite Action for detecting file changes in a repository. It compares two git refs (branch, tag, or SHA) and reports which changed files match your YAML-defined pattern groups—so you can run jobs only when relevant paths change.

This action is **reusable**: host it in a central repo and reference it from any workflow (same org or `actions/checkout` + path).

## Overview & context

- **Purpose**: Detect which path groups changed between two refs so workflows can run only the necessary jobs.
- **Scope**: Composite action wrapping a Python detector; supports `pull_request`, `push`, and `workflow_dispatch` (manual or auto ref detection).
- **Primary users**: Platform/DevOps and app teams building monorepo or multi-component CI pipelines.
- **Success criteria**: Correct `changes` / `changes_json` outputs for the event, enabling downstream jobs to gate reliably.

---

## Metadata dashboard

| Attribute | Value |
| --- | --- |
| **Owner / Lead** | @[Name] |
| **Service Status** | Alpha / Beta / Production |
| **Repository / Code** | `devtools-landingzone/actions/git-path-filter` |
| **Dependencies** | Git CLI, Python 3, PyYAML, wcmatch |
| **Slack / Support** | #[Channel-Name] |

## Features

-   **Ref-agnostic**: Works with branches, tags, or SHAs (no `origin/` prefix). Supports `pull_request`, `push`, and `workflow_dispatch`.
-   **Git**: Fetches with `git fetch origin <ref> --depth=1 --no-tags`; uses `git diff --name-status` for change types (A/M/D). **Zero-SHA guard**: when base is all zeros (new-branch push), lists all files in the source ref.
-   **Globbing**: Via [wcmatch](https://pypi.org/project/wcmatch/): `**` (recursive), `*`, `?`, `[...]`, `[!a-z]`, brace expansion `{a,b}`; robust edge cases.
-   **Negation**: `!` prefix with **last-match-wins** (sequential override).
-   **Status**: Git status preserved where useful: `R` (rename), `C` (copy), `T` (type change → M); others normalized to `A`/`M`/`D`.
-   **Change types**: Optional filter by status (`A`, `M`, `D`).
-   **Working directory**: Optional base path; only paths under it are considered; patterns are matched relative to it.
-   **Outputs**: `has_changes`, `files`, `every_file_matches` per group; `_unmatched` for files not in any group.
-   **Dependencies**: PyYAML, wcmatch (pinned in `requirements.txt`). CLI: `--debug` for verbose include/exclude logging.

## Inputs

| Input | Description | Required | Default |
| :--- | :--- | :--- | :--- |
| `source_branch` | Source/head ref (branch name, tag, or SHA). Ignored when `auto_detect_refs` is `'true'`. | **Yes** | — |
| `base_ref_branch` | Base ref to compare against (no `origin/` prefix). Ignored when `auto_detect_refs` is `'true'`. | **Yes** | — |
| `pattern_filter` | YAML string: key → list of globs; `!` = exclude (last match wins). | **Yes** | — |
| `github_token` | Token for `git fetch`. | No | `${{ github.token }}` |
| `change_types` | Comma-separated `A,M,D` to consider only those statuses. | No | `''` |
| `debug` | `true` to log include/exclude reason per file. | No | `false` |
| `working_directory` | Base path; only paths under this dir are considered; matching is relative to it. | No | `''` |
| `auto_detect_refs` | When `'true'`, the action derives `source` / `base` from the GitHub event (`push`, `pull_request`, `workflow_dispatch`). | No | `'false'` |

## Outputs

| Output | Description |
| :--- | :--- |
| `changes` | JSON array of group keys that have changes. e.g. `["backend", "docs"]` |
| `changes_json` | Full object: per group `has_changes`, `files`, `every_file_matches`; plus `_unmatched`. |

### Output structure (`changes_json`)

Paths are POSIX (forward slashes).

```json
{
  "backend": {
    "has_changes": true,
    "files": ["src/api/main.py", "requirements.txt"],
    "every_file_matches": false
  },
  "frontend": {
    "has_changes": false,
    "files": [],
    "every_file_matches": false
  },
  "_unmatched": {
    "has_changes": true,
    "files": ["readme.md"],
    "every_file_matches": false
  }
}
```

---

## How to use in all scenarios

You can either:

- Manually set **source** / **base** refs (existing examples below), or
- Let the action **auto-detect** them per event by setting `auto_detect_refs: 'true'` and only providing `pattern_filter`.

In both cases, always use **checkout with `fetch-depth: 0`** so the workflow has history for diffing.

### 1. Pull request (PR to target branch)

Compare the **PR head** to the **PR base branch**.

| Ref | Value |
| --- | ----- |
| Source | `github.head_ref` (branch name of the PR head) |
| Base | `github.base_ref` (branch the PR targets, e.g. `main`) |

```yaml
on:
  pull_request:
    branches: [main]

jobs:
  detect-changes:
    runs-on: ubuntu-latest
    outputs:
      changes: ${{ steps.changes.outputs.changes }}
      changes_json: ${{ steps.changes.outputs.changes_json }}
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Detect changes (git-path-filter)
        id: changes
        uses: ./devtools-landingzone/actions/git-path-filter
        with:
          auto_detect_refs: 'true'
          pattern_filter: |
            backend:
              - 'src/**/*.py'
            frontend:
              - 'src/**/*.js'
```

### 2. Push (e.g. merge to default branch)

Compare the **merge commit** (current SHA) to the **previous commit** or the default branch (e.g. for the first push to a new branch, or when `before` is missing).

| Ref | Value |
| --- | ----- |
| Source | `github.sha` (commit that triggered the run) |
| Base | `github.event.before` if present, else `github.event.repository.default_branch` |

```yaml
on:
  push:
    branches: [main]

jobs:
  detect-changes:
    runs-on: ubuntu-latest
    outputs:
      changes: ${{ steps.changes.outputs.changes }}
      changes_json: ${{ steps.changes.outputs.changes_json }}
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Set refs for push
        id: refs
        run: |
          echo "source=${{ github.sha }}" >> $GITHUB_OUTPUT
          echo "base=${{ github.event.before || github.event.repository.default_branch }}" >> $GITHUB_OUTPUT

      - name: Detect changes (git-path-filter)
        id: changes
        uses: ./devtools-landingzone/actions/git-path-filter
        with:
          auto_detect_refs: 'true'
          pattern_filter: |
            app:
              - '**/*.tfvars'
```

### 3. Manual run (`workflow_dispatch`)

| Where you run it | Source | Base | Why |
| --- | --- | --- | --- |
| Feature / non-default branch | `github.ref_name` | default branch | Pre-PR: “what would this branch change vs main?” |
| **Default branch (`main`)** | `github.sha` | **resolved first-parent SHA** (plain 40-char) | `main` vs `main` is always empty. Auto-detect resolves `HEAD^` locally — never passes `sha^` into fetch (that fails). |

**Important:** After merging a feature branch into `main`, prefer the **`push`** event (uses `before` → `sha`) for the merge itself. A later `workflow_dispatch` on `main` only sees the **tip commit’s** diff vs its first parent — not the whole feature branch history if more commits landed since.

**Required:** `actions/checkout` with `fetch-depth: 0`. Shallow clones cannot resolve the first parent → `Could not resolve ref`.

```yaml
on:
  workflow_dispatch:

jobs:
  detect-changes:
    runs-on: ubuntu-latest
    outputs:
      changes: ${{ steps.changes.outputs.changes }}
      changes_json: ${{ steps.changes.outputs.changes_json }}
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Detect changes (git-path-filter)
        id: changes
        uses: ./devtools-landingzone/actions/git-path-filter
        with:
          auto_detect_refs: 'true'
          pattern_filter: |
            tfvars:
              - '**/*.tfvars'
```

### 4. One workflow: PR, push, and manual

Use one job and either:

- Set source/base in a previous step based on the event name (existing pattern), or
- Simply set `auto_detect_refs: 'true'` and let the action derive refs.

```yaml
on:
  pull_request:
    branches: [main]
  push:
    branches: [main]
  workflow_dispatch:

jobs:
  detect-changes:
    runs-on: ubuntu-latest
    outputs:
      changes: ${{ steps.changes.outputs.changes }}
      changes_json: ${{ steps.changes.outputs.changes_json }}
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Set refs for detection
        id: refs
        run: |
          # Prefer auto_detect_refs: 'true' instead of this step.
          # Kept as an explicit equivalent of the composite's auto-detect logic.
          if [ "${{ github.event_name }}" = "pull_request" ]; then
            echo "source=${{ github.head_ref }}" >> $GITHUB_OUTPUT
            echo "base=${{ github.base_ref }}" >> $GITHUB_OUTPUT
          elif [ "${{ github.event_name }}" = "push" ]; then
            echo "source=${{ github.sha }}" >> $GITHUB_OUTPUT
            echo "base=${{ github.event.before }}" >> $GITHUB_OUTPUT
          elif [ "${{ github.ref_name }}" = "${{ github.event.repository.default_branch }}" ]; then
            # Resolve parent to a plain SHA — do not pass 'sha^' (fetch cannot use it)
            echo "source=${{ github.sha }}" >> $GITHUB_OUTPUT
            echo "base=$(git rev-parse ${{ github.sha }}^)" >> $GITHUB_OUTPUT
          else
            echo "source=${{ github.ref_name }}" >> $GITHUB_OUTPUT
            echo "base=${{ github.event.repository.default_branch }}" >> $GITHUB_OUTPUT
          fi

      - name: Detect changes (git-path-filter)
        id: changes
        uses: ./devtools-landingzone/actions/git-path-filter
        with:
          auto_detect_refs: 'true'
          pattern_filter: |
            tfvars:
              - '**/*.tfvars'
```

### 5. New-branch push (zero base)

When the base ref is the **zero SHA** (`0{40}`), the action does not run a diff; it lists **all files** in the source ref (e.g. new branch). Your “Set refs” step can pass `github.event.before` as base; GitHub may send the zero SHA for new-branch pushes.

### 6. Downstream jobs: run only when a group has changes

Use `changes_json` and `fromJSON()` in the job `if` condition:

```yaml
  run-backend-tests:
    runs-on: ubuntu-latest
    needs: detect-changes
    if: needs.detect-changes.outputs.changes_json != '' && fromJSON(needs.detect-changes.outputs.changes_json).backend.has_changes
    steps:
      - uses: actions/checkout@v4
      - run: ./run-backend-tests.sh
```

Optional: filter by change type (e.g. only added or modified):

```yaml
      - name: Detect changes (git-path-filter)
        id: changes
        uses: ./devtools-landingzone/actions/git-path-filter
        with:
          auto_detect_refs: 'true'
          change_types: 'A,M'
          pattern_filter: |
            backend:
              - 'src/**/*.py'
```

---

## Full example: monorepo backend/frontend

```yaml
name: CI

on:
  pull_request:
    branches: [main]

jobs:
  detect-changes:
    runs-on: ubuntu-latest
    outputs:
      changes: ${{ steps.changes.outputs.changes }}
      changes_json: ${{ steps.changes.outputs.changes_json }}
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Detect changes
        id: changes
        uses: ./devtools-landingzone/actions/git-path-filter
        with:
          auto_detect_refs: 'true'
          pattern_filter: |
            backend:
              - 'src/api/**/*.py'
              - 'requirements.txt'
            frontend:
              - 'src/webapp/**/*.js'
              - 'package.json'
```

## Test coverage (what we validated)

The implementation in this repo has been validated end-to-end in a dedicated `git-path-filter` test repository across:

- **Ref handling**
  - SHA vs SHA diffs (happy path).
  - `base == source` → no changes.
  - Zero-SHA base (all zeros) → treat all files in source as added.
  - Event-driven ref selection with `auto_detect_refs` for:
    - `push` to feature branches (`feature/*`) vs default branch.
    - `pull_request` (head vs base).
    - `push` to `main` after **squash merge**, **merge commit**, and **rebase & merge**.
    - `workflow_dispatch` on any branch vs default branch.

- **Change types (A/M/D)**
  - Added, modified, and deleted files detected correctly.
  - `change_types: 'A,M'` excludes deletes.
  - `change_types: 'D'` isolates deletes.

- **Pattern engine**
  - `**` globstar with deep nested paths.
  - Brace expansion `{a,b}`.
  - `!` negation with **last-match-wins** semantics.
  - `_unmatched` list for files not matched by any group.
  - `every_file_matches` true when all considered files fall into a group.

- **Working directory**
  - Only paths under `working_directory` are considered.
  - Patterns are matched relative to `working_directory`.

These scenarios are exercised via real Git commits, branches, and GitHub Actions workflows (push, PR, and workflow_dispatch) using the same `main.py` and `action.yml` shipped here.

### Git errors and debug notes

When running this action with `debug: 'true'`, you may see log lines like:

- `[GIT-PATH-FILTER] [DBG-922] Git command failed: fatal: Needed a single revision`
- Other `[DBG-92x]` messages coming from internal `git` calls.

In most cases these are **debug-only breadcrumbs**, not hard failures:

- The action calls `git` in multiple ways (for example, trying different ref formats) and some of those attempts can legitimately fail.
- When `ignore_error=True` is used internally, failures are logged but the action continues and still computes the final `changes_json`.

You should investigate further when:

- The action returns a **non-zero exit code**, or
- `changes_json` is unexpectedly empty or missing expected files.

In those cases, the debug logs (including `[DBG-922]` messages and any `ValueError` about unresolved refs) provide the context needed to fix the underlying ref or fetch configuration—for example:

- Missing `fetch-depth: 0` in `actions/checkout`.
- Wrong ref name (e.g. using `origin/main` instead of `main`).
- Refs not fetched from `origin` before the action runs.

### Example test jobs

```yaml
run-backend-tests:
  runs-on: ubuntu-latest
  needs: detect-changes
  if: needs.detect-changes.outputs.changes_json != '' && fromJSON(needs.detect-changes.outputs.changes_json).backend.has_changes
  steps:
    - uses: actions/checkout@v4
    - run: echo "Backend tests..."

run-frontend-tests:
  runs-on: ubuntu-latest
  needs: detect-changes
  if: needs.detect-changes.outputs.changes_json != '' && fromJSON(needs.detect-changes.outputs.changes_json).frontend.has_changes
  steps:
    - uses: actions/checkout@v4
    - run: echo "Frontend tests..."
```
