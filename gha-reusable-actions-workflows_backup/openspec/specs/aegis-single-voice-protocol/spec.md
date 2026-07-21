## Purpose

Single-voice AGENTS.md DNA that includes the OpenSpec BINDING lifecycle as core protocol (not a bolted-on second agent).

## Requirements

### Requirement: Single DNA voice in AGENTS.md

`AGENTS.md` MUST present one Knowledge-First Engineer. OKF (`okf.py`, `_okf_knowledge/`) is the brain; OpenSpec (`/opsx:*`, `openspec/`) is the change lifecycle (hands). The document MUST NOT end with a second agent-identity block that implies a peer OpenSpec agent.

#### Scenario: No trailing dual protocol

- **WHEN** a reader opens `AGENTS.md` after this change
- **THEN** there is no trailing `## INTEGRATED AEGIS + OPENSPEC PROTOCOL` section that re-introduces “You are a single … agent”
- **AND** the OpenSpec BINDING lifecycle rules appear earlier as core DNA

### Requirement: BINDING lifecycle is core DNA

The former Integrated Aegis + OpenSpec BINDING content (pack before design/specs, grill-me before design, plan/apply conflict rules, Mutation Gate tasks, archive write-back Rung 1/2 rules, happy path) MUST remain BINDING and MUST appear in an early lifecycle section of `AGENTS.md` (not only in thin tool bindings).

#### Scenario: Five binding rules preserved

- **WHEN** `AGENTS.md` is validated against the pre-change backup
- **THEN** pack-before-propose, grill-me-before-design, plan-time auto-correct, apply-time fail-closed, Mutation Gate halt, and archive write-back Rung 1 / maintain-gated Rung 2 are all still stated as MUST/FORBIDDEN
- **AND** the happy path `pack → grill-me → propose → apply → write-back → archive` remains

### Requirement: Backup before mutate

Before modifying `AGENTS.md` in apply, a byte-identical backup `AGENTS.md.4.9.2+openspec.bak` MUST exist at repo root (or be recreated from the then-current file if missing).

#### Scenario: Apply checks backup

- **WHEN** apply begins editing `AGENTS.md`
- **THEN** `AGENTS.md.4.9.2+openspec.bak` exists and matches the pre-edit content baseline for this change
- **AND** rollback is documented as copying the bak over `AGENTS.md`

### Requirement: Governance de-dupe without dropping Path contracts

Path A/B/C output contract schemas MUST remain. Mutation Gate and write-back MUST have a single authoritative definition (lifecycle BINDING and/or §1.6) with other sections pointing to it rather than restating conflicting rules.

#### Scenario: Version bump

- **WHEN** the unify change is applied
- **THEN** the `AGENTS.md` version line is `4.9.3+openspec`
