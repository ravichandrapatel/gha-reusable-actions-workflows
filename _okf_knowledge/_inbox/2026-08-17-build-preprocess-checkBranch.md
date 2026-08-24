# Change close-out write-back: build-preprocess-checkBranch

**Evidence grade:** provided
**Suggested destination:** MAINTAIN later (component inventory)

## What shipped / learned

- `preprocess.py`: declared allowlist `main` `master` `feature/**` `release/**` `hotfix/**` `bugfix/**` and stages `build_and_unit_test`, `owasp`, `sonar`, `docker`.
- Composite second step; outputs `branch` `approved` `approved_branches` `stages`. `--soft` + `--output` same contract as checkInventory.
