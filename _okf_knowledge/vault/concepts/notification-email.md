---
type: Concept
title: Notification Email composite
description: House composite that fans out SMTP mail to GitHub team members with build artifacts and pipeline-logs.zip.
tags: [github-actions, notification, email, smtp, teams, artifacts]
timestamp: 2026-08-10T00:00:00Z
status: active
pack_force_when: [notification-email, smtp, notify, email notification, pipeline-logs, team members]
---

# Notification Email composite

**Path:** `actions/common/notification-email/` (`action.yml` + `notify.py` + `readme.md`).

House composite for always-on (or on-demand) pipeline email.

## Behavior

1. List GitHub teams with access to the target repo.
2. Expand each team’s members; prefer public/API `email`, else `{login}@{email_domain}`.
3. Merge optional `extra_recipients`; dedupe; **fail if empty**.
4. Attach `build-artifacts.zip` (run artifacts; optional name filter) and a separate `pipeline-logs.zip` (Actions run logs API).
5. Send via SMTP STARTTLS (default port 587). Callers map org secrets into inputs — the composite cannot read org secrets itself.

## Token / secrets

| Need | Source |
| --- | --- |
| List teams + members | Org token with `read:org` (default `GITHUB_TOKEN` often insufficient) |
| Download artifacts/logs | `actions:read` (+ `repo` for private) |
| SMTP | Org secrets → inputs: `smtp_host`, `smtp_port`, `smtp_username`, `smtp_password` |

Prefer `./actions/common/notification-email` in this monorepo; when consumed elsewhere pin a release SHA (never `@vN`).

## Verification

```bash
python3 -m unittest discover -s actions/common/notification-email/tests -v
conftest test --parser yaml -n composite \
  -p policies/conftest/github_actions/composite \
  -p policies/conftest/github_actions/lib \
  actions/common/notification-email/action.yml
```

## Prompt Card

```text
notification-email: ./actions/common/notification-email
Teams→members→email (API else login@domain); fail if empty.
Attach build-artifacts.zip + separate pipeline-logs.zip; SMTP STARTTLS.
Map org SMTP_* + ORG_READ_TOKEN (read:org+actions:read) via inputs.
if: always(); no @vN — pin SHA when external.
```

## Related

- Concept: [GitHub Actions Domain](/vault/concepts/github-actions.md)
- Concept: [GHA CI pipeline recipe](/vault/concepts/gha-ci-pipeline-recipe.md)
- Playbook: [Author GHA Composite Action](/vault/playbooks/author-gha-composite-action.md)
- System: [gha-reusable-actions-workflows](/vault/systems/gha-reusable-actions-workflows.md)
- Standards: [GHA SPVS YAML](/standards/gha-spvs-yaml.md), [GHA component layout](/standards/gha-component-layout.md)
- Reference: [GHA action pin catalog](/vault/references/gha-action-pin-catalog.md)
