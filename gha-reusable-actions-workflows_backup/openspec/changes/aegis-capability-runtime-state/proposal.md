## Why

Aegis today assumes Python, OKF, OpenSpec, filesystem, Git, compile, and lint exist. That blocks portability across thin sandboxes. Exit codes, Mutation Gate, and lifecycle also overlap as parallel concepts. Agents need **capability discovery → enable features → then execute**, with a single runtime state machine that derives exit codes.

## What Changes

- Add `okf.py capabilities [--json]` probe (Brain, Filesystem, Python, Git, Shell, OpenSpec; plus compile/lint readiness when brain present).
- Rewrite PRE-FLIGHT in `AGENTS.md` (v bump): Discovery → negotiate → enable features → Rule #1 / lifecycle only for enabled features.
- Unify Mutation Gate + lifecycle HALTs + exit codes into states: `READY` → `BLOCKED` → `PENDING_APPROVAL` → `EXECUTING` → `ROLLED_BACK` → `COMPLETE` (exit derived).
- Status footer adds **Runtime State**; Mutation Gate task checkbox maps to `PENDING_APPROVAL`.
- Update thin bindings (`.cursor/rules/aegis-openspec.mdc` and mirrored aegis-openspec snippets) to mention discovery-first.
- Fallback: if Python/Brain missing, agent runs minimal shell probes and stays `BLOCKED` for brain/OpenSpec features (no freestyle).

## Capabilities

### New Capabilities

- `aegis-capability-discovery`: CLI + protocol for probing and enabling features before execution.
- `aegis-runtime-state`: Unified runtime state machine and derived exit codes in AGENTS DNA / footer.

### Modified Capabilities

- (none under `openspec/specs/` today for AGENTS — protocol change is new specs + AGENTS.md)

## Non-goals

- Full Module/Vendor registry revival.
- Changing OKF pack/lookup semantics beyond “only when Brain enabled”.
- Finishing unrelated in-flight changes (`local-act-dev-env`, `tfvars-matrix-fetch-and-trigger`).

## OKF Prompt Pack

Keywords: `aegis agents.md capability discovery negotiation exit codes mutation gate lifecycle state machine portable openspec`

Cards: okf-prompt-injection, maintain-aegis-system, extending-aegis, spvs-lifecycle.

## Grill-me decisions

- Delivery: **protocol + CLI probe** (`okf.py capabilities [--json]`).
- States and exit mapping as proposed (`PENDING_APPROVAL` = former Mutation Gate → exit 1).
- Feature matrix when caps missing (Brain+OpenSpec both missing → `BLOCKED` exit 4 for non-trivial CREATE/MODIFY).
- Cadence: once per non-trivial turn/session (+ re-probe on env change); trivial Q skips; command name `capabilities`.

## Deviations from user request (OKF auto-correct)

- Compile/lint remain required for Rung 2 / maintain close-out when Brain is enabled (not optional “skip lint forever”).
- Discovery does not replace Rule #1 when Brain is present.

## Impact

- `AGENTS.md`, thin bindings, `_okf_knowledge/kernel/` (`capabilities` command), optional short standard/playbook card, `openspec/config.yaml` references if any.
