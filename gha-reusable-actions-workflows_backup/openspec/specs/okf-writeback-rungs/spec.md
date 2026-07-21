## Purpose

Normative Rung 1 vs Rung 2 write-back rules and their binding to the maintain playbook / Mutation Gate.

## Requirements

### Requirement: Rung 1 inbox write-back is always required on archive

Agents MUST write a Rung 1 note to `_okf_knowledge/_inbox/<YYYY-MM-DD>-<change-name>-note.md` before OpenSpec archive `mv` (or final sync that retires the change). Skipping with “no trigger” is FORBIDDEN. Rung 1 is Mutation-Gate-exempt and MUST NOT edit `vault/`, `standards/`, or other durable brain paths.

#### Scenario: Archive close-out writes inbox note only for Rung 1

- **WHEN** an agent archives an approved OpenSpec change and no Rung 2 ingest will run
- **THEN** a Rung 1 `_inbox/` note exists with what shipped, evidence grade, and suggested destination (or `MAINTAIN later` / `no durable vault candidate`)
- **AND** no durable vault/standards file was modified under a “write-back” claim without the maintain playbook

### Requirement: Rung 2 ingest follows the maintain playbook

Rung 2 (any durable brain mutation from write-back) MUST follow `vault/playbooks/maintain-aegis-system.md` end-to-end, including type/dir, frontmatter, cross-links, affected `index.md`, `log.md`, and `okf.py compile` then `okf.py lint` with 0 errors. Rung 2 is NOT Mutation-Gate-exempt as freestyle vault editing. Destructive vault ops remain Mutation-Gated.

#### Scenario: Same-close-out Rung 2 completes maintain checklist

- **WHEN** distillate is durable, destination is clear, and the agent chooses same-close-out ingest
- **THEN** the maintain playbook post-change checklist completes successfully before OpenSpec archive `mv`
- **AND** the inbox source is retired only after successful ingest per that playbook

#### Scenario: Incomplete maintain defers Rung 2

- **WHEN** distillate is durable but the maintain checklist cannot complete in the close-out
- **THEN** the agent MUST leave Rung 1 with suggested destination `MAINTAIN later` (or equivalent)
- **AND** MUST NOT partially edit vault/standards under write-back

### Requirement: Control-plane surfaces state Rung 1 vs Rung 2 consistently

`AGENTS.md` §1.6 and Mutation Gate text, the maintain playbook OpenSpec archive write-back section and Prompt Card, archive skills/commands across tool mirrors, and thin `aegis-openspec` bindings MUST state the same Rung 1 / Rung 2 rules. Comparison-only bench prompt files are out of scope.

#### Scenario: Archive skill mirrors match AGENTS

- **WHEN** an agent reads any mirrored `openspec-archive-change` skill or `opsx-archive` command
- **THEN** the skill states Rung 1 always before archive `mv`, and Rung 2 only via full maintain playbook (or defer)
- **AND** it does not claim that Rung 2 write-back is Mutation-Gate-exempt
