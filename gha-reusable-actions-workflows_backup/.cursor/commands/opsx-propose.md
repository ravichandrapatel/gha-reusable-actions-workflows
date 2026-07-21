---
name: /opsx-propose
id: opsx-propose
category: Workflow
description: Propose a new change - create it and generate all artifacts in one step
---

Propose a new change - create the change and generate all artifacts in one step.

I'll create a change with artifacts:
- proposal.md (what & why)
- design.md (how)
- tasks.md (implementation steps)

When ready to implement, run /opsx:apply

---


## Aegis + OpenSpec Binding (MUST)

Follow root `AGENTS.md` integrated protocol.

1. **Before** `openspec new change` or writing any `design.md` / change `specs/`, run:
   ```bash
   python3 _okf_knowledge/kernel/okf.py pack --budget 1200 "<task keywords>"
   ```
   Inject **ONLY** returned `## Prompt Card` text. If pack/doctor fails hard (missing brain), HALT and fix OKF first.
2. **Grill-me (BINDING):** After OKF pack and **before** scaffolding design/specs, run the `grill-me` skill — interview one question at a time (with a recommended answer each turn) until shared understanding. Explore the codebase instead of asking when possible. Do not write design/specs while grilling.
3. **Plan-time conflict:** user intent vs OKF standard → AUTO-CORRECT `design.md` to OKF; document under "Deviations from user request (OKF auto-correct)" in `proposal.md`.
4. **High-risk ops** in `tasks.md` → distinct `- [ ] **[MUTATION GATE]** …` checkbox (IAM/secrets/prod, destructive, multi-file contract rewrite).

---

**Store selection:** If the user names a store (a store is a standalone OpenSpec repo registered on this machine) or the work lives in one, run `openspec store list --json` to discover registered store ids, then pass `--store <id>` on the commands that read or write specs and changes (`new change`, `status`, `instructions`, `list`, `show`, `validate`, `archive`, `doctor`, `context`). Other commands do not take the flag. Hints printed by commands already carry the flag; keep it on follow-ups. Without a store, commands act on the nearest local `openspec/` root.

**Input**: The argument after `/opsx:propose` is the change name (kebab-case), OR a description of what the user wants to build.

**Steps**

1. **If no input provided, ask what they want to build**

   Use the **AskUserQuestion tool** (open-ended, no preset options) to ask:
   > "What change do you want to work on? Describe what you want to build or fix."

   From their description, derive a kebab-case name (e.g., "add user authentication" → `add-user-auth`).

   **IMPORTANT**: Do NOT proceed without understanding what the user wants to build.

2. **OKF Prompt Pack (Aegis pre-flight — BINDING)**

   Derive keywords from the change request, then run from repo root:
   ```bash
   python3 _okf_knowledge/kernel/okf.py pack --budget 1200 "<keywords>"
   ```
   Read the Prompt Cards into working memory. Do **not** scaffold OpenSpec artifacts until this succeeds.

3. **Grill-me (BINDING — before design/specs)**

   Follow the `grill-me` skill:
   - Interview relentlessly about the plan/design until shared understanding.
   - Walk each branch of the decision tree; resolve dependencies one-by-one.
   - Ask **one question at a time**; for each, provide your **recommended answer**.
   - If a question can be answered by exploring the codebase (or OKF cards), explore instead of asking.
   - Summarize agreed decisions in bullets when grilling is complete.
   - Do **not** create `design.md` / change `specs/` until grilling finishes.

4. **Create the change directory**

   ```bash
   openspec new change "<name>"
   ```
   This creates a scaffolded change in the planning home resolved by the CLI with `.openspec.yaml`.

5. **Get the artifact build order**
   ```bash
   openspec status --change "<name>" --json
   ```
   Parse the JSON to get:
   - `applyRequires`: array of artifact IDs needed before implementation (e.g., `["tasks"]`)
   - `artifacts`: list of all artifacts with their status and dependencies
   - `planningHome`, `changeRoot`, `artifactPaths`, and `actionContext`: path and scope context. Use these instead of assuming repo-local paths.

6. **Create artifacts in sequence until apply-ready**

   Use the **TodoWrite tool** to track progress through the artifacts.

   Loop through artifacts in dependency order (artifacts with no pending dependencies first):

   a. **For each artifact that is `ready` (dependencies satisfied)**:
      - Get instructions:
        ```bash
        openspec instructions <artifact-id> --change "<name>" --json
        ```
      - The instructions JSON includes:
        - `context`: Project background (constraints for you - do NOT include in output)
        - `rules`: Artifact-specific rules (constraints for you - do NOT include in output)
        - `template`: The structure to use for your output file
        - `instruction`: Schema-specific guidance for this artifact type
        - `resolvedOutputPath`: Resolved path or pattern to write the artifact
        - `dependencies`: Completed artifacts to read for context
      - Read any completed dependency files for context
      - Create the artifact file using `template` as the structure and write it to `resolvedOutputPath`
      - Apply `context` and `rules` as constraints - but do NOT copy them into the file
      - When writing **proposal**: include OKF pack keywords, "Grill-me decisions", and "Deviations from user request (OKF auto-correct)"
      - When writing **design**: align to OKF pack (auto-correct vs user if needed)
      - When writing **tasks**: add `[MUTATION GATE]` rows for high-risk steps
      - Show brief progress: "Created <artifact-id>"

   b. **Continue until all `applyRequires` artifacts are complete**
      - After creating each artifact, re-run `openspec status --change "<name>" --json`
      - Check if every artifact ID in `applyRequires` has `status: "done"` in the artifacts array
      - Stop when all `applyRequires` artifacts are done

   c. **If an artifact requires user input** (unclear context):
      - Use **AskUserQuestion tool** to clarify
      - Then continue with creation

7. **Show final status**
   ```bash
   openspec status --change "<name>"
   ```

**Output**

After completing all artifacts, summarize:
- Change name and location
- List of artifacts created with brief descriptions
- What's ready: "All artifacts created! Ready for implementation."
- Prompt: "Run `/opsx:apply` to start implementing."

**Artifact Creation Guidelines**

- Follow the `instruction` field from `openspec instructions` for each artifact type
- The schema defines what each artifact should contain - follow it
- Read dependency artifacts for context before creating new ones
- Use `template` as the structure for your output file - fill in its sections
- **IMPORTANT**: `context` and `rules` are constraints for YOU, not content for the file
  - Do NOT copy `<context>`, `<rules>`, `<project_context>` blocks into the artifact
  - These guide what you write, but should never appear in the output

**Guardrails**
- NEVER scaffold design/specs without a successful OKF Prompt Pack in this session
- NEVER scaffold design/specs before completing grill-me (shared understanding + decision summary)
- Create ALL artifacts needed for implementation (as defined by schema's `apply.requires`)
- Always read dependency artifacts before creating a new one
- If context is critically unclear, ask the user - but prefer making reasonable decisions to keep momentum
- If a change with that name already exists, ask if user wants to continue it or create a new one
- Verify each artifact file exists after writing before proceeding to next
- OKF standards win at plan time; record auto-corrections in proposal.md
