## 1. CLI probe

- [x] 1.1 Add `okf.py capabilities [--json] [--strict]` implementation under `kernel/src/` (probe Brain/FS/Python/Git/Shell/OpenSpec; compile/lint readiness when brain present; `enabled_features` + `runtime_hint`).
- [x] 1.2 Wire subparser in `kernel/src/cli.py` and document in `okf.py` header usage.
- [x] 1.3 Smoke: run `capabilities` and `capabilities --json` in this repo.

## 2. Protocol DNA

- [x] **[MUTATION GATE]** Approve AGENTS.md + thin-binding rewrite (protocol contract; multi-file).
- [x] 2.1 Update `AGENTS.md` to v`4.10.0+openspec`: Discovery PRE-FLIGHT, feature matrix, unified state machine, footer `Runtime State`, Mutation Gate → `PENDING_APPROVAL`.
- [x] 2.2 Update thin bindings (`.cursor/rules/aegis-openspec.mdc` and mirrored `.github`/`.claude`/`.agent` aegis-openspec snippets) for discovery-first.
- [x] 2.3 Optional: short vault concept or Prompt Card for capability discovery (maintain playbook if ingesting). — **Skipped** (defer to MAINTAIN later; DNA + CLI sufficient for v1).

## 3. Verify

- [x] 3.1 Confirm pack is not required before discovery; pack still required when Brain enabled before design/specs.
- [x] 3.2 Confirm footer/docs no longer treat Mutation Gate and Exit Code as unrelated axes.
- [x] 3.3 `openspec status --change aegis-capability-runtime-state` complete.
