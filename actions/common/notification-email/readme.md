# Notification Email

Composite action that sends SMTP mail to GitHub team members on a repository, explicit addresses, or both.

## Overview & context

- **Purpose**: Fan-out a pipeline (or on-demand) email after resolving recipients.
- **Scope**: Lists teams on `repository`, expands members, prefers the GitHub public/API email, else `{login}@{email_domain}`. Optional `build-artifacts.zip` and `pipeline-logs.zip`.
- **Success criteria**: At least one recipient after merge/dedupe, then SMTP STARTTLS send (unless `dry_run`).

## Metadata dashboard

| Attribute | Value |
| --- | --- |
| **Owner / Lead** | DevOps Team |
| **Service Status** | Draft (pre-release) |
| **Repository / Code** | `actions/common/notification-email` |
| **Dependencies** | Python 3 stdlib (`urllib`, `smtplib`) |

## Inputs

| Input | Required | Default | Description |
| --- | --- | --- | --- |
| `recipients` | No | `""` | Direct emails (comma / semicolon / newline). Merged with team emails unless `resolve_teams` is false. |
| `resolve_teams` | No | `true` | List GitHub teams on `repository` and expand members. |
| `repository` | No | current repo | `owner/repo` or a repo name (owner from `github.repository_owner`). |
| `github_token` | No | `github.token` | Needs `read:org` for teams; `actions:read` for attachments. |
| `github_api_url` | No | `github.api_url` | REST API base (GHES-safe). |
| `email_domain` | No | `""` | Fallback `{login}@{domain}` when GitHub email is empty. |
| `smtp_host` | No | `""` | SMTP host or `host:port`. Required unless `dry_run`. |
| `smtp_port` | No | `587` | Port when host has no `:port`. |
| `smtp_username` | No | `""` | SMTP username. |
| `smtp_password` | No | `""` | SMTP password from a secret. |
| `smtp_from` | No | `""` | From address. Required unless `dry_run`. |
| `smtp_use_tls` | No | `true` | STARTTLS before login. |
| `subject` | No | default | Subject template (`{name}` or `{{name}}`). |
| `body` | No | `""` | Custom email template as the message body (text or HTML). Placeholders `{name}` / `{{name}}`. HTML is auto-detected. |
| `template_file` | No | `""` | Optional template file when `body` is empty. If the file contains `{body}`, the `body` input is inserted there. |
| `html` | No | `false` | Force `text/html`. Otherwise HTML in `body` / `template_file` is detected. |
| `template_vars` | No | `{}` | JSON object merged into the template context. |
| `attach_artifacts` | No | `true` | Zip this run’s artifacts as `build-artifacts.zip`. |
| `attach_logs` | No | `true` | Attach run logs as `pipeline-logs.zip`. |
| `artifact_name_filter` | No | `""` | Substring filter on artifact names. |
| `dry_run` | No | `false` | Resolve + render only. |

## Outputs

| Output | Description |
| --- | --- |
| `recipients` | De-duplicated To list. |
| `recipient_count` | Count. |
| `sent` | `true` after SMTP; `false` on dry-run. |
| `subject` | Rendered subject. |
| `teams` | Team slugs that were expanded. |

## Placeholders

Templates may use `{name}` or `{{name}}`. Unknown keys become empty. Built-ins: `repository`, `sha`, `ref`, `actor`, `run_id`, `run_number`, `run_url`, `server_url`, `event_name`, `workflow`. Add more with `template_vars`.

## Usage

Current repository teams (always-on notify job). Map org secrets — the composite cannot read them itself:

```yaml
- uses: ./actions/common/notification-email
  if: always()
  with:
    github_token: ${{ secrets.ORG_READ_TOKEN }}
    email_domain: example.com
    smtp_host: ${{ secrets.SMTP_HOST }}
    smtp_username: ${{ secrets.SMTP_USERNAME }}
    smtp_password: ${{ secrets.SMTP_PASSWORD }}
    smtp_from: ci@example.com
```

Explicit recipients only (no GitHub team lookup):

```yaml
- uses: ./actions/common/notification-email
  with:
    resolve_teams: false
    recipients: |
      release-owners@example.com
      sre-oncall@example.com
    smtp_host: ${{ secrets.SMTP_HOST }}
    smtp_username: ${{ secrets.SMTP_USERNAME }}
    smtp_password: ${{ secrets.SMTP_PASSWORD }}
    smtp_from: ci@example.com
    subject: '[{event_name}] {repository} #{run_number}'
    body: |
      Pipeline finished for {repository}
      Run: {run_url}
```

Teams on another repository:

```yaml
- uses: ./actions/common/notification-email
  with:
    repository: my-org/other-service
    github_token: ${{ secrets.ORG_READ_TOKEN }}
    email_domain: example.com
    smtp_host: ${{ secrets.SMTP_HOST }}
    smtp_username: ${{ secrets.SMTP_USERNAME }}
    smtp_password: ${{ secrets.SMTP_PASSWORD }}
    smtp_from: ci@example.com
```

Custom template as `body` (text or HTML). Placeholders are substituted; HTML is auto-detected:

```yaml
- uses: ./actions/common/notification-email
  with:
    resolve_teams: false
    recipients: release-owners@example.com
    subject: '[{event_name}] {repository} #{run_number}'
    body: |
      <h1>{repository}</h1>
      <p>Workflow <strong>{workflow}</strong> finished.</p>
      <p>Actor: {actor}</p>
      <p><a href="{run_url}">Open run</a></p>
    template_vars: '{"conclusion":"failure"}'
    smtp_host: ${{ secrets.SMTP_HOST }}
    smtp_username: ${{ secrets.SMTP_USERNAME }}
    smtp_password: ${{ secrets.SMTP_PASSWORD }}
    smtp_from: ci@example.com
```

Optional layout file with `{body}` filled from the `body` input:

```yaml
- uses: ./actions/common/notification-email
  with:
    recipients: release-owners@example.com
    resolve_teams: false
    template_file: .github/mail/layout.html
    body: |
      <p>Pipeline {workflow} finished for {repository}.</p>
      <p>Conclusion: {conclusion}</p>
    template_vars: '{"conclusion":"failure"}'
    smtp_host: ${{ secrets.SMTP_HOST }}
    smtp_username: ${{ secrets.SMTP_USERNAME }}
    smtp_password: ${{ secrets.SMTP_PASSWORD }}
    smtp_from: ci@example.com
```

## Manual run

```bash
python3 -u actions/common/notification-email/notify.py \
  --resolve-teams false \
  --recipients 'you@example.com' \
  --repository owner/repo \
  --subject 'hello {repository}' \
  --body 'run {run_url}' \
  --dry-run true

python3 -m unittest discover -s actions/common/notification-email/tests -v
```

## Release

Tags after Release Manager: `notification-email/v1.0.0` (versioned), `notification-email/v1` (stable, after promote). When consumed outside this monorepo, pin a release SHA (never `@vN`).
