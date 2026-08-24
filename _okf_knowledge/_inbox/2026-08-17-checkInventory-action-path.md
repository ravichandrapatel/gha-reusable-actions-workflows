# Change close-out write-back: checkInventory-action-path

**Evidence grade:** provided
**Suggested destination:** standards/python-cli-args.md (already updated)

## What shipped / learned

- Inventory path is `{ACTION_PATH}/{inventory_file}` — correct for composites (`github.action_path` / `GITHUB_ACTION_PATH`).
- `checkInventory.py --action-path` with basename `--inventory-file`. Fallback: ACTION_PATH → GITHUB_ACTION_PATH → script dir (standalone).
