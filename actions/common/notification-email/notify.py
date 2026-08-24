"""
FILE_NAME: notify.py
DESCRIPTION: Resolve GitHub team member emails and send SMTP notification mail.
VERSION: 1.0.0
AUTHORS: DevOps Team
"""

from __future__ import annotations

import argparse
import json
import os
import re
import smtplib
import ssl
import sys
import zipfile
from email.message import EmailMessage
from pathlib import Path
from typing import Any, Callable, Mapping
from urllib.error import HTTPError, URLError
from urllib.parse import urlparse
from urllib.request import HTTPRedirectHandler, Request, build_opener

PROJECT_PREFIX = "[NOTIFICATION-EMAIL]"
EXIT_CODE_SUCCESS = 0
EXIT_CODE_ERROR = 1
DEFAULT_API_URL = "https://api.github.com"
DEFAULT_SMTP_PORT = 587
MAX_ATTACHMENT_BYTES = 25 * 1024 * 1024
EMAIL_RE = re.compile(r"^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$")
REPO_FULL_RE = re.compile(r"^([A-Za-z0-9_.-]+)/([A-Za-z0-9_.-]+)$")
REPO_NAME_RE = re.compile(r"^[A-Za-z0-9_.-]+$")
PLACEHOLDER_DOUBLE_RE = re.compile(r"\{\{\s*([A-Za-z_][A-Za-z0-9_]*)\s*\}\}")
PLACEHOLDER_SINGLE_RE = re.compile(r"\{([A-Za-z_][A-Za-z0-9_]*)\}")
HTML_HINT_RE = re.compile(
    r"<(?:!doctype\s+html|html\b|head\b|body\b|div\b|p\b|table\b|h[1-6]\b|span\b|br\b|hr\b|style\b)",
    re.I,
)
DEFAULT_SUBJECT = "[{event_name}] {repository} #{run_number}"
DEFAULT_BODY = """GitHub Actions notification

Repository: {repository}
Workflow: {workflow}
Ref: {ref}
SHA: {sha}
Actor: {actor}
Event: {event_name}
Run: {run_url}
"""


def _log(message: str) -> None:
    """INTENT: Print a breadcrumb line.
    INPUT: message
    OUTPUT: none
    ROLE: logger
    SIDE_EFFECTS: stdout
    """
    print(f"{PROJECT_PREFIX} {message}")


def as_bool(value: str) -> bool:
    """INTENT: Parse a YAML/CLI boolean string.
    INPUT: raw flag
    OUTPUT: True for 1/true/yes/on
    ROLE: helper
    SIDE_EFFECTS: none
    """
    return str(value).strip().lower() in {"1", "true", "yes", "on"}


def parse_recipients(raw: str) -> list[str]:
    """INTENT: Split and validate explicit recipient addresses.
    INPUT: comma/semicolon/newline/space separated emails
    OUTPUT: de-duplicated emails in original case
    ROLE: helper
    SIDE_EFFECTS: none
    """
    found: list[str] = []
    seen: set[str] = set()
    for part in re.split(r"[,\s;]+", raw or ""):
        email = part.strip()
        if not email:
            continue
        if not EMAIL_RE.match(email):
            raise ValueError(f"invalid email address: {email}")
        key = email.lower()
        if key in seen:
            continue
        seen.add(key)
        found.append(email)
    return found


def parse_repository(raw: str, default_owner: str = "") -> tuple[str, str]:
    """INTENT: Parse owner/name or a bare repo name.
    INPUT: repository string, optional owner fallback
    OUTPUT: (owner, repo)
    ROLE: helper
    SIDE_EFFECTS: none
    """
    text = (raw or "").strip()
    if not text:
        raise ValueError("repository is required")
    full = REPO_FULL_RE.match(text)
    if full:
        return full.group(1), full.group(2)
    if REPO_NAME_RE.match(text):
        owner = default_owner.strip()
        if not owner:
            raise ValueError("repository name requires an owner (pass owner/repo)")
        return owner, text
    raise ValueError(f"invalid repository: {text}")


