# Internal Standards Framework

Welcome to the Internal Standards repository. This directory contains the "Law" of our infrastructure operations.

## The Hierarchy of Truth

In this workspace, **Internal Standards ALWAYS override Official Reference files.**

When GitHub Copilot or any engineer is looking for guidance:
1. Check `rulebooks/internal-standards/` first.
2. If no internal standard exists, refer to the domain-specific official reference folders within `rulebooks/official/` (e.g., `rulebooks/official/github-actions/`, `rulebooks/official/terraform/`, `rulebooks/official/kubernetes/`).
3. If there is a conflict, the internal standard is the source of truth.

## The OKF Standard

Every new internal standard file must follow this template:

```markdown
---
type: internal_standard
tool: [name]
authority: internal_governance
---

# [Standard Name]

## Intent
[Why does this standard exist?]

## Rules
[The specific rules to follow]
```

## The 'Router' Protocol

No one is allowed to search the workspace blindly. To maintain high performance and token efficiency:
- Every domain has a `_router.md` file.
- When you add a new internal standard, you **MUST** update the corresponding domain's `_router.md` with a direct link to your new file.
- Copilot is instructed to use these routers as the primary navigation tool.

## Review Process

Proposing a change to an internal standard:
1. Create a new branch.
2. Make your changes or add new standard files.
3. Update the relevant `_router.md`.
4. Open a Pull Request.
5. **Code Review Requirement:** At least one Lead Platform Engineer must approve the PR before merging.

## Detailed Guide
For a step-by-step walkthrough on creating and managing these "Law" files, see the [Internal Standards Guide](../../docs/07-internal-standards-guide.md).
