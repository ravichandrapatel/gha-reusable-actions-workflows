## 1. Shared fetch action

- [x] 1.1 Add `actions/common/fetch-repo-file/action.yml` (Contents API via `gh api`, token input, retries, write destination; no raw.githubusercontent).
- [x] 1.2 Add `actions/common/fetch-repo-file/readme.md` with inputs/outputs and **paste-ready build-preprocess recipe** targeting `matrices/workspaces.json` on this monorepo.
- [x] 1.3 Conftest/composite gate locally if required by house hooks (`conftest test` on the new action).

## 2. Sync auto-merge + docs

- [ ] **[MUTATION GATE]** Approve always-on merge-commit auto-merge in `tfvars-matrix-sync` (no new input; App/branch-protection implications).
- [ ] 2.1 Update `workflows/common/tfvars-matrix-sync/workflow.yml` to auto-merge with **merge commit** after PR open/update when matrix changed.
- [ ] 2.2 Update `workflows/common/tfvars-matrix-sync/readme.md`: auto-merge behavior, destination defaults, full `workflow_run` example (apply + destroy names, `completed`, success `if:`, `uses:` sync).
- [ ] 2.3 Optionally add stub `matrices/workspaces.json` (`{"workspaces":[]}`) only if needed for day-one path presence; otherwise document first sync PR creates it.

## 3. Verify

- [ ] 3.1 Confirm fetch action and docs never recommend `raw.githubusercontent.com`.
- [ ] 3.2 Confirm sync has no `enable_auto_merge` (or similar) input.
- [ ] 3.3 `openspec status --change tfvars-matrix-fetch-and-trigger` apply-ready / tasks complete.
