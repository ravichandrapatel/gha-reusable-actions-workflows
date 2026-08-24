# Change close-out write-back: docker-login-buildah

**Evidence grade:** verified
**Suggested destination:** vault/systems/gha-reusable-actions-workflows.md | MAINTAIN later

## What shipped / learned
- `actions/common/docker-login` is bash-only: `buildah login --password-stdin` (password from `REGISTRY_PASSWORD` env, never argv). Python helper removed.
- Login and docker-build-and-push push `uses: ./actions/common/retry` with `shell: bash` (not `uses: ../`).
- Inputs: `registry`, `username`, `password`, `tls_verify`, plus retry `max_attempts` / `retry_wait_seconds` / `timeout_seconds`.
