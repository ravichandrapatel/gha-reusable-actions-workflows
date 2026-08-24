# Change close-out write-back: release-manager-concurrency

**Evidence grade:** provided
**Suggested destination:** vault/concepts/release-manager-modes.md (ingested this turn)

## What shipped / learned
- Workflow Release Manager runs share concurrency group `release-manager-workflow` (serialize; queue, do not cancel) because they sync and push `main`.
- Action runs use `release-manager-action-{component_path}` so distinct actions deploy in parallel.
