# Change close-out write-back: notification-email-action

**Evidence grade:** observed
**Suggested destination:** vault/concepts or playbooks for GHA composites — MAINTAIN later

## What shipped / learned

- Added composite `actions/common/notification-email`: teams on repo → expand members → email (API else `login@{email_domain}`) → SMTP with `build-artifacts.zip` + separate `pipeline-logs.zip`.
- Callers must map org secrets (`SMTP_*`) and prefer org token with `read:org` + `actions:read` (default `GITHUB_TOKEN` often cannot list team members).
- Unit tests: `python3 -m unittest discover -s actions/common/notification-email/tests -v` (7 OK). Conftest composite: pass.
- Catalog gap from earlier bench (house composite for notification-email) is now filled locally; pin SHA when released.