def parse_smtp_endpoint(host: str, port: int) -> tuple[str, int]:
    """INTENT: Allow host or host:port in the SMTP host field.
    INPUT: host string, default port
    OUTPUT: (hostname, port)
    ROLE: helper
    SIDE_EFFECTS: none
    """
    text = (host or "").strip()
    if not text:
        raise ValueError("smtp host is required")
    if text.count(":") == 1 and not text.startswith("["):
        name, port_s = text.rsplit(":", 1)
        if port_s.isdigit():
            return name, int(port_s)
    return text, port


def parse_template_vars(raw: str) -> dict[str, str]:
    """INTENT: Load extra template placeholders from JSON.
    INPUT: JSON object string
    OUTPUT: string key/value map
    ROLE: helper
    SIDE_EFFECTS: none
    """
    text = (raw or "").strip() or "{}"
    try:
        data = json.loads(text)
    except json.JSONDecodeError as exc:
        raise ValueError(f"template_vars must be JSON: {exc}") from exc
    if not isinstance(data, dict):
        raise ValueError("template_vars must be a JSON object")
    return {str(key): "" if value is None else str(value) for key, value in data.items()}


def render_template(template: str, context: Mapping[str, str]) -> str:
    """INTENT: Substitute {{name}} then {name} placeholders.
    INPUT: template text, context map
    OUTPUT: rendered text; unknown keys become empty
    ROLE: helper
    SIDE_EFFECTS: none
    """

    def repl(match: re.Match[str]) -> str:
        return context.get(match.group(1), "")

    text = PLACEHOLDER_DOUBLE_RE.sub(repl, template)
    return PLACEHOLDER_SINGLE_RE.sub(repl, text)


def looks_like_html(text: str) -> bool:
    """INTENT: Detect an HTML email template from markup.
    INPUT: template text
    OUTPUT: True when common HTML tags are present
    ROLE: helper
    SIDE_EFFECTS: none
    """
    return bool(HTML_HINT_RE.search(text or ""))


def _read_optional_file(path_text: str, label: str) -> str:
    """INTENT: Read a template path when set.
    INPUT: path string, error label
    OUTPUT: file text or empty
    ROLE: helper
    SIDE_EFFECTS: reads disk
    """
    raw = (path_text or "").strip()
    if not raw:
        return ""
    path = Path(raw)
    if not path.is_file():
        raise ValueError(f"{label} not found: {path}")
    return path.read_text(encoding="utf-8")


def has_body_placeholder(template: str) -> bool:
    """INTENT: Detect {body} / {{body}} in a layout template.
    INPUT: template text
    OUTPUT: True when the file expects an inline body
    ROLE: helper
    SIDE_EFFECTS: none
    """
    text = template or ""
    return "{body}" in text or "{{body}}" in text


def load_body_template(
    body: str,
    template_file: str,
    body_file: str = "",
) -> tuple[str, str, bool]:
    """INTENT: Load an inline body template and/or a template file.
    INPUT: inline body, template_file path, optional body_file path
    OUTPUT: (layout_or_body, inline_body_for_{body}, html_hint)
    ROLE: helper
    SIDE_EFFECTS: may read template_file / body_file
    """
    inline = _read_optional_file(body_file, "body file") or (body or "")
    inline = inline.strip("\n")
    file_text = _read_optional_file(template_file, "template file")
    html = looks_like_html(inline) or looks_like_html(file_text)
    if file_text:
        suffix_html = Path(template_file.strip()).suffix.lower() in {".html", ".htm"}
        html = html or suffix_html
        if inline and has_body_placeholder(file_text):
            return file_text, inline, html
        if inline:
            return inline, "", html
        return file_text, "", html
    return (inline or DEFAULT_BODY), "", html


def merge_recipients(*groups: list[str]) -> list[str]:
    """INTENT: Concatenate recipient lists without case-insensitive dupes.
    INPUT: one or more email lists
    OUTPUT: stable-order unique emails
    ROLE: helper
    SIDE_EFFECTS: none
    """
    merged: list[str] = []
    seen: set[str] = set()
    for group in groups:
        for email in group:
            key = email.lower()
            if key in seen:
                continue
            seen.add(key)
            merged.append(email)
    return merged


