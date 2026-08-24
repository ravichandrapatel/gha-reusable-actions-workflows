# Change close-out write-back: notification-email-action

**Evidence grade:** observed
**Suggested destination:** vault/concepts/notification-email.md — MAINTAIN later (concept exists; add `recipients` / `resolve_teams` / `template_file`)

## What shipped / learned

- Recreated missing house composite `actions/common/notification-email` (`action.yml`, `notify.py`, `readme.md`, unit tests).
- Recipients: GitHub teams on `repository` (current repo or `owner/repo` / bare name) → member email (API else `{login}@{email_domain}`); optional `recipients` merged; `resolve_teams: false` skips GitHub lookup.
- Custom templates: `body` or `template_file` with `{name}` / `{{name}}` plus `template_vars` JSON. SMTP STARTTLS; optional `build-artifacts.zip` + `pipeline-logs.zip`.
- Verify: `python3 -m unittest discover -s actions/common/notification-email/tests -v` (21 OK). Conftest composite: 14 passed.
