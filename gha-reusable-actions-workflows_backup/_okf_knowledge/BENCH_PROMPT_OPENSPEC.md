# A/B Benchmark — OKF+OpenSpec vs baseline

> **Purpose**
>
> Benchmark whether the **Aegis + OpenSpec** format (`_okf_knowledge` brain + `/opsx:*` hands) improves engineering outcomes over a baseline model by running two isolated subagents on the same task using the same model.

This prompt tests the fused loop from root [`AGENTS.md`](../AGENTS.md) (`4.9.2+openspec`):

`okf.py pack` → grill-me → `/opsx:propose` → `/opsx:apply` → write-back check → `/opsx:archive`

Copy this file into a Cursor chat (or `@`-mention it), fill every `{{...}}` placeholder, then send.

The parent agent **orchestrates only**. It must **not** implement the task itself.
If a parent-run gate fails, the parent **must** feed the failure back to that arm for fixes and re-score true cost-to-PASS (never treat a draft FAIL as final without the fix loop).

**HTML report must use the checked-in template** — do not hand-author a new layout:

- Template: [`BENCH_REPORT_TEMPLATE.html`](BENCH_REPORT_TEMPLATE.html)
- Renderer: [`render_bench_report.py`](render_bench_report.py)

**Neither Aegis nor OpenSpec is automatic for subagents.** The OKF+OpenSpec arm must be told to use both; the baseline arm must be told to use neither.

**Compliance knowledge isolation (hard):** Org compliance and the **answer-key sources for this task’s `{{PARENT_GATE}}`** MUST NOT appear in the shared task brief or either arm’s initial prompt. The OKF+OpenSpec arm obtains compliance **only** via live `okf.py pack` / `okf.py lookup` / `okf.py card` Prompt Cards. Fill `{{GATE_ANSWER_KEY_GLOBS}}` with the grader paths for **this** gate only (GHA example: `**/policies/**`, `**/*.rego`). Parent runs `{{PARENT_GATE}}` and an isolation audit against those globs.

---

