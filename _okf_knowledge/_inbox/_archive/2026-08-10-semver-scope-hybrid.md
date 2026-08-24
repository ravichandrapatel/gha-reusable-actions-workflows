# Change close-out write-back: semver-scope-hybrid

**Evidence grade:** verified
**Suggested destination:** vault/concepts/semver-from-commits.md (ingested) | standards/gha-commit-subjects.md (ingested)

## What shipped / learned
- SemVer bump now filters by conventional-commit scope vs component `safe_name`.
- Hybrid: unscoped / empty `()` count for any component; `feat|fix|chore({safe_name})` counts; other scopes ignored.
- Code: `policies/scripts/commit_message_lib.sh` (`commit_msg_extract_scope`, classify 2nd arg), `actions/common/semver/action.yml`.
- Tests: `policies/tests/test_commit_message_lib.sh` (all passed).
