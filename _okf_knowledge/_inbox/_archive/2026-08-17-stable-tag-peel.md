# Change close-out write-back: stable-tag-peel

**Evidence grade:** verified
**Suggested destination:** vault/concepts/component-tagging.md (ingested)

## What shipped / learned

- Promote/rollback used `git tag -a "$STABLE_TAG" "$VERSION_TAG"`, creating nested annotated tags (`/v1` → `/vX.Y.Z` tag object → commit).
- GitHub Actions peels nested tags; nektos/act (go-git) does not → `unsupported object type` for `uses: ...@build-preprocess/v1`.
- Fix: `TARGET_COMMIT="$(git rev-parse "${VERSION_TAG}^{commit}")"` then `git tag -a "$STABLE_TAG" "$TARGET_COMMIT"`.
- Existing remote `/v1` tags stay nested until a new promote/rollback after this workflow is on default branch. Pin `@name/vX.Y.Z` until then.