def member_email(login: str, api_email: str, email_domain: str) -> str:
    """INTENT: Prefer GitHub API email, else login@domain.
    INPUT: login, public/API email, fallback domain
    OUTPUT: email or empty when neither is usable
    ROLE: helper
    SIDE_EFFECTS: none
    """
    public = (api_email or "").strip()
    if public and EMAIL_RE.match(public):
        return public
    domain = (email_domain or "").strip().lstrip("@")
    login_s = (login or "").strip()
    if login_s and domain:
        candidate = f"{login_s}@{domain}"
        if EMAIL_RE.match(candidate):
            return candidate
    return ""


class StripAuthRedirectHandler(HTTPRedirectHandler):
    """Drop Authorization when GitHub redirects artifact/log URLs off-host."""

    def redirect_request(self, req, fp, code, msg, headers, newurl):  # type: ignore[no-untyped-def]
        new_req = super().redirect_request(req, fp, code, msg, headers, newurl)
        if new_req is None:
            return None
        old_host = urlparse(req.full_url).hostname
        new_host = urlparse(new_req.full_url).hostname
        if old_host != new_host:
            for hdr in ("Authorization", "authorization"):
                if hdr in new_req.headers:
                    del new_req.headers[hdr]
                if hdr in new_req.unredirected_hdrs:
                    del new_req.unredirected_hdrs[hdr]
        return new_req


class GithubClient:
    """INTENT: Minimal GitHub REST client (stdlib urllib).
    INPUT: api_url, token
    OUTPUT: JSON/bytes helpers
    ROLE: api client
    SIDE_EFFECTS: HTTPS calls
    """

    def __init__(self, api_url: str, token: str, timeout: int = 30) -> None:
        self.api_url = (api_url or DEFAULT_API_URL).rstrip("/")
        self.token = token
        self.timeout = timeout
        self._opener = build_opener(StripAuthRedirectHandler)

    def _headers(self) -> dict[str, str]:
        headers = {
            "Accept": "application/vnd.github+json",
            "User-Agent": "gha-notification-email",
            "X-GitHub-Api-Version": "2022-11-28",
        }
        if self.token:
            headers["Authorization"] = f"Bearer {self.token}"
        return headers

    def _request(self, url: str, accept: str | None = None) -> tuple[int, bytes, Mapping[str, str]]:
        parsed = urlparse(url)
        if parsed.scheme not in {"http", "https"}:
            raise RuntimeError("refusing non-http(s) GitHub URL")
        headers = self._headers()
        if accept:
            headers["Accept"] = accept
        req = Request(url, headers=headers, method="GET")
        try:
            with self._opener.open(req, timeout=self.timeout) as resp:  # nosec B310
                return int(resp.status), resp.read(), resp.headers
        except HTTPError as exc:
            body = exc.read()
            raise RuntimeError(f"GitHub API {exc.code} for {url}: {body[:300]!r}") from exc
        except URLError as exc:
            raise RuntimeError(f"GitHub API request failed for {url}: {exc}") from exc

    def _abs(self, path_or_url: str) -> str:
        if path_or_url.startswith("http://") or path_or_url.startswith("https://"):
            return path_or_url
        return f"{self.api_url}{path_or_url}"

    def get_json(self, path: str) -> Any:
        """INTENT: GET a JSON object.
        INPUT: path or absolute URL
        OUTPUT: parsed JSON
        ROLE: api client
        SIDE_EFFECTS: HTTP GET
        """
        _status, body, _headers = self._request(self._abs(path))
        if not body:
            return None
        return json.loads(body.decode("utf-8"))

    def get_paginated(self, path: str, list_key: str = "") -> list[Any]:
        """INTENT: Follow Link rel=next; unwrap a named list key when set.
        INPUT: path, optional object list key (artifacts)
        OUTPUT: concatenated list
        ROLE: api client
        SIDE_EFFECTS: HTTP GET
        """
        items: list[Any] = []
        url = self._abs(path)
        while url:
            _status, body, headers = self._request(url)
            payload: Any = json.loads(body.decode("utf-8")) if body else []
            if list_key:
                if not isinstance(payload, dict):
                    raise RuntimeError(f"expected object with {list_key} from {url}")
                chunk = payload.get(list_key) or []
            else:
                chunk = payload
            if not isinstance(chunk, list):
                raise RuntimeError(f"expected list from {url}")
            items.extend(chunk)
            url = _next_link(headers)
        return items

    def get_bytes(self, path: str) -> bytes:
        """INTENT: GET a binary payload (artifact/log zip).
        INPUT: path
        OUTPUT: bytes
        ROLE: api client
        SIDE_EFFECTS: HTTP GET
        """
        _status, body, _headers = self._request(
            self._abs(path),
            accept="application/octet-stream",
        )
        return body


