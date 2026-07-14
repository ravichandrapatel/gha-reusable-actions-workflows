---
type: Concept
title: SPVS Lifecycle
description: OWASP SPVS Plan/Integrate/Release/Operate stages mapped onto this monorepo's controls.
tags: [github-actions, spvs, lifecycle, concepts]
timestamp: 2026-07-14T17:40:00Z
status: active
---

# SPVS Lifecycle

| Stage | This repository |
| :--- | :--- |
| Plan / Develop | Commit-msg hook; ticket conventional commits; SemVer derivation |
| Integrate | Pre-commit Conftest, Actionlint, Bandit, Shellcheck (change-scoped) |
| Release | Release Manager security job; versioned tags; workflow sync |
| Operate | Promote / rollback; stable `v1` tags; branch protection / App bypass |

Branch protection, signed commits, CODEOWNERS are GitHub settings — not workflow YAML.

## Prompt Card

```text
SPVS stages here: Plan=commit-msg hook + ticket commits; Integrate=pre-commit
Conftest/Actionlint/Bandit/Shellcheck; Release=Release Manager security job + tags;
Operate=promote/rollback stable v1. Branch protection/signed commits/CODEOWNERS
are GitHub settings — never encode them in workflow YAML.
```

## Related

- Standard: [GHA SPVS YAML](/standards/gha-spvs-yaml.md)
- Vendor: [OWASP](/kernel/vendors/owasp.md)
- System: [gha-reusable-actions-workflows](/vault/systems/gha-reusable-actions-workflows.md)
