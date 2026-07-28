# Change close-out write-back: openspec-removal

**Evidence grade:** observed
**Suggested destination:** MAINTAIN later (already ingested into AGENTS.md / vault / capabilities)

## What shipped
- Deleted `openspec/`, `/opsx:*` commands, `openspec-*` skills, `aegis-openspec.mdc`
- AGENTS.md `4.11.0` OKF-only lifecycle; new `.cursor/rules/aegis-okf.mdc`
- Capability probe: no OpenSpec; BLOCKED when Brain missing
- Vault capability + maintain playbook updated; `BENCH_PROMPT_OPENSPEC.md` removed
- `okf-lint.yml` runs from repo root
- `okf.py compile` + `lint` clean (0 errors)