def _next_link(headers: Mapping[str, str]) -> str:
    link = headers.get("Link") or headers.get("link") or ""
    for part in link.split(","):
        if 'rel="next"' in part:
            start = part.find("<") + 1
            end = part.find(">")
            if start > 0 and end > start:
                return part[start:end]
    return ""


def resolve_team_emails(
    client: GithubClient,
    owner: str,
    repo: str,
    email_domain: str,
) -> tuple[list[str], list[str]]:
    """INTENT: Expand repo teams to member email addresses.
    INPUT: client, owner, repo, fallback domain
    OUTPUT: (emails, team slugs)
    ROLE: resolver
    SIDE_EFFECTS: GitHub API reads
    """
    try:
        teams = client.get_paginated(f"/repos/{owner}/{repo}/teams?per_page=100")
    except RuntimeError as exc:
        raise RuntimeError(
            "failed to list repository teams (token needs read:org; "
            f"GITHUB_TOKEN is often insufficient): {exc}"
        ) from exc
    slugs: list[str] = []
    emails: list[str] = []
    seen_logins: set[str] = set()
    for team in teams:
        slug = str(team.get("slug") or "").strip()
        if not slug:
            continue
        slugs.append(slug)
        members = client.get_paginated(f"/orgs/{owner}/teams/{slug}/members?per_page=100")
        for member in members:
            login = str(member.get("login") or "").strip()
            if not login or login.lower() in seen_logins:
                continue
            seen_logins.add(login.lower())
            profile = client.get_json(f"/users/{login}") or {}
            api_email = str(profile.get("email") or member.get("email") or "")
            resolved = member_email(login, api_email, email_domain)
            if resolved:
                emails.append(resolved)
            else:
                _log(f"no email for {login}; set email_domain or a public GitHub email")
    return merge_recipients(emails), slugs


def collect_attachments(
    client: GithubClient,
    owner: str,
    repo: str,
    run_id: str,
    attach_artifacts: bool,
    attach_logs: bool,
    artifact_name_filter: str,
    workdir: Path,
) -> list[tuple[str, bytes]]:
    """INTENT: Download run artifacts and/or pipeline logs as zip bytes.
    INPUT: client, repo identity, run id, flags, workdir
    OUTPUT: (filename, bytes) pairs that fit the size cap
    ROLE: helper
    SIDE_EFFECTS: GitHub API reads; may write a combined zip
    """
    attachments: list[tuple[str, bytes]] = []
    total = 0
    name_filter = artifact_name_filter.strip()
    if attach_artifacts and run_id:
        try:
            artifacts = client.get_paginated(
                f"/repos/{owner}/{repo}/actions/runs/{run_id}/artifacts?per_page=100",
                list_key="artifacts",
            )
        except RuntimeError as exc:
            _log(f"skipping artifacts: {exc}")
            artifacts = []
        blobs: list[tuple[str, bytes]] = []
        for art in artifacts:
            if art.get("expired"):
                continue
            name = str(art.get("name") or "artifact")
            if name_filter and name_filter not in name:
                continue
            art_id = art.get("id")
            if art_id is None:
                continue
            try:
                blob = client.get_bytes(f"/repos/{owner}/{repo}/actions/artifacts/{art_id}/zip")
            except RuntimeError as exc:
                _log(f"skipping artifact {name}: {exc}")
                continue
            blobs.append((f"{name}.zip", blob))
        if blobs:
            combined = _zip_named_blobs(workdir / "build-artifacts.zip", blobs)
            attachments.append(("build-artifacts.zip", combined))
            total += len(combined)
    if attach_logs and run_id:
        try:
            logs = client.get_bytes(f"/repos/{owner}/{repo}/actions/runs/{run_id}/logs")
        except RuntimeError as exc:
            _log(f"skipping pipeline logs: {exc}")
            logs = b""
        if logs:
            if total + len(logs) > MAX_ATTACHMENT_BYTES:
                _log("skipping pipeline-logs.zip; attachments would exceed 25MB")
            else:
                attachments.append(("pipeline-logs.zip", logs))
    if total > MAX_ATTACHMENT_BYTES:
        _log("dropping attachments; combined size exceeds 25MB")
        return []
    return attachments


