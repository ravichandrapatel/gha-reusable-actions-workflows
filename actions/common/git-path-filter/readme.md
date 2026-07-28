# Git Path Filter

![Git Path Filter logo](logo.png)

Composite action that compares two git refs and reports which **path groups** changed (YAML globs, `**`, `!` last-match-wins). Use it to gate CI jobs so only affected components run.

**Path in this repo:** `actions/common/git-path-filter`  
**E2E workflow:** [`.github/workflows/git-path-filter-e2e.yml`](../../../.github/workflows/git-path-filter-e2e.yml)  
**Latest real-world results:** [`E2E_RESULTS_2026-07-20.md`](E2E_RESULTS_2026-07-20.md)

---

## Quick start (recommended)

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
    permissions:
      contents: read
      pull-requests: read
    outputs:
      changes: ${{ steps.gpf.outputs.changes }}
      changes_json: ${{ steps.gpf.outputs.changes_json }}
    steps:
      # REQUIRED: full history (manual/main and sha^ resolve need parents)
      - uses: actions/checkout@9c091bb21b7c1c1d1991bb908d89e4e9dddfe3e0 # v4
        with:
          fetch-depth: 0

      - name: Detect path changes
        id: gpf
        uses: ./actions/common/git-path-filter
        with:
          auto_detect_refs: 'true'
          debug: 'false'
          pattern_filter: |
            backend:
              - 'src/api/**'
              - 'requirements.txt'
            frontend:
              - 'src/web/**'
              - 'package.json'
            docs:
              - '**/*.md'
              - '!**/node_modules/**'

  backend:
    needs: detect-changes
    if: >-
      needs.detect-changes.outputs.changes_json != '' &&
      fromJSON(needs.detect-changes.outputs.changes_json).backend.has_changes
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - uses: actions/checkout@9c091bb21b7c1c1d1991bb908d89e4e9dddfe3e0
      - run: echo "Run backend CI"
