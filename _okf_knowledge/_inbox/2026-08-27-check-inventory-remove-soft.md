# Change close-out write-back: check-inventory-remove-soft

**Evidence grade:** verified (check-inventory unittest 4/4; Conftest composite 28/28)
**Suggested destination:** vault/systems/gha-reusable-actions-workflows.md | MAINTAIN later

## What shipped / learned
- Removed `soft` from `check-inventory` (action input, `--soft` CLI) and the `build-preprocess` pass-through. Inventory miss always exits 1.
