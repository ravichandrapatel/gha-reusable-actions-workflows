## 1. Portable kit

- [x] 1.1 Add `act-platform/image/ubuntu/Dockerfile` (+ short image notes) → `gha-act-ubuntu:dev` (catthehacker Ubuntu act base; no house CLIs).
- [x] 1.2 Add `act-platform/image/ubi9/Dockerfile` (+ short image notes) → `gha-act-ubi9:dev` (UBI9 + act prerequisites).
- [x] 1.3 Add `act-platform/templates/` (`.actrc` content, `.act/events/README.md`, `secrets.example`, `vars.example`, `gitignore.snippet`).
- [x] 1.4 Add `act-platform/build-images.sh` (build both tags).
- [x] 1.5 Add `act-platform/bootstrap.sh` (`TARGET`, `--force`, `--build`; no nested kit when TARGET is host; refuse clobber without `--force`).
- [x] 1.6 Add portable `act-platform/README.md` (any-repo; no Conftest/Release Manager prerequisites).

## 2. Host adoption

- [x] 2.1 Run bootstrap on this repo (or equivalent checked-in root `.actrc` + `.act/` from templates).
- [x] 2.2 Update root `.gitignore` with act secret/var paths from snippet.
- [x] 2.3 Root `README.md` pointer to `act-platform/`.

## 3. Host OKF docs

- [ ] 3.1 Add `_okf_knowledge/vault/playbooks/run-gha-local-act.md` (kit pointer; both images; `act --list`; FORBIDDEN Release Manager; lint = pre-commit; recipes follow-on).
- [ ] 3.2 Update `vault/playbooks/index.md` and `_okf_knowledge/log.md`.

## 4. Brain maintain

- [ ] **[MUTATION GATE]** Approve vault playbook ingest + index/log updates.
- [ ] 4.1 `python3 _okf_knowledge/kernel/okf.py compile` then `lint`.

## 5. Verify

- [x] 5.1 Kit has no required imports of `./actions/*`, Conftest, or OKF.
- [x] 5.2 Build both tags when Docker available; `act --list` from host root (or document skip).
- [x] 5.3 Bootstrap dry-check: script help / refuse-without-force behavior.
- [ ] 5.4 `openspec status --change local-act-dev-env` apply-ready.