```text
# A/B Benchmark — OKF+OpenSpec vs baseline (parent orchestrator only)

You are the parent. Do **not** implement the task.

## Parent Responsibilities

- Do **not** implement the task.
- Launch **two parallel subagents** (same model).
- Verify outputs independently (re-run {{PARENT_GATE}} yourself).
- **Never put {{PARENT_GATE}}, SPVS, Conftest, Rego paths, or SHA-pin rules into the baseline arm’s initial prompt.**
- **If the parent gate fails for either arm: feed the failure output back to that arm and make it fix the issues** (do not score a draft FAIL as final).
- Re-verify after each fix loop until PASS or remediation budget is exhausted.
- Score **true cost-to-PASS** (initial + all remediation loops).
- Audit **protocol compliance** for the OKF+OpenSpec arm (see below).
- Produce a standalone HTML benchmark report from BENCH_REPORT_TEMPLATE.html.

## Knowledge + lifecycle isolation (mandatory)

| Source | OKF+OpenSpec arm | Baseline arm | Parent |
| --- | --- | --- | --- |
| Shared `{{TASK_DESCRIPTION}}` | Functional only | Functional only | — |
| Aegis / OKF Prompt Cards (`okf.py pack`) | **Required** (only compliance source) | Forbidden | — |
| OpenSpec (`openspec/`, `/opsx:*`, skills) | **Required** (propose→apply→archive) | Forbidden | — |
| grill-me (bench self-resolve) | **Required** before design/specs | Forbidden | — |
| `{{GATE_ANSWER_KEY_GLOBS}}` | **Forbidden** | **Forbidden** | May read to run gate |
| Pins/versions/catalogs | From **cards** only | Public knowledge only | — |
| `{{PARENT_GATE}}` | Not in initial prompt | **Not in initial prompt** | Runs for score |
| Gate failure stdout on resume | Allowed (fix loop) | Allowed (fix loop) | Pastes raw output |

`{{GATE_ANSWER_KEY_GLOBS}}` is **per task / per gate** — not a global AGENTS.md list.

Shared task text and both initial arm prompts MUST be free of org-compliance text and those answer-key paths. Compliance lives on Prompt Cards (dynamic pack/lookup) and/or the parent-only gate.

**OKF discovery budget:** Mandated `okf.py pack --budget 1200` before propose. Mid-apply unknown API/policy: at most **one** extra `okf.py lookup --card` (or `card`) per gap. Then **must continue**. Do not Grep/Read `{{GATE_ANSWER_KEY_GLOBS}}` to prepare for the gate.

## Task Under Test

{{TASK_DESCRIPTION}}

### Functional Requirements (shared — no policy language)

Document functional needs inside `{{TASK_DESCRIPTION}}` (stages, artifact flow, README sections, etc.). Do **not** encode org compliance there.

### Parent-only success gate

Parent verifies with `{{PARENT_GATE}}` (customize per task), plus a functional checklist, for example:

- Required deliverables exist under the arm OUT_DIR
- Documented functional requirements are met
- README / docs completeness (if required by the task)
- **Org / policy gate** (parent only): e.g. Conftest / lint / tests — **do not paste this command or its rules into the baseline initial prompt**
- **Functional CI shape (parent only — GHA pipeline tasks):** FAIL the arm (even if Conftest PASSes) unless `workflow.yml` includes:
  - checkout (`uses:` …`checkout` or `./`…`checkout`)
  - both `upload-artifact` and `download-artifact` for cross-job sharing
  - task-required internal action (e.g. `./actions/security/owasp-dependency-check`)
  - Feed functional FAIL text into the rem loop the same way as `{{PARENT_GATE}}` failure output

### Protocol gate (OKF+OpenSpec arm only — parent audits)

Parent **MUST** verify the fused lifecycle was followed:

1. Evidence of `okf.py pack --budget 1200` (or equivalent pack) **before** OpenSpec design/specs
2. Change exists: `openspec/changes/{{CHANGE_NAME_OKF}}/` (or CLI-resolved planning home)
3. Artifacts present: `proposal.md`, `design.md`, `tasks.md` (schema may add `specs/`)
4. `proposal.md` includes:
   - OKF Prompt Pack note (keywords used)
   - Grill-me decisions (or explicit N/A only if skipped — skipping is a protocol FAIL unless task says so)
   - Deviations from user request (OKF auto-correct) — or `None`
5. `tasks.md` uses checkboxes; high-risk steps use distinct `- [ ] **[MUTATION GATE]** …` lines when applicable
6. Task deliverables written under `{{OUT_DIR_OKF}}` (OpenSpec change dir is planning/state — not a substitute for OUT_DIR)
7. Write-back: if a §1.6 trigger fired → `_okf_knowledge/_inbox/<date>-<slug>.md` exists

Record `protocol_okf_openspec: PASS|FAIL` in parent findings. Gate PASS + protocol FAIL is **not** a clean OKF+OpenSpec win.

### Output paths (must differ)

- OKF+OpenSpec arm writes deliverables to: {{OUT_DIR_OKF}}
- OKF+OpenSpec OpenSpec change name: {{CHANGE_NAME_OKF}}
- Baseline arm writes to: {{OUT_DIR_NO_OKF}}
- Baseline MUST NOT create/edit `openspec/changes/**`

### Model

Use the same model for both Tasks: {{MODEL — or "same as parent"}}

### Deliverables (per arm)

{{DELIVERABLES — e.g. workflow.yml + README.md}}

### Bench mode overrides (both arms must honor)

- **Grill-me (OKF+OpenSpec only):** non-interactive. Self-interview: for each material branch, state question + recommended answer, accept the recommendation, move on. Cap at {{MAX_GRILL_QUESTIONS — e.g. 5}} questions. Explore codebase/cards instead of asking when possible. Summarize decisions before scaffolding design/specs. Do **not** wait for a human.
- **Mutation gates (OKF+OpenSpec only):** still emit `- [ ] **[MUTATION GATE]** …` in `tasks.md` when risk warrants. For this bench, treat gates as **pre-approved** by parent (`BENCH_MUTATION_GATE: APPROVED`) so the arm does not halt waiting for a human — check the box only after documenting the risk in the task text.
- **Archive:** prefer `openspec archive` / `/opsx:archive` after apply when the change is complete; if archive would mutate shared repo state unsafely, leave the change active and note why in JSON `notes` (still run write-back check).

---

## Launch TWO subagents IN ONE TURN (parallel)

### Subagent A (OKF + OpenSpec)

- description: okf-opsx-{{SHORT_NAME}}
- subagent_type: generalPurpose
- prompt:

```
You MUST follow the Aegis + OpenSpec integrated protocol for this run.

Repo root / package root: {{TARGET_REPO}}
Control plane: {{TARGET_REPO}}/AGENTS.md
Brain: {{TARGET_REPO}}/_okf_knowledge/
OpenSpec: {{TARGET_REPO}}/openspec/
Binding summary: {{TARGET_REPO}}/.github/aegis-openspec.md (or .cursor/.claude/.agent sibling)

Must use:
- Aegis (`_okf_knowledge`, okf.py)
- AGENTS.md integrated protocol (pack → grill-me → propose → apply → write-back → archive)
- `okf.py pack --budget 1200` Prompt Cards as the ONLY org/compliance source
- OpenSpec change lifecycle (`openspec` CLI and/or openspec-* / opsx skills)
- grill-me skill in **bench self-resolve** mode (no human wait)

FORBIDDEN (this bench task):
- Freestyle coding without OpenSpec `tasks.md`
- Writing design.md / change specs without a prior OKF pack
- Dumping vault contents (no index.json, context dumps, or full vault/standard bodies)
- Reading or grepping this task’s gate answer keys: {{GATE_ANSWER_KEY_GLOBS}}
- Mining the monorepo or network for pins/versions/rule IDs that should be on cards
- Opening grader sources “to pass the gate” before or while authoring
- Touching the baseline OUT_DIR

Record your start time (`date +%s.%N`) FIRST so you can report wall_s at the end.

BENCH_MUTATION_GATE: APPROVED
(Still list MUTATION GATE tasks when risk warrants; do not block on human approval.)

## Required lifecycle (in order)

1) OKF Prompt Pack (BINDING — before any OpenSpec design/specs):
   cd {{TARGET_REPO}}
   python3 _okf_knowledge/kernel/okf.py pack --budget 1200 "{{LOOKUP_QUERY}}"
   Inject ONLY returned ## Prompt Card text.

2) Grill-me (BINDING — bench self-resolve):
   - Self-interview up to {{MAX_GRILL_QUESTIONS}} material questions.
   - Each: question + recommended answer; accept recommendation; next.
   - Explore codebase/cards instead of asking when possible.
   - Summarize Grill-me decisions (bullets).
   - Do NOT write design.md / specs while grilling.

3) OpenSpec propose:
   - Create change named: {{CHANGE_NAME_OKF}}
   - Produce proposal.md, design.md, tasks.md (and specs if schema requires).
   - proposal.md MUST include:
     - OKF Prompt Pack note (keywords)
     - Grill-me decisions
     - Deviations from user request (OKF auto-correct) or None
   - Plan-time user vs OKF conflict → AUTO-CORRECT design to OKF; note deviation.
   - High-risk steps → distinct `- [ ] **[MUTATION GATE]** …` in tasks.md

4) OpenSpec apply:
   - Implement tasks.md.
   - Write task deliverables ONLY under: {{OUT_DIR_OKF}}
   - Unknown API/policy mid-task → one `okf.py lookup --card --limit 2 "<keywords>"` then continue.
   - Runtime conflict with approved design → HALT Exit Code 1, list Governance Conflicts (do not silently rewrite design). For bench: record the conflict in notes and stop that path; parent may resume.
   - MUTATION GATE tasks: with BENCH_MUTATION_GATE APPROVED, you may check them after documenting risk — do not wait for a human.

5) Write-Back Check (AGENTS.md §1.6) BEFORE final JSON:
   If any trigger fired (lookup gap, live pin/version/catalog, multi-attempt procedure, user correction, root cause) → write Rung 1 to
   `{{TARGET_REPO}}/_okf_knowledge/_inbox/<YYYY-MM-DD>-<slug>.md`
   Inbox write-back is NOT limited to OUT_DIR. Skipping it is a FAIL for this arm.

6) Archive / finalize:
   - Prefer openspec archive for {{CHANGE_NAME_OKF}} when complete.
   - If archive is unsafe for shared repo state, skip archive and explain in notes — write-back still required when triggered.

Then complete this task (functional brief only — compliance comes from cards):
{{TASK_DESCRIPTION}}

Deliverables:
{{DELIVERABLES}}

Write task deliverables ONLY under: {{OUT_DIR_OKF}}
OpenSpec planning artifacts: openspec change {{CHANGE_NAME_OKF}} (CLI default planning home under {{TARGET_REPO}}).

Stop when deliverables meet the functional brief + Prompt Cards + protocol artifacts, or after at most {{MAX_FIX_TURNS}} remediation turn(s).

Do NOT expect a parent policy command in this prompt. Apply card constraints yourself.
If you self-run a lint/gate tool, you may only validate files you wrote under {{OUT_DIR_OKF}} — never open {{GATE_ANSWER_KEY_GLOBS}} to prepare.

Return JSON ONLY (no markdown fence):
{
  "arm": "okf_openspec",
  "wall_s": <float seconds for your whole run>,
  "status": "PASS" | "FAIL",
  "gate_detail": "<short — functional + card + protocol self-check>",
  "change_name": "{{CHANGE_NAME_OKF}}",
  "files_written": ["..."],
  "openspec_artifacts": ["proposal.md", "design.md", "tasks.md"],
  "grill_me": {"questions": <int>, "decisions_summary": "<short>"},
  "pack_keywords": "{{LOOKUP_QUERY}}",
  "write_back": {"triggered": true|false, "rung": 0|1|2, "inbox_path": "<path or null>", "reason": "<short>"},
  "mutation_gates": {"listed": <int>, "approved_via_bench": true},
  "prompt_chars": <int approx chars of prompts/cards you used>,
  "output_chars": <int approx chars of assistant text + file contents written>,
  "round_trips": <int count of your tool-call turns, including remediation>,
  "notes": "<short — mention extra okf lookup, archive skipped, governance HALT, etc.>"
}
```

### Subagent B (Baseline — no OKF, no OpenSpec)

- description: no-okf-no-opsx-{{SHORT_NAME}}
- subagent_type: generalPurpose
- prompt:

```
You MUST NOT use Aegis/OKF or OpenSpec for this run.

Must NOT use:
- AGENTS.md (Aegis protocol)
- _okf_knowledge / okf.py / Prompt Cards / vault / standards from Aegis
- openspec CLI, openspec/changes, /opsx:*, openspec-* skills
- grill-me skill

FORBIDDEN (this bench task):
- Reading {{TARGET_REPO}}/AGENTS.md for protocol
- Reading anything under {{TARGET_REPO}}/_okf_knowledge/
- Running okf.py pack / lookup / card
- Creating or editing openspec/changes/**
- Reading this task’s gate answer keys: {{GATE_ANSWER_KEY_GLOBS}}
- Using org pin lists, rule IDs, or gate commands from memory of this monorepo’s docs (general public knowledge for the domain only)
- Touching the OKF+OpenSpec OUT_DIR or its OpenSpec change

Record your start time (`date +%s.%N`) FIRST so you can report wall_s at the end.

Complete this task from general public knowledge only (no Aegis, no OpenSpec):
{{TASK_DESCRIPTION}}

Deliverables:
{{DELIVERABLES}}

Write outputs ONLY under: {{OUT_DIR_NO_OKF}}
Stop when the deliverables meet the functional brief, or after at most {{MAX_FIX_TURNS}} remediation turn(s).

There is NO policy/compliance gate in this prompt. Do not hunt for Conftest, SPVS, Rego, or OpenSpec templates.

Return JSON ONLY (no markdown fence):
{
  "arm": "baseline",
  "wall_s": <float seconds for your whole run>,
  "status": "PASS" | "FAIL",
  "gate_detail": "<short — functional self-check only>",
  "files_written": ["..."],
  "prompt_chars": <int>,
  "output_chars": <int>,
  "round_trips": <int count of your tool-call turns, including remediation>,
  "notes": "<short>"
}
```

---

## Parent Verification

Re-run `{{PARENT_GATE}}` on both outputs.

Do **not** trust subagent PASS/FAIL.

### Isolation audit (required — uses this task’s globs)

Parent **MUST** audit transcripts against **`{{GATE_ANSWER_KEY_GLOBS}}`**:

Flag OKF+OpenSpec isolation FAIL (even if `{{PARENT_GATE}}` PASSes) if the arm:

- Read/Grep’d any path matching `{{GATE_ANSWER_KEY_GLOBS}}`
- Mined monorepo/network for org pins/rule IDs that should have come from Prompt Cards
- Exceeded the discovery budget (more than one extra `okf.py lookup|card` per mid-apply gap for grader archaeology)
- Skipped pack before design/specs

Baseline isolation FAIL if it touched Aegis/OKF, OpenSpec change trees, or `{{GATE_ANSWER_KEY_GLOBS}}`.

Record `isolation_okf_opsx` / `isolation_base` as PASS|FAIL in parent findings. Gate PASS + isolation FAIL is **not** a clean win.

### Protocol audit (OKF+OpenSpec arm — required)

See **Protocol gate** above. Record `protocol_okf_openspec: PASS|FAIL`.

### Write-back audit (OKF+OpenSpec arm — required)

Parent **MUST** check §1.6 self-learn:

- If the arm reported a lookup gap, live pin/version resolve, or multi-attempt explore → expect `write_back.rung >= 1` and a new file under `{{TARGET_REPO}}/_okf_knowledge/_inbox/`
- Missing Rung 1 when a trigger clearly fired → `write_back_okf: FAIL`
- Baseline arm: `write_back` N/A

### Gate FAIL → fix loop (required — true cost-to-PASS)

This is mandatory. A first-draft FAIL is not a final result.

1. Run `{{PARENT_GATE}}` (and any parent checklist) yourself on each arm’s outputs.
2. If **PASS**: keep that arm’s initial metrics as true totals.
3. If **FAIL**:
   - Do **not** implement the fix in the parent.
   - Resume **only the failing arm** (same model, same isolation rules).
   - Paste the **full raw gate/failure output** into the resume prompt.
   - Baseline remains forbidden from `{{GATE_ANSWER_KEY_GLOBS}}` / Aegis / OpenSpec; it may only use the pasted failure text + its own files.
   - OKF+OpenSpec may update tasks.md / apply fixes under the same change name; still FORBIDDEN from answer-key globs.
   - Instruct the arm to fix the issues and stop when PASS or after at most {{MAX_GATE_FIX_LOOPS — e.g. 2}} parent feedback loops.
   - Parent re-runs `{{PARENT_GATE}}` after each loop.
4. **True metrics** for a remediated arm = initial run + all remediation loops.
5. Report both “draft wall” and “true wall” (and loop count) when remediation occurred.
6. Effectiveness / Efficiency use the **final parent-verified** gate status and **true** wall time.

### Resume prompt template (failing arm only)

Use this as the Task `resume` prompt body (keep arm isolation unchanged):

    Parent verification FAILED the gate. You must fix the issues, then re-check.

    Keep the same arm rules as your original run:
    - OKF+OpenSpec: pack/cards + OpenSpec change {{CHANGE_NAME_OKF}}; still FORBIDDEN from {{GATE_ANSWER_KEY_GLOBS}} and pin/rule mining outside cards.
    - Baseline: still forbidden from Aegis/OKF, OpenSpec, and {{GATE_ANSWER_KEY_GLOBS}}.

    Record remediation start: date +%s.%N

    Write task deliverables ONLY under your original output directory.
    OKF+OpenSpec exception: §1.6 Rung 1 to {{TARGET_REPO}}/_okf_knowledge/_inbox/ is still required if a write-back trigger fired.
    Do not touch the other arm's files.

    Failure output (fix until parent gate passes — use only this text + your files; do not open policy trees):
    ---
    {{GATE_FAILURE_OUTPUT}}
    ---

    After fixing, stop. Max {{MAX_FIX_TURNS}} self-remediation turns this loop.
    Parent will re-run the gate.

    Return JSON ONLY (no markdown fence):
    {
      "arm": "<okf_openspec|baseline>",
      "phase": "gate_remediation",
      "remediation_wall_s": <float>,
      "total_wall_s_including_original": <float>,
      "original_wall_s": <float>,
      "status": "PASS" | "FAIL",
      "gate_detail": "<short>",
      "files_written": ["..."],
      "write_back": {"triggered": true|false, "rung": 0|1|2, "inbox_path": "<path or null>", "reason": "<short>"},
      "prompt_chars": <int this remediation>,
      "output_chars": <int this remediation>,
      "round_trips": <int this remediation>,
      "round_trips_total": <int original + remediation>,
      "notes": "<short>"
    }

---

## Runtime Correctness Audit

Check for (adapt to domain; keep as PASS/FAIL per arm):

- invented actions / APIs / modules
- placeholder actions or masking stubs
- invalid marketplace / registry references
- deprecated actions or APIs
- invalid versions / unpinned mutable refs (when policy requires pins)
- broken SonarQube properties (when applicable)
- broken OWASP import (when applicable)
- cache mistakes
- duplicated builds / duplicated work
- duplicated downloads / redundant I/O
- missing permissions
- excessive permissions
- missing concurrency
- missing timeout
- invalid dependency / `needs` graph
- **card-only isolation** (OKF+OpenSpec did not mine `{{GATE_ANSWER_KEY_GLOBS}}`; baseline did not touch Aegis/OKF/OpenSpec or those globs)
- **lifecycle integrity** (OKF+OpenSpec: pack before design; grill-me decisions recorded; tasks.md drove apply)

Score runtime correctness as % of checks PASSED. Isolation/protocol FAIL may be tracked separately in Parent Findings even when other checks PASS.

---

## Architecture Review (0–5 each)

- Build Once / Reuse Many
- Artifact Strategy
- Cache Strategy
- Dependency Graph
- Parallelization
- Critical Path Optimization
- Runtime Efficiency
- Failure Isolation
- Security Hardening
- Maintainability
- Reusability
- Enterprise Readiness

**Total: 60**

Also score qualitatively (Parent Findings, not the 60-point total):

- Change manageability (OpenSpec proposal/design/tasks quality) — OKF+OpenSpec arm
- Governance fit (mutation gates, OKF auto-correct notes, fail-closed behavior)

---

## Performance Metrics

Collect (true totals after any remediation loops):

**Scored (use for winner / ROI):**

- **True Wall Time** = draft wall + all remediation walls
- **Parent runs to PASS** (1 vs 2+ when gate fix loops run)
- Prompt Characters / Output Characters (true totals across runs)
- Input Tokens (`prompt_chars / 4`) / Output Tokens / Total Tokens
- Estimated Cost (`${{IN_PRICE_PER_M}}/M` in, `${{OUT_PRICE_PER_M}}/M` out unless overridden)
- Files Written / Deliverable Size
- Effectiveness (`1` if parent-verified final PASS else `0`)
- Efficiency (`PASS → 1 / true_wall_s`, else `0`)

**Informational only (winner must be `—`; do not crown Baseline on these):**

- Draft Wall (label gate FAIL / not final when applicable)
- Tool-call turns (show draft+rem breakdown; fewer turns ≠ fewer parent runs)
- Throughput (tokens/sec, chars/sec) — higher ≠ better (rem dumps inflate)
- OpenSpec artifact count / grill-me question count (OKF+OpenSpec only)

---

## Derived Metrics

Calculate:

- Time Saved
- Token Savings
- Cost Savings
- Turn Reduction
- Cache Reuse (qualitative / observed)
- Duplicate Work Eliminated (qualitative / observed)
- Quality Index (0–100)
- Engineering ROI

### Quality Index

- 40% Parent Verification
- 25% Runtime Correctness
- 20% Architecture Review (`arch_total / 60 * 100`)
- 15% Documentation

### Engineering ROI (OKF+OpenSpec vs Baseline)

- Time Saved % (true wall)
- Token Reduction %
- Cost Reduction %
- Parent-run Reduction % (scored); tool-turn counts are informational only
- Architecture Improvement %
- Quality Improvement %
- Runtime Correctness Improvement %
- Estimated Developer Effort Saved
- Protocol overhead note (pack + grill-me + OpenSpec artifacts vs freestyle) — informational

---

## HTML Report

Standalone. Inline CSS. Dark theme. Responsive. No JavaScript.

**Must** render from the template (no custom shells):

```bash
python3 {{TARGET_REPO}}/_okf_knowledge/render_bench_report.py --list-keys
python3 {{TARGET_REPO}}/_okf_knowledge/render_bench_report.py \
  --data {{REPORT_DATA_JSON}} \
  --out {{REPORT_HTML}}
```

Build JSON covering every template placeholder. Prefer structured helpers:
`kpis`, `metrics`, `dashboard`, `architecture`, `runtime`, `parent_findings`,
`benefits_okf`, `benefits_base`, `methodology`, `verdict_lines`.

In narrative fields, label arms **OKF+OpenSpec** and **Baseline** (not bare “OKF” / “no-OKF”).

### Sections (fixed by template — do not reorder/remove)

1. Executive Summary
2. Winner Banner
3. KPI Cards
4. Performance Dashboard
5. Full Metrics Table
6. Architecture Review
7. Runtime Correctness Audit
8. Artifact & Cache Flow
9. Benefits Observed
10. Parent Findings
11. Methodology
12. Final Verdict

### KPI Cards (each shows OKF+OpenSpec / Baseline / Delta / Winner)

**Scored** (`kind: scored` in report JSON):

- True Wall (scored) — show baseline as `draft+rem=true` when rem ran
- Parent Runs (scored)
- Input Tokens / Output Tokens / Total Tokens
- Estimated Cost
- Effectiveness / Efficiency (`1/true_wall`)
- Quality Index / Architecture Score / Runtime Correctness

**Informational** (`kind: info`; winner `—`):

- Tool Turns (info)
- Optional: Throughput (info)
- Optional: Protocol artifacts (info) — OpenSpec file count / grill questions

When a feedback loop ran, dashboard bars **must** stack draft + remediation into true totals. Never present draft-only wall as the Wall KPI winner.

Append both results to `{{RESULTS_JSONL}}`.

---

## Final Verdict

Summarize in **maximum 6 lines**:

- Fastest
- Lowest Tokens
- Lowest Cost
- Highest Quality
- Best Architecture
- Best Runtime Correctness
- Best Enterprise Readiness
- Overall Winner

---

## Hard Rules

- Same model.
- Parallel execution.
- Parent never performs implementation (including gate fixes — subagents fix; parent only re-verifies).
- No context sharing between arms.
- Parent independently verifies via `{{PARENT_GATE}}`, isolation audit, and OKF+OpenSpec protocol audit.
- **Shared task + both initial arm prompts: zero org-compliance text** and no answer-key paths.
- **OKF+OpenSpec compliance source: live Prompt Pack** (`okf.py pack`). **Forbidden** for this task: `{{GATE_ANSWER_KEY_GLOBS}}` and mining pins outside cards.
- **OKF+OpenSpec lifecycle: pack → grill-me (bench self-resolve) → propose → apply → write-back → archive (when safe).**
- **Baseline: no Aegis; no OpenSpec; no `{{GATE_ANSWER_KEY_GLOBS}}`.**
- **Gate FAIL → resume failing arm with failure output and fix until PASS (or budget exhausted); score true totals.**
- **Isolation FAIL or protocol FAIL is reported even when the gate PASSes** (not a clean win).
- HTML report must be self-contained and rendered from `BENCH_REPORT_TEMPLATE.html` via `render_bench_report.py`.
- Do **not** bake domain grader paths into AGENTS.md — keep them in this bench prompt’s placeholders.
```

---

## Placeholder cheat sheet

| Placeholder | Example |
| --- | --- |
| `TARGET_REPO` | `/home/ghost/workspace-latest/gha-reusable-actions-workflows` |
| `TASK_DESCRIPTION` | Functional brief only — **no** SPVS/Conftest/SHA rules |
| `PARENT_GATE` | Parent-only command — **not** pasted into baseline initial prompt |
| `DELIVERABLES` | `workflow.yml` and `README.md` |
| `OUT_DIR_OKF` | `{{TARGET_REPO}}/_ab_bench/okf_openspec/{{SHORT_NAME}}/` |
| `OUT_DIR_NO_OKF` | `{{TARGET_REPO}}/_ab_bench/baseline/{{SHORT_NAME}}/` |
| `CHANGE_NAME_OKF` | `ab-bench-okf-opsx-{{SHORT_NAME}}` |
| `SHORT_NAME` | `ci-pipeline` |
| `LOOKUP_QUERY` | task/domain keywords for **live** `okf.py pack` |
| `GATE_ANSWER_KEY_GLOBS` | per-gate grader paths only, e.g. `**/policies/**` `**/*.rego` |
| `MAX_FIX_TURNS` | `1` |
| `MAX_GATE_FIX_LOOPS` | `2` |
| `MAX_GRILL_QUESTIONS` | `5` |
| `GATE_FAILURE_OUTPUT` | raw stdout/stderr from failed `{{PARENT_GATE}}` |
| `MODEL` | `same as parent` |
| `IN_PRICE_PER_M` / `OUT_PRICE_PER_M` | `3` / `15` |
| `RESULTS_JSONL` | `_ab_bench/results-openspec.jsonl` |
| `REPORT_HTML` | `_ab_bench/{{SHORT_NAME}}-okf-openspec-vs-baseline-report.html` |
| `REPORT_DATA_JSON` | `_ab_bench/{{SHORT_NAME}}-okf-openspec-report-data.json` |

### Example `TASK_DESCRIPTION` (functional only)

```text
Create a reusable GitHub Actions workflow (`on: workflow_call`) with stages:
build-preprocess, build-test-lint, owasp, sonarqube, sonarqube-gate,
publish-to-nexus, docker-build-publish, notification-email.

