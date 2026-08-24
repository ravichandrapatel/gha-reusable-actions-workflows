# Change close-out write-back: gha-pin-refresh-2026-08-10

**Evidence grade:** verified
**Suggested destination:** vault/references/gha-action-pin-catalog.md (ingested)

## What shipped / learned
- Refreshed all third-party `uses:` pins to latest release SHAs (live GitHub API).
- Eliminated floating `@v4` in `arc-nodejs-8stage.yml`.
- Synced `tfvars-matrix-sync` live copy under `.github/workflows/`.
- Catalog + Prompt Card updated; major bumps include checkout v7.0.1, setup-python v7, download-artifact v8, cache v6.