```

With `auto_detect_refs: 'true'` you do **not** need to pass `source_branch` / `base_ref_branch` — the action picks them from the GitHub event.

---

## Choose your scenario

| Your trigger | Where you run | What gets compared | Set this |
| --- | --- | --- | --- |
| **Pull request** | PR → `main` | PR head branch → PR base branch | `auto_detect_refs: 'true'` |
| **Push to feature** | `feature/*` | feature branch → default branch | `auto_detect_refs: 'true'` |
| **Push to `main`** (after merge) | `main` | `github.sha` → `github.event.before` (or first parent) | `auto_detect_refs: 'true'` |
| **Manual run on feature** | Actions UI → feature branch | feature → default branch | `auto_detect_refs: 'true'` |
| **Manual run on `main`** | Actions UI → `main` | tip SHA → **first-parent SHA** (not `main`↔`main`) | `auto_detect_refs: 'true'` + `fetch-depth: 0` |
| **Custom / tags / release** | any | whatever you pass | set `source_branch` + `base_ref_branch` explicitly |
| **Brand-new branch push** | first push | all files in source (zero-SHA base) | auto or pass `before` (may be `0{40}`) |

### Hard requirements

1. **`fetch-depth: 0`** on `actions/checkout` (full history).
2. Prefer **`auto_detect_refs: 'true'`** for PR / push / `workflow_dispatch`.
3. Do **not** pass `origin/` prefixes (`main`, not `origin/main`).
4. After a merge, the **`push`** event is the best signal for “what just landed”; a later manual run on `main` only diffs the **tip commit** vs its first parent.

---

## How `auto_detect_refs` picks refs

| `github.event_name` | Source | Base |
| --- | --- | --- |
| `pull_request` | `github.head_ref` | `github.base_ref` |
| `push` to default/`main` | `github.sha` | `github.event.before` if set and non-zero; else first parent of `sha` (plain 40-char SHA) |
| `push` to other branch | branch name | default branch |
| `workflow_dispatch` on default/`main` | `github.sha` | first parent of `sha` (plain SHA — never raw `sha^` into fetch) |
| `workflow_dispatch` on other branch | `github.ref_name` | default branch |

Outputs `source_ref` / `base_ref` show what was actually used (useful in logs / summaries).

---

## Scenario guides

### 1. Pull request

**Use when:** PR opened/updated against `main` (or other base).

```yaml
on:
  pull_request:
    branches: [main]

jobs:
  detect-changes:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: read
    steps:
      - uses: actions/checkout@9c091bb21b7c1c1d1991bb908d89e4e9dddfe3e0
        with:
          fetch-depth: 0
      - id: gpf
        uses: ./actions/common/git-path-filter
        with:
          auto_detect_refs: 'true'
          pattern_filter: |
            app:
              - 'apps/my-service/**'
```

Compares **PR head → PR base** (full PR file set).

---

### 2. Push to `main` (after squash / rebase / merge commit)

**Use when:** code lands on `main` via any GitHub merge method.

```yaml
on:
  push:
    branches: [main]

jobs:
  detect-changes:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - uses: actions/checkout@9c091bb21b7c1c1d1991bb908d89e4e9dddfe3e0
        with:
          fetch-depth: 0
      - id: gpf
        uses: ./actions/common/git-path-filter
        with:
          auto_detect_refs: 'true'
          pattern_filter: |
            app:
              - 'apps/**'
```

| Merge method on GitHub | Tip shape | What push compares |
| --- | --- | --- |
| **Squash** | 1 parent | `sha` → `before` (previous `main`) |
| **Rebase and merge** | 1 parent | `sha` → `before` |
| **Merge commit** | 2 parents | `sha` → `before` (pre-merge `main`) |

All three were validated live — see [Merge strategies](#merge-strategies-validated) below.

---

### 3. Push to a feature branch

**Use when:** pushing to `feature/*` before or without a PR.

```yaml
on:
  push:
    branches: ['feature/**']

# auto_detect: source = feature branch name, base = default branch
```

Shows “what would this branch change vs `main`?”.

---

### 4. Manual run (`workflow_dispatch`)

#### 4a. On a feature branch

Actions → workflow → **Run workflow** → select **feature** branch.

- Source: feature branch  
- Base: default branch (`main`)  
- Good for dry-runs before opening a PR.

#### 4b. On `main` (post-merge re-run)

Actions → workflow → **Run workflow** → select **`main`**.

- Source: current tip SHA  
- Base: **first-parent SHA** (resolved to a plain 40-char hash)  
- Sees files from the **tip commit** (e.g. the merge/squash commit), not an empty `main`↔`main` diff.

```yaml
on:
  workflow_dispatch:

jobs:
  detect-changes:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - uses: actions/checkout@9c091bb21b7c1c1d1991bb908d89e4e9dddfe3e0
        with:
          fetch-depth: 0   # mandatory for first-parent resolve
      - id: gpf
        uses: ./actions/common/git-path-filter
        with:
          auto_detect_refs: 'true'
          debug: 'true'    # optional while verifying
          pattern_filter: |
            app:
              - 'apps/**'
```

**Tip:** Prefer the automatic **`push`** after merge for production gating; use manual on `main` for re-runs / debugging.

---

### 5. Combined workflow (PR + push + manual)

One job, one `auto_detect_refs: 'true'` — covers all three events:

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
    permissions:
      contents: read
      pull-requests: read
    outputs:
      changes_json: ${{ steps.gpf.outputs.changes_json }}
    steps:
      - uses: actions/checkout@9c091bb21b7c1c1d1991bb908d89e4e9dddfe3e0
        with:
          fetch-depth: 0
      - id: gpf
        uses: ./actions/common/git-path-filter
        with:
          auto_detect_refs: 'true'
          pattern_filter: |
            backend:
              - 'src/api/**'
            frontend:
              - 'src/web/**'
```

You do **not** need a hand-written “Set refs” step when `auto_detect_refs` is true.

---

### 6. Explicit refs (no auto-detect)

**Use when:** tags, releases, comparing arbitrary SHAs, or local/debug.

```yaml
- id: gpf
  uses: ./actions/common/git-path-filter
  with:
    source_branch: ${{ github.sha }}
    base_ref_branch: ${{ github.event.before }}
    # or: base_ref_branch: 'v1.2.0'
    pattern_filter: |
      charts:
        - 'deploy/helm/**'
```

| Goal | `source_branch` | `base_ref_branch` |
| --- | --- | --- |
| This commit vs previous | `${{ github.sha }}` | `${{ github.event.before }}` |
| Tag vs previous tag | `v1.3.0` | `v1.2.0` |
| Empty (smoke) | same SHA | same SHA → `changes: []` |
| New branch (all files) | branch or SHA | `0000000000000000000000000000000000000000` |

---

### 7. New-branch push (zero SHA)

GitHub may set `github.event.before` to forty zeros. The action treats that as “no base” and lists **all files** in the source ref as added (`A`).

---

### 8. Filter by change type (A / M / D)

```yaml
with:
  auto_detect_refs: 'true'
  change_types: 'A,M'   # ignore deletes
  pattern_filter: |
    app:
      - 'apps/**'
```

| Value | Meaning |
| --- | --- |
| `A` | Added |
| `M` | Modified (also type-change) |
| `D` | Deleted |
| `A,M` | Added + modified only |

---

### 9. Working directory (monorepo slice)

Only consider paths under a subdirectory; patterns match **relative** to that dir:

```yaml
with:
  auto_detect_refs: 'true'
  working_directory: 'services/payments'
  pattern_filter: |
    code:
      - '**/*.py'
    charts:
      - 'helm/**'
```

A change only under `.github/workflows/` will **not** match when `working_directory` is `services/payments` (by design).

---

### 10. Negation (`!`) — last match wins

Patterns are applied in order; the **last** matching pattern decides include/exclude:

```yaml
pattern_filter: |
  code:
    - 'src/**'
    - '!src/**/*.md'
    - '!src/**/testdata/**'
