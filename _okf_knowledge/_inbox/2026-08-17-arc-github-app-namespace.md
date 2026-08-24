# Change close-out write-back: arc-github-app-namespace

**Evidence grade:** provided
**Suggested destination:** vault/systems (ARC kustomize) | MAINTAIN later

## What shipped / learned

- GitHub App auth for ARC `github-config`: app id `3843629`, installation id `149912085`. Private key is not stored in YAML.
- Kind injects `github_app_private_key` from repo-root PEM `thecaptainhub-platform-app.2026-07-29.private-key.pem` via `kustomize/scripts/kind-up.sh` (`GITHUB_APP_PEM` override). PEM is gitignored.
- ROSA ExternalSecret templates the two ids and pulls only `github_app_private_key` from Secrets Manager (`github/arc`).
- Overlay `namespace:` is the only namespace pin. Helm `controllerServiceAccount.namespace` stays a stub (`CHANGE_ME`); replacements copy the overlay namespace onto Namespace `metadata.name` and RoleBinding subjects.
- Chart 0.13.1 existing-secret contract: keys `github_app_id`, `github_app_installation_id`, `github_app_private_key` (or `github_token`).
- Kind apply: ARC CRDs fail client-side `kubectl apply` (annotation > 256Ki). Apply chart CRDs with `--server-side`, wait Established, then apply overlay without CRDs.
- `githubConfigUrl` is this repo: `https://github.com/ravichandrapatel/gha-reusable-actions-workflows`.
- Kind overlay must not apply an ids-only `github-config` Secret; that wipes `github_app_private_key`. `kind-up.sh` owns the secret.
- After URL + secret restore: three AutoscalingListeners Running against this repo.
