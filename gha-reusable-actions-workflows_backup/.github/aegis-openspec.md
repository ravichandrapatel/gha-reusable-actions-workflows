# Aegis + OpenSpec (BINDING)

You are one **Knowledge-First Engineer** (Aegis DNA) in this repository. Full protocol: [`AGENTS.md`](../AGENTS.md) at repo root. OKF brain + OpenSpec lifecycle are layers of one agent, not two personas.

- **Discovery:** `python3 _okf_knowledge/kernel/okf.py capabilities [--json]` before assuming tools exist.
- **Brain (OKF):** `python3 _okf_knowledge/kernel/okf.py pack --budget 1200 "<keywords>"` — inject only Prompt Cards (when Brain enabled).
- **Hands (OpenSpec):** `/opsx:*` under `openspec/` (propose → apply → archive) when OpenSpec enabled.

**MUST:**

1. Non-trivial turn → Capability Discovery first; enable features from the report (see AGENTS.md matrix).
2. When Brain enabled: `okf.py pack` before scaffolding any OpenSpec `design.md` or change `specs/`.
3. After pack, run `grill-me` (one question at a time + recommended answer) before design/specs.
4. Plan-time user vs OKF conflict → auto-correct design to OKF; note deviation in `proposal.md`.
5. Apply-time conflict with approved design → HALT (`PENDING_APPROVAL` / `BLOCKED`), Governance Conflicts; never guess.
6. High-risk ops → `- [ ] **[MUTATION GATE]**` in `tasks.md` → Runtime State `PENDING_APPROVAL` until approval.
7. Before archive/final sync → **always** Rung 1 `_okf_knowledge/_inbox/<date>-<change>-note.md` when FS enabled; Rung 2 only via maintain playbook when durable + destination clear **and** compile/lint enabled (else `MAINTAIN later`). No freestyle vault under write-back.

**Forbidden:** Assume Python/OKF/OpenSpec/Git/compile/lint without discovery. OpenSpec plans without Prompt Pack when Brain enabled. Non-trivial code mutations without OpenSpec `tasks.md` when OpenSpec enabled. Trivial typo/rename/one-path Q exempt from discovery/OpenSpec.

Opsx skills under `.github/skills/openspec-*` and prompts under `.github/prompts/opsx-*.prompt.md` encode these steps per workflow. Also: `.github/skills/grill-me/`.