```

---

### 11. Downstream job gating

```yaml
jobs:
  detect-changes:
    # ... produces outputs.changes_json

  deploy-frontend:
    needs: detect-changes
    if: >-
      needs.detect-changes.outputs.changes_json != '' &&
      fromJSON(needs.detect-changes.outputs.changes_json).frontend.has_changes
    runs-on: ubuntu-latest
    steps:
      - run: echo "frontend changed"
```

`changes` is a JSON array of group names that have changes, e.g. `["backend","docs"]`.

---

## Inputs

| Input | Required | Default | Description |
| --- | :---: | --- | --- |
| `pattern_filter` | **Yes** | — | YAML map: group → list of globs (`!` = exclude) |
| `auto_detect_refs` | No | `false` | Derive source/base from the GitHub event |
| `source_branch` | If auto_detect is false | `''` | Head ref (branch, tag, or SHA) |
| `base_ref_branch` | If auto_detect is false | `''` | Base ref (no `origin/` prefix) |
| `github_token` | No | `${{ github.token }}` | Token for git fetch |
| `change_types` | No | `''` | `A`, `M`, `D` filter (comma-separated) |
| `working_directory` | No | `''` | Scope + relative pattern root |
| `debug` | No | `false` | Per-file include/exclude logs |

## Outputs

| Output | Description |
| --- | --- |
| `changes` | JSON array of group keys with changes, e.g. `["backend"]` |
| `changes_json` | Full map: per group `has_changes`, `files`, `every_file_matches`; plus `_unmatched` |
| `source_ref` | Resolved source actually used |
| `base_ref` | Resolved base actually used |

### `changes_json` shape

```json
{
  "backend": {
    "has_changes": true,
    "files": ["src/api/main.py"],
    "every_file_matches": false
  },
  "frontend": {
    "has_changes": false,
    "files": [],
    "every_file_matches": false
  },
  "_unmatched": {
    "has_changes": true,
    "files": ["README.md"],
    "every_file_matches": false
  }
}
```

---

## Features

- Ref-agnostic: branch, tag, or SHA  
- `pull_request` / `push` / `workflow_dispatch` via `auto_detect_refs`  
- Globstar `**`, braces `{a,b}`, negation `!` (last-match-wins)  
- Optional `change_types` and `working_directory`  
- Zero-SHA base → list all files in source as added  
- Parent syntax (`sha^`) resolved safely (no destructive shallow fetch)

---

## Merge strategies validated

Real PRs into `main` (2026-07-20), each followed by **push e2e** + **`workflow_dispatch` on `main`**:

| Merge type | PR | Push | Manual on `main` |
| --- | --- | --- | --- |
| Squash | [#10](https://github.com/ravichandrapatel/gha-reusable-actions-workflows/pull/10) | [PASS](https://github.com/ravichandrapatel/gha-reusable-actions-workflows/actions/runs/29736621988) | [PASS](https://github.com/ravichandrapatel/gha-reusable-actions-workflows/actions/runs/29736643541) |
| Rebase and merge | [#11](https://github.com/ravichandrapatel/gha-reusable-actions-workflows/pull/11) | [PASS](https://github.com/ravichandrapatel/gha-reusable-actions-workflows/actions/runs/29736694806) | [PASS](https://github.com/ravichandrapatel/gha-reusable-actions-workflows/actions/runs/29736716796) |
| Merge commit | [#12](https://github.com/ravichandrapatel/gha-reusable-actions-workflows/pull/12) | [PASS](https://github.com/ravichandrapatel/gha-reusable-actions-workflows/actions/runs/29736763123) | [PASS](https://github.com/ravichandrapatel/gha-reusable-actions-workflows/actions/runs/29736783883) |

On merge commits, manual dispatch uses **first parent** as base (pre-merge `main`). Full tables: [`E2E_RESULTS_2026-07-20.md`](E2E_RESULTS_2026-07-20.md).

---

## Troubleshooting

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| `Could not resolve ref` / unexpected error | Shallow checkout | `fetch-depth: 0` |
| Manual on `main` → no changes | Comparing `main`↔`main` (old behavior) | Use current action + `auto_detect_refs: 'true'` |
| Manual on `main` misses whole feature | Tip-only diff | Prefer **push** event for the merge; or compare explicit SHAs |
| `working_directory` shows 0 hits | Changes outside that dir | Expected; widen `working_directory` or patterns |
| Want verbose logs | — | `debug: 'true'` |

`[DBG-922] Git command failed: …` in debug mode is often an ignored probe (alternate ref form), not a hard failure — investigate only when the step exits non-zero.

### Re-run e2e with `gh`

```bash
gh workflow run git-path-filter-e2e.yml --ref main
gh run watch --exit-status
gh run list --workflow=git-path-filter-e2e.yml --branch main --limit 5
```

---

## Metadata

| Attribute | Value |
| --- | --- |
| **Owner / Lead** | Platform / DevOps |
| **Repository path** | `actions/common/git-path-filter` |
| **Dependencies** | Git, Python 3, PyYAML, wcmatch (`requirements.txt`) |
| **E2E** | `.github/workflows/git-path-filter-e2e.yml` |
