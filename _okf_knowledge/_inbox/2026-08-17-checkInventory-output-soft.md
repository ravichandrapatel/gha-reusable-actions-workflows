# Change close-out write-back: checkInventory-output-soft

**Evidence grade:** provided
**Suggested destination:** standards/python-cli-args.md (flag name `--output`) | MAINTAIN later if already ingested

## What shipped / learned

- `checkInventory.py`: `--github-output` renamed to `--output`. `--soft` on miss writes `matched=false` and exits 0; hard miss still exits 1.
- Composite maps `soft` via env and passes `--soft` when `true`. `--output` is `$GITHUB_OUTPUT` in Actions.