Requirements: build once; proper needs:; caching; artifact sharing;
OWASP report imported into SonarQube; quality gate blocks publish;
Nexus only after gate; Docker consumes build artifacts; notification if: always();
README covers inputs/outputs/secrets/artifact flow/cache/dependency graph/usage.
```

### Example `PARENT_GATE` (parent only — never in baseline initial prompt)

```text
cd {{TARGET_REPO}} && conftest test --parser yaml -n workflow \
  -p policies/conftest/github_actions/workflow \
  -p policies/conftest/github_actions/lib \
  {{OUT_DIR}}/workflow.yml
```

Also run the **Functional CI shape** checklist on `{{OUT_DIR}}/workflow.yml` (checkout + upload/download-artifact + `./actions/security/owasp-dependency-check` for the example ci-pipeline task). Conftest PASS + functional FAIL → rem loop, not a clean win.

### Example filled identifiers

```text
SHORT_NAME=ci-pipeline
CHANGE_NAME_OKF=ab-bench-okf-opsx-ci-pipeline
LOOKUP_QUERY=github actions reusable workflow_call CI pipeline caching artifacts
OUT_DIR_OKF={{TARGET_REPO}}/_ab_bench/okf_openspec/ci-pipeline/
OUT_DIR_NO_OKF={{TARGET_REPO}}/_ab_bench/baseline/ci-pipeline/
```

---

## What this bench adds vs classic OKF-only (`BENCH_PROMPT.md`)

| Dimension | Classic OKF bench | This OpenSpec+OKF bench |
| --- | --- | --- |
| Compliance source | `lookup --card` | `okf.py pack --budget 1200` (+ mid-apply lookup) |
| Planning | None (write files directly) | OpenSpec propose (`proposal` / `design` / `tasks`) |
| Decision gate | None | grill-me (bench self-resolve) before design |
| Execution | Freestyle under OUT_DIR | `/opsx:apply` driven by `tasks.md` |
| Risk control | Cards only | Cards + `[MUTATION GATE]` tasks (bench pre-approved) |
| Close-out | Write-back | Write-back + archive when safe |
| Baseline | No OKF | No OKF **and** no OpenSpec |

---

## HTML report template

| File | Role |
| --- | --- |
| [`BENCH_REPORT_TEMPLATE.html`](BENCH_REPORT_TEMPLATE.html) | Dark, responsive, no-JS shell with `{{PLACEHOLDER}}` markers + scoring contract |
| [`render_bench_report.py`](render_bench_report.py) | Fills placeholders; KPI `kind: scored|info` |

```bash
python3 _okf_knowledge/render_bench_report.py --list-keys

python3 _okf_knowledge/render_bench_report.py \
  --data _ab_bench/my-task-okf-openspec-report-data.json \
  --out _ab_bench/my-task-okf-openspec-vs-baseline-report.html
```

Set `METHODOLOGY_NOTE_CLASS` to `hidden` when there is no remediation note; otherwise leave it empty and put the note in `METHODOLOGY_NOTE`.

---

## Related

- Integrated protocol: [`../AGENTS.md`](../AGENTS.md) (`INTEGRATED AEGIS + OPENSPEC PROTOCOL`)
- Binding card: [`../.github/aegis-openspec.md`](../.github/aegis-openspec.md)
- OpenSpec project config: [`../openspec/config.yaml`](../openspec/config.yaml)
- Classic OKF-only bench: [`BENCH_PROMPT.md`](BENCH_PROMPT.md)
- Injection rule: [`standards/okf-prompt-injection.md`](standards/okf-prompt-injection.md)
- Report template: [`BENCH_REPORT_TEMPLATE.html`](BENCH_REPORT_TEMPLATE.html)
- Report renderer: [`render_bench_report.py`](render_bench_report.py)
