# Change close-out write-back: s2i-build-and-push

**Evidence grade:** verified
**Suggested destination:** vault/systems/gha-reusable-actions-workflows.md | MAINTAIN later

## What shipped / learned
- Composite `actions/common/s2i-build-and-push` for Maven/.NET when the runtime artifact is already built in a prior job.
- Uses native Red Hat **`s2i build SOURCE BUILDER IMAGE`** — no generated Dockerfile, no `docker-build-and-push` / `buildah bud`.
- Flow: stage artifact → `tag.sh` → `s2i build` → retried `buildah push`. Requires `s2i` + `buildah` on the runner.
- Evidence: unittest 8/8; Conftest composite pass; shellcheck clean.
