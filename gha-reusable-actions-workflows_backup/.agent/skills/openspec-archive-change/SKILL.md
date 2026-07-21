---
name: openspec-archive-change
description: Archive a completed change in the experimental workflow. Use when the user wants to finalize and archive a change after implementation is complete.
allowed-tools: Bash(openspec:*), Bash(python3 *)
license: MIT
compatibility: Requires openspec CLI and repo-root Aegis OKF (`_okf_knowledge/`).
metadata:
  author: openspec
  version: "1.2"
  generatedBy: "1.6.0"
---

Archive a completed change in the experimental workflow.

## Aegis + OpenSpec Binding (MUST)

Follow root [`AGENTS.md`](../../../AGENTS.md) integrated protocol.

**Write-Back Check (BINDING — before archive or final sync):** Always write Rung 1 to `_okf_knowledge/_inbox/<YYYY-MM-DD>-<change-name>-note.md` (what shipped, evidence grade, suggested destination) **before** moving the change to archive. **FORBIDDEN** to skip with “no trigger.” Rung 1 is Mutation-Gate-exempt (inbox only). Rung 2 INGEST only when durable + destination clear **and** the maintain playbook post-change checklist completes in this close-out (`compile`+`lint` → 0 errors); otherwise leave Rung 1 with `MAINTAIN later`. **FORBIDDEN** freestyle vault/standards edits under write-back. Zone 5 code-structure facts are not vault candidates.

**Store selection:** If the user names a store (a store is a standalone OpenSpec repo registered on this machine) or the work lives in one, run `openspec store list --json` to discover registered store ids, then pass `--store <id>` on the commands that read or write specs and changes (`new change`, `status`, `instructions`, `list`, `show`, `validate`, `archive`, `doctor`, `context`). Other commands do not take the flag. Hints printed by commands already carry the flag; keep it on follow-ups. Without a store, commands act on the nearest local `openspec/` root.

**Input**: Optionally specify a change name. If omitted, check if it can be inferred from conversation context. If vague or ambiguous you MUST prompt for available changes.

**Steps**

1. **If no change name provided, prompt for selection**

   Run `openspec list --json` to get available changes. Use the **AskUserQuestion tool** to let the user select.

   Show only active changes (not already archived).
   Include the schema used for each change if available.

   **IMPORTANT**: Do NOT guess or auto-select a change. Always let the user choose.

2. **Check artifact completion status**

   Run `openspec status --change "<name>" --json` to check artifact completion.

   Parse the JSON to understand:
   - `schemaName`: The workflow being used
   - `planningHome`, `changeRoot`, `artifactPaths`, and `actionContext`: path and scope context
   - `artifacts`: List of artifacts with their status (`done` or other)

   **If any artifacts are not `done`:**
   - Display warning listing incomplete artifacts
   - Use **AskUserQuestion tool** to confirm user wants to proceed
   - Proceed if user confirms

3. **Check task completion status**

   Read the tasks file (typically `tasks.md`) to check for incomplete tasks.

   Count tasks marked with `- [ ]` (incomplete) vs `- [x]` (complete).

   **If incomplete tasks found:**
   - Display warning showing count of incomplete tasks
   - Use **AskUserQuestion tool** to confirm user wants to proceed
   - Proceed if user confirms

   **If no tasks file exists:** Proceed without task-related warning.

4. **Assess delta spec sync state**

   Use `artifactPaths.specs.existingOutputPaths` from status JSON to check for delta specs. If none exist, proceed without sync prompt.

   **If delta specs exist:**
   - Compare each delta spec with its corresponding main spec at `openspec/specs/<capability>/spec.md`
   - Determine what changes would be applied (adds, modifications, removals, renames)
   - Show a combined summary before prompting

   **Prompt options:**
   - If changes needed: "Sync now (recommended)", "Archive without syncing"
   - If already synced: "Archive now", "Sync anyway", "Cancel"

   If user chooses sync, use Task tool (subagent_type: "general-purpose", prompt: "Use Skill tool to invoke openspec-sync-specs for change '<name>'. Delta spec analysis: <include the analyzed delta spec summary>"). Proceed to archive regardless of choice.

5. **Aegis Write-Back Check (BINDING — before archive)**

   **Always** write `_okf_knowledge/_inbox/<YYYY-MM-DD>-<change-name>-note.md` with:
   - change name
   - 1–5 bullets of what shipped / durable outcomes
   - evidence grade (`verified` | `observed` | `provided` | `inferred`)
   - suggested vault destination or `MAINTAIN later` / `no durable vault candidate`

   If durable + destination clear (pin catalog, CI recipe, standard, playbook) **and** the maintain post-change checklist can complete in this close-out: Path C INGEST per maintain playbook § OpenSpec archive write-back; run `okf.py compile` then `okf.py lint` (0 errors) before archive move. Otherwise leave Rung 1 as `MAINTAIN later` — do **not** partially edit vault/standards.

   Do **not** skip this step. Do **not** invent Zone 5 code-structure Concepts.

6. **Perform the archive**

   Create an `archive` directory under `planningHome.changesDir` if it doesn't exist:
   ```bash
   mkdir -p "<planningHome.changesDir>/archive"
   ```

   Generate target name using current date: `YYYY-MM-DD-<change-name>`

   **Check if target already exists:**
   - If yes: Fail with error, suggest renaming existing archive or using different date
   - If no: Move `changeRoot` to the archive directory

   ```bash
   mv "<changeRoot>" "<planningHome.changesDir>/archive/YYYY-MM-DD-<name>"
   ```

7. **Display summary**

   Show archive completion summary including:
   - Change name
   - Schema that was used
   - Archive location
   - Whether specs were synced (if applicable)
   - Write-back: path of Rung 1 note; Rung 2 ingest yes/no
   - Note about any warnings (incomplete artifacts/tasks)

**Output On Success**

```
## Archive Complete

**Change:** <change-name>
**Schema:** <schema-name>
**Archived to:** the archive path derived from `planningHome.changesDir`/YYYY-MM-DD-<name>/
**Specs:** ✓ Synced to main specs (or "No delta specs" or "Sync skipped")
**Write-back:** Rung 1 `_okf_knowledge/_inbox/<note>` · Rung 2: <ingested|deferred|none durable>

All artifacts complete. All tasks complete.
```

**Guardrails**
- Always write Rung 1 `_inbox/` note before archive move — never “skip, no trigger”; Rung 2 only via full maintain checklist (else defer)
- Always prompt for change selection if not provided
- Use artifact graph (openspec status --json) for completion checking
- Don't block archive on warnings - just inform and confirm
- Preserve .openspec.yaml when moving to archive (it moves with the directory)
- Show clear summary (include write-back note path and whether ingest ran)
- If sync is requested, use openspec-sync-specs approach (agent-driven); write-back still runs before final archive move
- If delta specs exist, always run the sync assessment and show the combined summary before prompting
