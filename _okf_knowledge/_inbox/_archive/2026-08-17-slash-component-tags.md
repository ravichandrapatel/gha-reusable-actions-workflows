# Change close-out write-back: slash-component-tags

**Evidence grade:** provided
**Suggested destination:** vault/concepts/component-tagging.md (ingested this turn)

## What shipped / learned
- Release Manager tags changed from hyphen (`{safe_name}-{X.Y.Z}`, `{safe_name}-v1`) to slash (`{safe_name}/v{X.Y.Z}`, `{safe_name}/v1`).
- Versioned-tag glob is `{safe_name}/v*.*.*` so the stable `{safe_name}/v1` tag is not treated as a SemVer.
- CKV2_SPVS_5 internal `/actions/` allow-list now accepts `{name}/vN` and `{name}/vX.Y.Z` (replaces `{name}-vN`).
- Existing hyphen tags are not dual-read; first slash release starts from `0.0.0` → `1.0.0` unless `version` is passed.
