---
type: Playbook
title: Maintain aegis-system
description: How to add or update concepts, playbooks, references, scripts, and skills in the aegis-system OKF vault — with post-change verification.
tags: [aegis-system, ingest, maintenance, okf, procedure]
timestamp: 2026-07-21T01:05:00Z
status: active
---

# Trigger

You need to add or change durable knowledge in aegis-system: a concept, house standard,
playbook, reference, vault script, agent bridge, or Cursor skill.

# Preconditions

- [AGENTS.md](/AGENTS.md) §1.2 binds all brain mutations to this playbook — follow it end-to-end.
- Read [AGENTS.md](/AGENTS.md) §1.3 for the OKF frontmatter schema before creating files.
- Raw source material (if any) is in [`_inbox/`](/_inbox/) and has not been edited.
- You know which `type` the content is (see decision table below).

# What to create — decision table

| You are documenting… | `type` | Directory | Also update |
|----------------------|--------|-----------|-------------|
| Evergreen knowledge, pattern, tool overview | `Concept` | `vault/` (by domain) | `vault/index.md` |
| House rule (MUST/SHOULD) | `Concept` + tag `standard` | `standards/` | [standards/index.md](/standards/index.md) |
| Executable agent procedure | `Playbook` | `vault/playbooks/` | [playbooks/index.md](/vault/playbooks/index.md) |
| Cached upstream docs | `Reference` | `vault/references/` | Run `kernel/okf.py optimize` |
| Running system in workspace | `System` | `vault/systems/` | [systems/index.md](/vault/systems/index.md) |
| Post-mortem | `Incident` | `vault/incidents/` | Link to affected systems/playbooks |
| Domain routing / tool overview | `Concept` | `vault/concepts/` | [vault/index.md](/vault/index.md) |
| Vault tooling (lint, compile, scrape) | Python script | `kernel/` | This playbook § Scripts |
| Control-plane schema / persona | Markdown | `AGENTS.md` (package root, next to `_okf_knowledge/`) | [_okf_knowledge/index.md](/index.md) |

# Add or update a concept

## 1. Choose path and filename

- One concept per file; kebab-case filename matching the topic.
- House standards go in `standards/` with `tags: [standard, …]`.
- Domain concepts go in `vault/`.

## 2. Frontmatter (required)

```yaml
---
type: Concept
title: Human-readable name
description: One-line summary for indexes and okf_lookup.
tags: [kebab-case, topic]
timestamp: 2026-07-13T00:00:00Z
status: active
---
```

## 3. Body

- Prefer headings, tables, lists, and fenced code over long prose.
- Standards: normative **MUST** / **SHOULD** / **FORBIDDEN** language.
- Binding standards **MUST** include a non-empty `## Prompt Card` section (≤150 tokens / ~600 chars) — enforced by `okf.py lint` (`DBG-308` / `DBG-309`). See [OKF Prompt Injection](/standards/okf-prompt-injection.md).
- Other agent-facing concepts **SHOULD** include a `## Prompt Card` for slim injection.
- External claims: `# Citations` with numbered `[1] [title](url)` entries.
- Link to related concepts with bundle-absolute paths.

## 4. Cross-links (both directions)

- New concept MUST link to at least one existing related concept.
- Update those existing files to link back.
- Update every affected `index.md` on the path from root to the file.

# Add or update a playbook

## Required sections

```markdown
# Trigger
# Preconditions
# Steps
# Verification
```

- Add a one-line entry to [playbooks/index.md](/vault/playbooks/index.md).

# Add or update a script

The kernel entrypoint is `kernel/okf.py` (thin CLI caller) with implementation modules under `kernel/src/`; one subcommand per operation. The kernel is **not** an OKF concept.

