# Change close-out: preprocess docker on push + workflow_dispatch

**Evidence grade:** verified (unittest 17/17)

## What shipped

- `build_stages`: `docker` when not library, not PR, and event is `push` **or** `workflow_dispatch` (was manual-only).
- Docs/action.yml/readme updated; tests cover develop push and PR skip.

**Suggested destination:** vault concept for CI stage matrix if one is authored later.
