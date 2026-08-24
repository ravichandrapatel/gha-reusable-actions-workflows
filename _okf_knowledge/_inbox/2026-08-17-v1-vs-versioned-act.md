# Change close-out write-back: v1-vs-versioned-act

**Evidence grade:** verified
**Suggested destination:** vault/concepts/component-tagging.md (already notes peel)

## What shipped / learned

- Production act: `@v1` fails `unsupported object type`; `@v1.5.0` (same component) works.
- Cause: `/v1` is a nested annotated tag (`v1` → `v1.5.0` tag object → commit). Versioned tag points at a commit. GitHub peels nested tags; act/go-git does not.
- `git rev-parse tag` without `^{commit}` returns the tag object SHA; tagging that SHA re-nests.
- Repair: recreate `/v1` at `git rev-parse vX.Y.Z^{commit}` (same commit, new tag object). Clear `~/.cache/act` after rewrite. RM now asserts `type commit` before push.