| Subcommand | Role |
|--------|------|
| `okf.py capabilities` | Probe Brain/Filesystem/Python/Git/Shell/OpenSpec (+ compile/lint readiness); list `enabled_features` / `runtime_hint` (`--json`, `--strict`) |
| `okf.py compile` | Regenerate `kernel/src/graph.json`, `index.json`, `prompt_cards.json`; embed graph in `kernel/src/aegis-brain.html` |
| `okf.py lint` | Conformance + broken links + orphans + **standards Prompt Card gate**; embeds report into `kernel/src/aegis-brain.html` |
| `okf.py card` | Extract `## Prompt Card` sections for slim agent injection |
| `okf.py lookup` | Search via `index.json` (fallback: live vault); list hits or budgeted `--card` |
| `okf.py enrich` | LLM gap-fill for retrieval fields (description, tags, `## Prompt Card`); dry-run by default, `--write` to apply |
| `okf.py scrape` | JIT upstream fetch → `vault/` |
| `okf.py optimize` | Normalize references, rebuild vault indexes, run compiler |
| `okf.py serve` | Local server + `POST /api/lint` / `POST /api/compile` |

# Post-change checklist

Run after **every** concept or playbook add/update:

```bash
# From this package directory (wherever it was dropped in agents/)
python3 _okf_knowledge/kernel/okf.py compile
python3 _okf_knowledge/kernel/okf.py lint
```

| Step | Action |
|------|--------|
| 1 | Update affected `index.md` files |
| 2 | Cross-link both directions |
| 3 | Append entry to [log.md](/log.md) |
| 4 | Run `okf.py compile` |
| 5 | Run `okf.py lint` — must end with `0 error(s)` |
| 6 | Archive or delete `_inbox/` source after ingest |

# OpenSpec archive write-back

Triggered by `/opsx:archive` or final sync that retires an approved change ([AGENTS.md](/AGENTS.md) §1.6).

## Rung 1 (always)

Write `_inbox/<YYYY-MM-DD>-<change-name>-note.md` **before** archive `mv`:

```markdown
# OpenSpec archive write-back: <change-name>

**Evidence grade:** observed | provided | verified | inferred
**Suggested destination:** vault/... | standards/... | MAINTAIN later | no durable vault candidate

## What shipped
- …
```

## Rung 2 (when durable)

Same-close-out ingest **only when** the note is reusable, destination is clear, **and** this playbook’s post-change checklist can finish before OpenSpec archive `mv`. Rung 2 is Path C MAINTAIN/INGEST — **not** Mutation-Gate-exempt freestyle. If the checklist cannot complete, leave Rung 1 with `MAINTAIN later` and do **not** partially edit vault/standards.

| Durable? | Action |
|----------|--------|
| Pin / catalog SHA | Update `vault/references/` catalog |
| CI recipe / house procedure | Update Concept/Playbook |
| Missing standard | Draft under `standards/` + Prompt Card |
| Unclear destination | Leave inbox; do not invent layout |
| Zone 5 file-tree only | Note “no durable vault candidate”; do not ingest |
| Checklist cannot finish now | Leave inbox as `MAINTAIN later`; no vault edit |

Then run post-change checklist (`compile` + `lint` → 0 errors; indexes / cross-links / `log.md`). Archive or delete the inbox source after successful ingest.

# Verification

- [ ] New/edited file has valid frontmatter per [AGENTS.md](/AGENTS.md) §1.3
- [ ] Every affected `index.md` lists the new or changed page
- [ ] `python3 _okf_knowledge/kernel/okf.py lint` reports clean (or warnings only, with plan)
- [ ] `log.md` has a dated entry
- [ ] Change followed this playbook as required by [AGENTS.md](/AGENTS.md) §1.2
- [ ] OpenSpec archive always left a Rung 1 `_inbox/` note before `mv`

## Prompt Card

```text
Brain mutations MUST: correct type/dir; frontmatter; cross-links; index.md; log.md.
Standards MUST ship ## Prompt Card (≤600 chars). After change: compile then lint (0 errors).
OpenSpec archive: ALWAYS Rung 1 _inbox; Rung 2 only via full maintain checklist (else defer).
```

# Related

- Schema contract + maintenance binding: [AGENTS.md](/AGENTS.md) (§1.2, §1.3, MAINTAIN/INGEST intent)
- Standards: [Simplicity First](/standards/simplicity-first.md)
- Starter: [Extending Aegis](/vault/concepts/extending-aegis.md)
- Portable pre-flight: [Aegis Capability Discovery](/vault/concepts/aegis-capability-discovery.md)
- Profile template: [Profile schema](/kernel/profiles/_schema.md)
