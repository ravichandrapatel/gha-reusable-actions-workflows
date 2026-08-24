# Change close-out write-back: act-tagged-temp-ng-ui

**Evidence grade:** verified
**Suggested destination:** MAINTAIN later | vault/playbooks if we document local act as a house playbook

## What shipped / learned
- `act` only sees `.github/workflows/`; keep `{safe_name}/vX.Y.Z` refs and map them with `--local-repository`.
- WSL: `DOCKER_HOST=unix:///var/run/docker.sock` (not containerd).
- Throwaway app: `temp/ng-ui-act-fixture` + overlay `temp/gha-local-map` (inventory patched only in overlay).
- Verified: tagged `ng-ui-build-pipeline/v1` + `build-preprocess/v2.0.0` ran; inventory match; npm lint/test/build succeeded.
- Blocker: `actions/upload-artifact@v7` vs act 0.2.84 artifact server (`unknown field mime_type`). Upgrade act or skip later jobs for local smoke.
