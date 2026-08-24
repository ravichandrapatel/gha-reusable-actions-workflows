# Change close-out write-back: build-preprocess-python

**Evidence grade:** observed
**Suggested destination:** vault/systems/gha-reusable-actions-workflows.md (component inventory) | MAINTAIN later

## What shipped / learned

- `actions/common/build-preprocess` match logic moved from inline bash/jq to stdlib `main.py`. Composite keeps a SPVS-required launcher: `set -euo pipefail` + `python3 -u` + `PYTHONUNBUFFERED=1`.
- No third-party deps. Caller match rules unchanged (full `owner/repo`, repo name, last path segment).
