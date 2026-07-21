---
type: Concept
title: OKF Prompt Injection
description: Binding rule — anytime Aegis runs, inject a dynamic Prompt Pack from live lookup; vault-first catalogs with live refresh when stale; grader reads only for explain/fix — not a static path ban-list.
tags: [standard, okf, prompting, tokens, aegis, retrieval, cache]
timestamp: 2026-07-21T04:30:00Z
status: active
---

# OKF Prompt Injection (Rule #2)

**Rule #2.** Curated OKF stays in the vault. Generation and Q&A context get a **dynamic Prompt Pack**: slim `## Prompt Card` text from **this turn’s** `okf.py lookup` / `okf.py card` — not a full-brain dump and not a static “never open these paths” encyclopedia in AGENTS.md.

**Scope:** Anytime Aegis is used (questions, review, authoring) — not only Path A artifact generation.

Domain graders differ by stack. **What is in-bounds for a turn is defined by the live lookup hit-set** (and, for benches, by task placeholders such as `GATE_ANSWER_KEY_GLOBS`).

## Retrieval ladder (global)

| Priority | Lane | How | Use for | Must not use for |
| :---: | :--- | :--- | :--- | :--- |
| 1 | **OKF knowledge cache** | `okf.py lookup --card` / `pack` (+ ≤1 follow-up `lookup`/`card`) | Standards, playbooks, concepts, catalogs, pins/versions in the vault | Random vault Grep; paste `graph.json` / full docs |
| 2 | **Pointers from cards** | Read only paths the **current cards** name | One deep dive the pack pointed to | Opening every related file |
| 3 | **Task corpus** | Glob → Grep → Read (or Explore subagent) | Product/code/config (`actions/`, `workflows/`, …); observed pins; house `./actions/*` | Discovering org compliance that should be on cards; opening grader trees |
| 4 | **Live external** | Official Git/OCI/`gh`/upstream metadata | Pins/versions/catalogs still missing or stale after lanes 1–3 | Skipping vault/corpus when a fresh card exists; inventing `@vN` |
| 5 | **Grader / answer key** | See [Grader access](#grader-access-daily-work) | Explain failure (what/why/where); fix from gate output | Authoring-time peek to invent compliance |

Lane 1 **MUST** run before corpus or authoring. Corpus (lane 3) is allowed after lane 1 when cards lack required facts. Live (lane 4) is allowed only after corpus still cannot supply the fact. **Write-back is MUST** when lanes 3–4 learn durable pins/recipes (Rung 1 `_inbox/` minimum; ingest via maintain playbook).

**Plan-time FORBIDDEN:** approving “stub `run:` / local staging / promote later” as the design when the task needs real checkout, cross-job artifacts, or house actions — resolve via the ladder instead.

## Catalog / pin freshness (vault + live)

Pins, version catalogs, and similar reference data use **both** sources, ordered by freshness need:

1. **Vault first (default):** human-maintained Prompt Cards; keep warm with `okf.py compile` (`index.json` / `prompt_cards.json`; process also mtime-caches them). Concepts may set `pack_force_when: [keywords]` so pack/lookup force-includes them when the query matches.
2. **Corpus next:** scan task code for `./actions/*` and observed SHA pins.
3. **Live fetch when still missing or stale:** network/`gh`/upstream only if vault+corpus lack the fact, the card is marked stale, or the user requires verification against current upstream.
4. **Write-back (MUST when learned):** durable discoveries belong back in the vault via the maintain playbook — do not rediscover every run.

Agents **MUST NOT** default to live rediscovery when a current card already supplies the catalog.

## Grader access (daily work)

| Mode | Policy / Rego / CI rule sources |
| :--- | :--- |
| **Authoring / writing** | Cards (+ failure text if remediating). **MUST NOT** mine the grader to invent compliance. |
| **Asked what failed / why / where** | **MAY** open the relevant grader source to explain and locate the rule. Prefer starting from failure output, then open the cited file/rule. |
| **A/B bench OKF arm** | Follow the bench prompt: forbidden globs are **task-specific** (`GATE_ANSWER_KEY_GLOBS`), not this standard’s static list. |

## MUST

1. Anytime Aegis is used, run `okf.py lookup --card` (or `lookup` then `card`) with **task-specific** keywords before vault Grep or generation.
2. Assemble a **Prompt Pack** from returned `## Prompt Card` sections only.
3. Each card **MUST** target **≤150 tokens** (~600 characters). Prefer shorter.
4. Total Prompt Pack for one turn **SHOULD** stay **≤400 tokens** unless the user expands scope.
5. Encyclopedic bodies **MUST** stay in the vault — **MUST NOT** be copied wholesale into the generation prompt.
6. Binding rules **MUST** expose a `## Prompt Card` so lookup can surface them dynamically.
7. Missing pin/version/constraint in the pack → **one** follow-up `lookup`/`card`, then corpus (lane 3), then live-refresh (lane 4); **MUST** write-back durable facts. **MUST NOT** ship stub designs that omit required checkout/artifact/house-action wiring.

## SHOULD

1. `okf.py card <path>…` when paths are already known from lookup.
2. Prefer **one-shot validation pass** (e.g. Conftest) when the Prompt Pack already encodes binding rules — avoid generate → fail → remediate loops when the first pack is sufficient.
3. Keep domain catalogs/pins **on cards** so vault-first stays viable. Maintain a **pin cache** (tag → 40-char SHA) for common `uses:`; attach it when remediating pin findings (e.g. CKV2_SPVS_5) instead of live `gh` rediscovery.
4. For authoring tasks, keep the pack to **MUST bullets + pin lines** only (still ≤150 tok/card).
5. After vault edits: `okf.py compile` (and lint) so the knowledge cache stays fresh.

## FORBIDDEN

1. Pasting `graph.json` or full standard/concept files into the prompt by default.
2. “Load the whole Aegis brain” as the default strategy.
3. Skipping live lookup and grepping the vault for compliance knowledge.
4. Encoding a **static** forever ban/allow of domain grader paths in AGENTS.md (bench/task prompts or domain cards own isolation globs).
5. Authoring-time reverse-engineering of the grader when the Prompt Pack already covers the task.
6. Preferring live pin/catalog rediscovery every run when a fresh vault card exists.
7. Treating “no OKF is faster” as truth without measuring **time to validation pass** (include remediation turns).

## Example minimal pack (GHA composite)

```text
SPVS composite MUST:
- runs.using: composite; action.yml + readme.md
- bash run: set -euo pipefail; no set -x
- no ${{ inputs.* }} in run — map via env
- uses: 40-char SHA only; no ../
- no curl|bash; no AWS_* static keys

Pins:
docker/login-action@74a5d142397b4f367a81961eba4e8cd7edddf772
docker/setup-buildx-action@b5ca514318bd6ebac0fb2aedd5d36ec1b5c232a2
```

## Prompt Card

```text
Anytime Aegis: lookup/pack first (cards ≤150 tok; pack ≤400 tok).
Ladder: OKF → card pointers → task corpus → live Git/OCI → write-back.
Grader: explain/fix only. Catalogs: vault-first; pack_force_when honored.
FORBIDDEN: stub-as-design; brain dump; skip lookup; mine grader while authoring.
```

## How to load knowledge (procedure)

| Step | Action |
| :--- | :--- |
| 1 | Form `<task keywords>` from **current** intent/domain |
| 2 | `okf.py pack --budget 1200` or `lookup --card --limit 3 "<task keywords>"` |
| 3 | Inject returned cards only (`pack_force_when` matches are force-included) |
| 4 | Optional: one follow-up lookup/card if still missing |
| 5 | Corpus Glob/Grep/Read (`actions/`, `workflows/`, …) for house actions / observed pins |
| 6 | Live fetch official pins/versions only if still missing or stale |
| 7 | On gate failure: use failure text; open grader sources when explaining what/why/where |
| 8 | Durable new catalog facts → `_inbox` / maintain playbook → `compile` |

## Bench / isolation note

A/B benches that isolate “cards vs grader” **MUST** name forbidden answer-key globs in the **bench prompt** (e.g. `{{GATE_ANSWER_KEY_GLOBS}}`). Do not bake those globs into AGENTS.md.

## Related

- Principle: [Simplicity First](/standards/simplicity-first.md)
- Control plane: [AGENTS.md](/AGENTS.md) Rule #1 (thin pointer)
- Architecture record (design only, not a runbook): `/ADR.md` D4 / D11
- Playbook: [Maintain aegis-system](/vault/playbooks/maintain-aegis-system.md)
- Starter: [Extending Aegis](/vault/concepts/extending-aegis.md)
