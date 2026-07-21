---
type: Concept
title: Aegis Capability Discovery
description: Probe environment caps before enabling Brain/OpenSpec/Git features; unified Runtime States derive exit codes.
tags: [aegis-system, capability, discovery, runtime-state, portable]
timestamp: 2026-07-21T01:00:00Z
status: active
pack_force_when: [capabilities, capability-discovery, runtime-state, PENDING_APPROVAL, okf.py capabilities]
---

# Aegis Capability Discovery

Portable pre-flight for Aegis: **discover** what exists, **enable** features, then pack/lifecycle. Do not assume Python, OKF, OpenSpec, filesystem, Git, compile, or lint.

## Probe

```bash
python3 _okf_knowledge/kernel/okf.py capabilities [--json] [--strict]
```

Reports: Brain, Filesystem, Python, Git, Shell, OpenSpec, compile, lint → `present` | `missing` | `degraded`, plus `enabled_features` and `runtime_hint` (`READY` | `BLOCKED`). `--strict` exits `4` when blocked.

**Cadence:** once per non-trivial turn (and on env change). Trivial Q&A may skip. **Fallback** if Python/`okf.py` missing: shell probes; never claim a successful Prompt Pack.

## Feature matrix (summary)

| Missing | Disable | Still allow |
| --- | --- | --- |
| FS / Shell | Mutate paths | Explain-only with pasted context |
| Python / Brain | Pack, compile, lint, vault ingest | OpenSpec-only if present; else BLOCKED when Rule #1 required |
| OpenSpec | Propose / apply / archive | Advisory + trivial edits |
| Git | Commit / PR / archive git ops | Edits + pack if Brain OK |
| compile / lint | Rung 2 maintain close-out | Rung 1 inbox + `MAINTAIN later` |

Hard rule: non-trivial CREATE/MODIFY with Brain **and** OpenSpec missing → `BLOCKED` / exit `4`.

## Runtime states (exit derived)

`READY` → `BLOCKED` → `PENDING_APPROVAL` → `EXECUTING` → `ROLLED_BACK` → `COMPLETE`

| State | Exit |
| --- | --- |
| `PENDING_APPROVAL` (tasks `[MUTATION GATE]`) | `1` |
| `BLOCKED` | `2` or `4` |
| `COMPLETE` | `0` |
| `ROLLED_BACK` | `1` or `2` |

Status footer **MUST** include `Runtime State` and derived `Exit Code`. Normative DNA: [AGENTS.md](/AGENTS.md) § Capability Discovery and §4.1.

## Prompt Card

```text
Non-trivial: okf.py capabilities [--json] before pack/OpenSpec.
Enable features from report; no tool assumptions.
States: READY|BLOCKED|PENDING_APPROVAL|EXECUTING|ROLLED_BACK|COMPLETE
(exit derived). Gate checkbox → PENDING_APPROVAL (exit 1).
Brain+OpenSpec missing → BLOCKED exit 4. Fallback probes if no Python.
```

## Related

- Control plane: [AGENTS.md](/AGENTS.md)
- Maintenance: [Maintain aegis-system](/vault/playbooks/maintain-aegis-system.md)
- Starter: [Extending Aegis](/vault/concepts/extending-aegis.md)
- Retrieval: [OKF Prompt Injection](/standards/okf-prompt-injection.md)
