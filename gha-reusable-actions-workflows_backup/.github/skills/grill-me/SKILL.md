---
name: grill-me
description: >-
  Interview the user relentlessly about a plan or design until reaching shared
  understanding, resolving each branch of the decision tree. Use when user wants
  to stress-test a plan, get grilled on their design, or mentions "grill me".
  Also runs as a mandatory gate during OpenSpec propose (after OKF pack, before
  scaffolding design/specs).
---

Interview me relentlessly about every aspect of this plan until we reach a shared understanding. Walk down each branch of the design tree, resolving dependencies between decisions one-by-one. For each question, provide your recommended answer.

Ask the questions one at a time.

If a question can be answered by exploring the codebase, explore the codebase instead.

## How to run

1. Ground first (if not already done this session):
   ```bash
   python3 _okf_knowledge/kernel/okf.py pack --budget 1200 "<plan keywords>"
   ```
   Prefer OKF Prompt Cards over re-deriving house standards.

2. Build a mental decision tree covering scope, non-goals, interfaces, failure modes, security/risk, rollout, and open unknowns. Resolve dependency order (blockers first).

3. For each unresolved branch:
   - If the codebase or OKF pack already answers it → explore/read and record the answer; do not ask.
   - Otherwise ask **one** question.
   - State your **recommended answer** in the same turn.
   - Wait for the user before asking the next question.

4. Stop when every material branch has an explicit decision (user answer or codebase-derived). Summarize the shared understanding in a short bullet list before handing off (e.g. back to `/opsx:propose` artifact writing).

## Guardrails

- One question per turn — no multi-question dumps.
- Always offer a recommended answer.
- Do not implement code or write OpenSpec `design.md` / change `specs/` while grilling (capture decisions only).
- During `/opsx:propose`, grilling is **mandatory** after OKF pack and **before** scaffolding design/specs.

## Missing knowledge (Aegis ladder)

If Prompt Cards lack required pins/recipes:

1. Explore **task corpus** (`actions/`, `workflows/`, …) — prefer house `./actions/*`.
2. If still missing → **live** official Git/OCI/`gh` (not grader/Rego).
3. **MUST write-back** learned pins/recipes to `_okf_knowledge/_inbox/` (then ingest).

**FORBIDDEN** as an agreed design: “stub `run:` / local staging / promote later” when the task needs real checkout, cross-job `upload-artifact`/`download-artifact`, or a house action.

## CI / reusable workflow grill branches (explore first)

When the plan is multi-job CI / `workflow_call`, resolve (via cards or corpus) before design:

- Checkout present on jobs that need the repo?
- Cross-job artifact names + upload/download (not mkdir-only staging)?
- Which `./actions/*` house composites apply (e.g. OWASP → `./actions/security/owasp-dependency-check`)?
- Pin SHAs from pin-catalog card (or ladder) — never floating `@vN`?
