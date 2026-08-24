---
type: Concept
title: SemVer from Commits
description: How ticket conventional commits map to SemVer bumps for component tags.
tags: [github-actions, semver, commits, concepts]
timestamp: 2026-08-17T02:09:00Z
status: active
---

# SemVer from Commits

Implemented by `actions/common/semver` using `policies/scripts/commit_message_lib.sh`.

## Rules

1. Lookup latest tag `{safe_name}/v*.*.*`; version is the suffix after `/v`.
2. No prior tag: treat current as `0.0.0` then next is **`1.0.0`**.
3. Scan commits since last tag; classify by keyword.
4. Any `feat` -> minor bump; else `fix`/`chore` -> patch; else docs/refactor/perf/test/style -> no bump.
5. Scope is optional and does not gate the bump: `feat:`, `feat():`, `feat({safe_name}):`, and `feat(other):` (e.g. `feat(prbot):`) all count when the keyword is bump-capable.
6. Release fails if no bump-capable commits since last tag.
7. Explicit `version` input on Release Manager bypasses auto-calculation.

## Prompt Card

```text
SemVer from commits since last {safe_name}/v*.*.* tag:
feat -> minor; fix/chore -> patch; docs/refactor/perf/test/style -> no bump.
Scope optional: unscoped, feat(safe_name), or feat(other) e.g. feat(prbot) all count.
No prior tag -> first release is 1.0.0. No bump-capable commits -> release FAILS.
Explicit version input bypasses auto-calculation.
```

## Related

- Standard: [GHA commit subjects](/standards/gha-commit-subjects.md)
- Concept: [Release Manager modes](/vault/concepts/release-manager-modes.md), [Component tagging](/vault/concepts/component-tagging.md)
- System: [gha-reusable-actions-workflows](/vault/systems/gha-reusable-actions-workflows.md)
