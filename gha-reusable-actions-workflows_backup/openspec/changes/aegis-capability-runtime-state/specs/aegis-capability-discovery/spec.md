## ADDED Requirements

### Requirement: Capabilities CLI probe

The OKF kernel MUST provide `python3 _okf_knowledge/kernel/okf.py capabilities` that reports at least Brain, Filesystem, Python, Git, Shell, and OpenSpec as `present`, `missing`, or `degraded`, and MUST support `--json` machine-readable output listing enabled features derived from those caps.

#### Scenario: Full house environment

- **WHEN** an agent runs `okf.py capabilities --json` in a complete checkout with Python, brain tree, git, shell, and openspec on PATH
- **THEN** the report marks those capabilities present (or degraded only with a stated reason)
- **AND** enabled features include Prompt Pack and OpenSpec lifecycle

#### Scenario: OpenSpec missing

- **WHEN** `openspec` is not available on PATH
- **THEN** the report marks OpenSpec missing
- **AND** enabled features omit propose/apply/archive

### Requirement: Discovery before non-trivial execution

AGENTS protocol MUST require Capability Discovery at the start of each non-trivial turn (and on suspected environment change) before Rule #1 pack or OpenSpec plan/apply, and MUST allow skipping discovery for trivial Q&A.

#### Scenario: Non-trivial work discovers first

- **WHEN** an agent begins non-trivial CREATE/MODIFY work
- **THEN** it runs `okf.py capabilities` or documented fallback probes before scaffolding OpenSpec design/specs
- **AND** it does not assume compile/lint/OpenSpec exist without a report

### Requirement: Fallback when CLI unavailable

When Python or the OKF entrypoint is missing, the agent MUST run minimal filesystem/shell probes, emit a Capability Report, and MUST NOT claim a successful Prompt Pack.

#### Scenario: No Python

- **WHEN** `python3` or `okf.py` cannot run
- **THEN** the agent records Brain/Python as missing via fallback probes
- **AND** non-trivial brain-backed work enters `BLOCKED` rather than freestyle vault mutation
