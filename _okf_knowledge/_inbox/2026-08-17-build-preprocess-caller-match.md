# Change close-out write-back: build-preprocess-caller-match

**Evidence grade:** observed
**Suggested destination:** vault/systems/gha-reusable-actions-workflows.md (component inventory) | MAINTAIN later

## What shipped / learned

- `actions/common/build-preprocess` now fails (exit 1) unless the caller repo is listed in shipped `inventory.json` `.repos`.
- Caller is `inputs.repo` when set, otherwise `GITHUB_REPOSITORY`. Match is exact `owner/repo`, repo name, or last path segment of an inventory `owner/repo` entry (tfvars sync stores basenames).
- New outputs: `matched=true` on success, `repo` = resolved caller. Empty stub inventory still fails every caller until tfvars-inventory-sync populates it.
