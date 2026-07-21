## ADDED Requirements

### Requirement: Unified runtime state machine

AGENTS protocol MUST define runtime states `READY`, `BLOCKED`, `PENDING_APPROVAL`, `EXECUTING`, `ROLLED_BACK`, and `COMPLETE`, and MUST derive Status Footer exit codes from those states rather than treating Mutation Gate and exit codes as independent axes.

#### Scenario: Approval halt

- **WHEN** a high-risk mutation requires user approval
- **THEN** the agent reports Runtime State `PENDING_APPROVAL` and Exit Code `1`
- **AND** the tasks checklist still uses a `[MUTATION GATE]` checkbox as the approval latch

#### Scenario: Success complete

- **WHEN** non-trivial work finishes successfully
- **THEN** the agent reports Runtime State `COMPLETE` and Exit Code `0`

### Requirement: Feature enablement matrix

When capabilities are missing, AGENTS protocol MUST disable features per the agreed matrix: missing Brain disables pack/compile/lint/vault ingest; missing OpenSpec disables propose/apply/archive; missing Git disables commit/PR/archive git ops; missing compile/lint disables Rung 2 maintain close-out but allows Rung 1 inbox; non-trivial CREATE/MODIFY with both Brain and OpenSpec missing MUST be `BLOCKED` with Exit Code `4`.

#### Scenario: Brain and OpenSpec absent

- **WHEN** Capability Discovery reports Brain and OpenSpec missing
- **AND** the user requests non-trivial multi-file CREATE/MODIFY
- **THEN** the agent enters Runtime State `BLOCKED` with Exit Code `4`
- **AND** does not invent an alternate lifecycle

### Requirement: Status footer includes Runtime State

Non-trivial finals MUST include Runtime State alongside Exit Code in the Status Footer.

#### Scenario: Footer fields

- **WHEN** an agent emits a non-trivial final response
- **THEN** the footer includes `Runtime State` and a derived `Exit Code`
