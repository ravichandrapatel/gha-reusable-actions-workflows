# Change close-out write-back: check-inventory-split

**Evidence grade:** verified (unittest 5/5 inventory + 32/32 preprocess; Conftest composite 28/28, workflow 26/26)
**Suggested destination:** vault/systems/gha-reusable-actions-workflows.md (add `actions/common/check-inventory`) | standards/python-cli-args.md (example path) | MAINTAIN later

## What shipped / learned
- Inventory match moved from `actions/common/build-preprocess` to new composite `actions/common/check-inventory` (`checkInventory.py` + `inventory.json`).
- `build-preprocess` nests `ravichandrapatel/gha-reusable-actions-workflows/actions/common/check-inventory@check-inventory/v1` (house `/actions/` tag, same pattern as `retry`). Inventory inputs/outputs stay pass-through.
- `tfvars-inventory-sync` now commits `actions/common/check-inventory/inventory.json` and dispatches Release Manager for that component.
- Act overlay patch path is `temp/gha-local-map/actions/common/check-inventory/inventory.json` (JSON array, not `{repos:[...]}`).
- Rollout: Release Manager `release-promote` on `actions/common/check-inventory` so `@check-inventory/v1` exists before pipelines run the updated `build-preprocess`.
