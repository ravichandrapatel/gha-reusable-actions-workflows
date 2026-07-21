## Context

`AGENTS.md` §4 PRE-FLIGHT jumps to Intent → Pack without negotiating environment. §4.1 “capability check” is vault-evidence only. Exit codes (0–4), Mutation Gate PENDING/APPROVED, and Path A/B/C lifecycle are documented separately and confuse agents.

## Goals / Non-Goals

**Goals:**

- Portable PRE-FLIGHT: Capability Discovery → Brain Available? → probe FS/Python/Git/Shell/OpenSpec → Enable features → then pack/lifecycle.
- `okf.py capabilities [--json]` as preferred probe; agent fallback probes if CLI unavailable.
- Single state machine; exit codes derived; footer carries Runtime State.
- Feature enablement matrix (agreed in grill-me).

**Non-Goals:**

- Replacing OpenSpec; inventing remote capability brokers; auto-installing missing tools.

## Decisions

1. **PRE-FLIGHT order (BINDING)**
   ```
   Capability Discovery
        ↓
   Caps: Brain | Filesystem | Python | Git | Shell | OpenSpec
        (+ compile/lint readiness if Brain)
        ↓
   Enable features (matrix)
        ↓
   Intent → (if Brain) Rule #1 Pack → … lifecycle / Path A|B|C
   ```

2. **CLI `capabilities`**
   - Human table + `--json` object: `{ "capabilities": { "python": "present", "brain": "present"|"missing"|"degraded", ... }, "enabled_features": [...], "runtime_hint": "READY"|"BLOCKED" }`.
   - Exit: `0` if enough for at least advisory; non-zero optional later — v1 always exit 0 with report (agent interprets); or exit 4 when `brain`+`openspec` missing and `--strict`. **Recommended v1:** exit `0` always; `--strict` → exit `4` when non-trivial baseline caps missing (python+fs+shell). Document both.

3. **State machine**
   - `READY` — caps OK for intended work  
   - `BLOCKED` — missing cap / governance hard-stop → exit 2 or 4  
   - `PENDING_APPROVAL` — former Mutation Gate → exit 1  
   - `EXECUTING` — mutations in flight (transient)  
   - `ROLLED_BACK` — reverted after failure → exit 1 or 2  
   - `COMPLETE` — success → exit 0  
   - Tasks keep `- [ ] **[MUTATION GATE]**` as the UX checkbox that *enters* `PENDING_APPROVAL`.

4. **Feature matrix** — as grill-me; Rung 1 inbox allowed if Filesystem present even when compile/lint missing.

5. **Fallback probes** (no Python): check `_okf_knowledge/` dir, `command -v git`, `command -v openspec`, writable cwd — emit Capability Report manually; do not claim Brain pack succeeded.

6. **Version:** AGENTS.md → `4.10.0+openspec` (capability + state machine).

## Risks / Trade-offs

- [Chicken-and-egg] → Fallback probes when `okf.py` cannot run.
- [Noise every turn] → Only non-trivial; compact one-line report OK.
- [Strict vs soft exit] → `--strict` for CI; agents use JSON field `runtime_hint`.

## Migration Plan

1. Implement `capabilities` command + tests/smoke.
2. Patch AGENTS.md + thin bindings.
3. Optional Prompt Card / standard stub for discovery.
4. Smoke: full env → READY; hide `openspec` → OpenSpec features disabled.

## Open Questions

None — grill-me closed.