def _zip_named_blobs(path: Path, blobs: list[tuple[str, bytes]]) -> bytes:
    path.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(path, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        for name, blob in blobs:
            zf.writestr(name, blob)
    data = path.read_bytes()
    path.unlink(missing_ok=True)
    return data


def build_message(
    subject: str,
    body: str,
    mail_from: str,
    recipients: list[str],
    html: bool,
    attachments: list[tuple[str, bytes]],
) -> EmailMessage:
    """INTENT: Assemble the MIME message.
    INPUT: headers, body, recipients, attachments
    OUTPUT: EmailMessage
    ROLE: helper
    SIDE_EFFECTS: none
    """
    msg = EmailMessage()
    msg["Subject"] = subject
    msg["From"] = mail_from
    msg["To"] = ", ".join(recipients)
    if html:
        msg.set_content(body, subtype="html")
    else:
        msg.set_content(body)
    for filename, blob in attachments:
        maintype, subtype = ("application", "zip") if filename.endswith(".zip") else ("application", "octet-stream")
        msg.add_attachment(blob, maintype=maintype, subtype=subtype, filename=filename)
    return msg


def send_smtp(
    host: str,
    port: int,
    username: str,
    password: str,
    use_tls: bool,
    message: EmailMessage,
) -> None:
    """INTENT: Send one message over SMTP STARTTLS (or plain).
    INPUT: SMTP settings and message
    OUTPUT: none
    ROLE: mailer
    SIDE_EFFECTS: SMTP network I/O
    """
    context = ssl.create_default_context()
    with smtplib.SMTP(host, port, timeout=60) as smtp:
        if use_tls:
            smtp.starttls(context=context)
        if username:
            smtp.login(username, password)
        smtp.send_message(message)


def write_outputs(path: str, outputs: dict[str, str]) -> None:
    """INTENT: Append action outputs when --output is set.
    INPUT: file path, key/value map
    OUTPUT: none
    ROLE: helper
    SIDE_EFFECTS: appends to output file
    """
    with open(path, "a", encoding="utf-8") as fh:
        for key, value in outputs.items():
            if "\n" in value:
                fh.write(f"{key}<<EOF\n{value}\nEOF\n")
            else:
                fh.write(f"{key}={value}\n")


def build_context(args: argparse.Namespace, extra: dict[str, str]) -> dict[str, str]:
    """INTENT: Merge GitHub fields with template_vars.
    INPUT: parsed args, extra vars
    OUTPUT: placeholder context
    ROLE: helper
    SIDE_EFFECTS: none
    """
    repository = args.repository.strip()
    server = args.server_url.strip().rstrip("/") or "https://github.com"
    run_id = args.run_id.strip()
    run_url = f"{server}/{repository}/actions/runs/{run_id}" if repository and run_id else ""
    ctx = {
        "repository": repository,
        "sha": args.sha.strip(),
        "ref": args.ref.strip(),
        "actor": args.actor.strip(),
        "run_id": run_id,
        "run_number": args.run_number.strip(),
        "run_url": run_url,
        "server_url": server,
        "event_name": args.event_name.strip(),
        "workflow": args.workflow.strip(),
        "extra": extra.get("extra", ""),
    }
    ctx.update(extra)
    return ctx


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    """INTENT: Parse standalone CLI flags.
    INPUT: argv or sys.argv
    OUTPUT: argparse.Namespace
    ROLE: cli
    SIDE_EFFECTS: none
    """
    parser = argparse.ArgumentParser(description="Send SMTP mail to GitHub team members and/or explicit recipients")
    parser.add_argument("--recipients", default="", help="Direct emails; skips GitHub teams when --resolve-teams false")
    parser.add_argument("--resolve-teams", default="true", help="true to expand GitHub teams on --repository")
    parser.add_argument("--repository", default="", help="owner/repo or repo name (owner from --repository-owner)")
    parser.add_argument("--repository-owner", default="", help="Owner used when --repository is a bare name")
    parser.add_argument("--github-token", default="", help="Token with read:org (and actions:read for attachments)")
    parser.add_argument("--github-api-url", default="", help="GitHub API base; default api.github.com")
    parser.add_argument("--email-domain", default="", help="Fallback {login}@{domain} when GitHub email is empty")
    parser.add_argument("--smtp-host", default="", help="SMTP hostname or host:port")
    parser.add_argument("--smtp-port", default=str(DEFAULT_SMTP_PORT), help="SMTP port (ignored if host includes :port)")
    parser.add_argument("--smtp-username", default="", help="SMTP username")
    parser.add_argument("--smtp-password", default="", help="SMTP password")
    parser.add_argument("--smtp-from", default="", help="From address")
    parser.add_argument("--smtp-use-tls", default="true", help="STARTTLS before login")
    parser.add_argument("--subject", default="", help="Subject template")
    parser.add_argument("--body", default="", help="Custom email template (text or HTML) provided as the message body")
    parser.add_argument("--body-file", default="", help="Read the body template from a file (used by the composite for multiline HTML)")
    parser.add_argument("--template-file", default="", help="Optional layout file; {body} is filled from --body when both are set")
    parser.add_argument("--html", default="false", help="Send body as text/html")
    parser.add_argument("--template-vars", default="{}", help="JSON object merged into template context")
    parser.add_argument("--attach-artifacts", default="true", help="Attach run artifacts as build-artifacts.zip")
    parser.add_argument("--attach-logs", default="true", help="Attach Actions logs as pipeline-logs.zip")
    parser.add_argument("--artifact-name-filter", default="", help="Substring filter on artifact names")
    parser.add_argument("--run-id", default="", help="Actions run id for attachments")
    parser.add_argument("--run-number", default="", help="Actions run number for templates")
    parser.add_argument("--sha", default="", help="Commit SHA for templates")
    parser.add_argument("--ref", default="", help="Git ref for templates")
    parser.add_argument("--actor", default="", help="Actor for templates")
    parser.add_argument("--server-url", default="", help="GitHub server URL")
    parser.add_argument("--event-name", default="", help="Event name for templates")
    parser.add_argument("--workflow", default="", help="Workflow name for templates")
    parser.add_argument("--output", default="", help="GITHUB_OUTPUT path; omit to print JSON")
    parser.add_argument("--dry-run", default="false", help="Resolve and render without SMTP or downloads")
    parser.add_argument("--action-path", default="", help="Unused; accepted for house CLI consistency")
    return parser.parse_args(argv)


def run(
    args: argparse.Namespace,
    client: GithubClient | None = None,
    smtp_send: Callable[..., None] | None = None,
) -> int:
    """INTENT: Resolve recipients, render the template, optionally send SMTP.
    INPUT: parsed args, optional injected client and mailer
    OUTPUT: process exit code
    ROLE: orchestrator
    SIDE_EFFECTS: GitHub API, SMTP, GITHUB_OUTPUT
    """
    try:
        extra = parse_template_vars(args.template_vars)
        direct = parse_recipients(args.recipients)
        resolve_teams = as_bool(args.resolve_teams)
        dry_run = as_bool(args.dry_run)
        html_flag = as_bool(args.html)
        default_owner = args.repository_owner.strip()
        repository_raw = args.repository.strip()
        owner, repo = ("", "")
        team_emails: list[str] = []
        team_slugs: list[str] = []
        if resolve_teams:
            if not repository_raw:
                raise ValueError("repository is required when resolve_teams is true")
            owner, repo = parse_repository(repository_raw, default_owner)
            token = args.github_token.strip()
            if client is None:
                api_url = args.github_api_url.strip() or os.environ.get("GITHUB_API_URL") or DEFAULT_API_URL
                client = GithubClient(api_url, token)
            team_emails, team_slugs = resolve_team_emails(client, owner, repo, args.email_domain)
        elif repository_raw:
            owner, repo = parse_repository(repository_raw, default_owner)

        recipients = merge_recipients(direct, team_emails)
        if not recipients:
            raise ValueError(
                "no recipients: pass --recipients and/or enable --resolve-teams "
                "with a token that can list teams, plus --email-domain if GitHub emails are private"
            )

        body_file = getattr(args, "body_file", "")
        layout, inline_body, html_from_template = load_body_template(
            args.body,
            args.template_file,
            body_file,
        )
        html = html_flag or html_from_template
        if not args.repository.strip() and owner and repo:
            args.repository = f"{owner}/{repo}"
        elif owner and repo:
            args.repository = f"{owner}/{repo}"
        context = build_context(args, extra)
        if inline_body:
            context["body"] = render_template(inline_body, context)
        subject = render_template(args.subject.strip() or DEFAULT_SUBJECT, context)
        body = render_template(layout, context)

        attachments: list[tuple[str, bytes]] = []
        if not dry_run and (as_bool(args.attach_artifacts) or as_bool(args.attach_logs)):
            if client is None:
                token = args.github_token.strip()
                api_url = args.github_api_url.strip() or os.environ.get("GITHUB_API_URL") or DEFAULT_API_URL
                client = GithubClient(api_url, token)
            if owner and repo and args.run_id.strip():
                attachments = collect_attachments(
                    client,
                    owner,
                    repo,
                    args.run_id.strip(),
                    as_bool(args.attach_artifacts),
                    as_bool(args.attach_logs),
                    args.artifact_name_filter,
                    Path.cwd(),
                )
            else:
                _log("skipping attachments; repository or run-id missing")

        mail_from = args.smtp_from.strip()
        sent = "false"
        if dry_run:
            _log(f"dry-run recipients={','.join(recipients)}")
            _log(f"dry-run subject={subject}")
        else:
            if not mail_from:
                raise ValueError("smtp_from is required unless dry_run is true")
            host, port = parse_smtp_endpoint(args.smtp_host, int(str(args.smtp_port).strip() or DEFAULT_SMTP_PORT))
            message = build_message(subject, body, mail_from, recipients, html, attachments)
            sender = smtp_send or send_smtp
            sender(
                host,
                port,
                args.smtp_username.strip(),
                args.smtp_password,
                as_bool(args.smtp_use_tls),
                message,
            )
            sent = "true"
            _log(f"sent to {len(recipients)} recipient(s)")

        outputs = {
            "recipients": ",".join(recipients),
            "recipient_count": str(len(recipients)),
            "sent": sent,
            "subject": subject,
            "teams": ",".join(team_slugs),
        }
        if args.output.strip():
            write_outputs(args.output.strip(), outputs)
        else:
            print(json.dumps(outputs, indent=2))
        return EXIT_CODE_SUCCESS
    except (ValueError, RuntimeError, OSError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return EXIT_CODE_ERROR


def main(argv: list[str] | None = None) -> int:
    """INTENT: CLI entrypoint.
    INPUT: argv
    OUTPUT: exit code
    ROLE: cli
    SIDE_EFFECTS: see run()
    """
    return run(parse_args(argv))


if __name__ == "__main__":
    sys.exit(main())
