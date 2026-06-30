# Chapter 7 — Internal Standards Guide ("The Law")

> **Part V — Governance**

This chapter provides detailed instructions on how to create, update, and manage **Internal Standards** within the `rulebooks/internal-standards/` directory. These standards represent the "Law" of our infrastructure operations and take precedence over all official documentation.

---

## 1. Understanding the Hierarchy of Truth

To ensure consistency and high performance, we follow a strict hierarchy:

1.  **Internal Standards (The Law)**: Located in `rulebooks/internal-standards/`. These are our specific implementation rules, security requirements, and architectural decisions.
2.  **Official Reference (The Dictionary)**: Located in `rulebooks/{domain}/`. This is the raw documentation from tool vendors (GitHub, HashiCorp, etc.).

**Rule**: If an internal standard exists for a topic, it **ALWAYS** overrides the official reference. GitHub Copilot is explicitly instructed to follow this rule via `.github/copilot-instructions.md`.

---

## 2. Creating a New Internal Standard

When a new engineering pattern or mandatory rule is established, it must be documented as an internal standard.

### 2.1 The OKF Template
Every internal standard file MUST use the **OKF (Ops-Knowledge Format)** frontmatter.

```markdown
---
type: internal_standard
tool: [tool-name]
authority: internal_governance
---

# Internal Standard: [Standard Name]

## Intent
[Provide a clear explanation of why this standard exists and what problem it solves.]

## Rules
[List the specific, mandatory rules that must be followed. Use clear "MUST", "SHOULD", and "MUST NOT" language.]

## Examples
[Provide runnable or copy-pasteable examples of compliant implementations.]
```

### 2.2 Directory Placement
All internal standards must be placed in:
`rulebooks/internal-standards/{tool-name}.md`

---

## 3. The 'Router' Protocol

To maintain token efficiency for AI models, we do not allow broad workspace searches. All navigation must be structured.

### 3.1 Updating the Internal Standards Router
Whenever you add a new standard file, you **MUST** update `rulebooks/internal-standards/_router.md`.

1.  Open `rulebooks/internal-standards/_router.md`.
2.  Add a direct link to your new file under the appropriate section.

### 3.2 Updating the Master Router
If you are creating a new domain of knowledge (e.g., a new tool category), you must also ensure the master router at `rulebooks/_router.md` is updated.

---

## 4. Updating an Existing Standard

Standards are living documents. When updating:

1.  **Preserve OKF Frontmatter**: Do not change the `type` or `authority` fields.
2.  **Version Control**: Follow the standard Git workflow (see [Review Process](#5-review-process)).
3.  **Synthesize Points**: If the update is based on external documentation, synthesize the key points into clear rules rather than copying large blocks of text.

---

## 5. Review Process

Internal standards are the "Law" and require high-level oversight.

1.  **Branching**: Create a new branch for your changes (e.g., `feat/new-python-standard`).
2.  **Pull Request**: Open a PR against `main`.
3.  **Approval**: **Code Review Requirement**: At least one **Lead Platform Engineer** must approve the PR.
4.  **Verification**: Ensure the new file passes any automated OKF validation checks.

---

## 6. Checklist for Authors

- [ ] File uses the correct OKF frontmatter.
- [ ] File is placed in `rulebooks/internal-standards/`.
- [ ] `rulebooks/internal-standards/_router.md` has been updated with a link.
- [ ] Language is clear, concise, and mandatory.
- [ ] PR has been opened and assigned to a Lead Platform Engineer.

---

**Navigation:** ← [Release Manager checklist](05-release-checklist.md) | [Contents](README.md)
