"""
FILE_NAME: test_notify.py
DESCRIPTION: Unit tests for notification-email notify.py helpers and run().
VERSION: 1.0.0
AUTHORS: DevOps Team
"""

from __future__ import annotations

import importlib.util
import json
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("notify", ROOT / "notify.py")
assert SPEC and SPEC.loader
notify = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(notify)


class FakeGithub:
    def __init__(self, routes: dict[str, Any]) -> None:
        self.routes = routes
        self.calls: list[str] = []

    def get_paginated(self, path: str, list_key: str = "") -> list[Any]:
        self.calls.append(path)
        payload = self._lookup(path)
        if list_key:
            return list(payload.get(list_key) or [])
        return list(payload)

    def get_json(self, path: str) -> Any:
        self.calls.append(path)
        return self._lookup(path)

    def get_bytes(self, path: str) -> bytes:
        self.calls.append(path)
        payload = self._lookup(path)
        if isinstance(payload, bytes):
            return payload
        return b"zip"

    def _lookup(self, path: str) -> Any:
        for key, value in self.routes.items():
            if path.startswith(key):
                return value
        raise RuntimeError(f"unexpected path {path}")


def _args(**overrides: Any) -> SimpleNamespace:
    base = dict(
        recipients="",
        resolve_teams="true",
        repository="acme/widgets",
        repository_owner="acme",
        github_token="token",
        github_api_url="https://api.github.com",
        email_domain="example.com",
        smtp_host="smtp.example.com",
        smtp_port="587",
        smtp_username="user",
        smtp_password="secret",
        smtp_from="ci@example.com",
        smtp_use_tls="true",
        subject="",
        body="",
        body_file="",
        template_file="",
        html="false",
        template_vars="{}",
        attach_artifacts="false",
        attach_logs="false",
        artifact_name_filter="",
        run_id="99",
        run_number="7",
        sha="abc123",
        ref="refs/heads/main",
        actor="octocat",
        server_url="https://github.com",
        event_name="push",
        workflow="CI",
        output="",
        dry_run="true",
        action_path="",
    )
    base.update(overrides)
    return SimpleNamespace(**base)


class RecipientTests(unittest.TestCase):
    def test_parse_recipients_splits_and_dedupes(self) -> None:
        got = notify.parse_recipients("a@x.com, b@x.com; A@x.com\nc@x.com")
        self.assertEqual(got, ["a@x.com", "b@x.com", "c@x.com"])

    def test_parse_recipients_rejects_invalid(self) -> None:
        with self.assertRaises(ValueError):
            notify.parse_recipients("not-an-email")

    def test_merge_recipients_case_insensitive(self) -> None:
        got = notify.merge_recipients(["A@x.com"], ["a@x.com", "b@x.com"])
        self.assertEqual(got, ["A@x.com", "b@x.com"])


class RepositoryTests(unittest.TestCase):
    def test_full_name(self) -> None:
        self.assertEqual(notify.parse_repository("acme/widgets"), ("acme", "widgets"))

    def test_bare_name_uses_owner(self) -> None:
        self.assertEqual(notify.parse_repository("widgets", "acme"), ("acme", "widgets"))

    def test_bare_name_without_owner_fails(self) -> None:
        with self.assertRaises(ValueError):
            notify.parse_repository("widgets")


class TemplateTests(unittest.TestCase):
    def test_render_double_and_single_placeholders(self) -> None:
        text = notify.render_template("Hi {{actor}} / {repository}", {"actor": "a", "repository": "o/r"})
        self.assertEqual(text, "Hi a / o/r")

    def test_render_leaves_css_braces(self) -> None:
        text = notify.render_template("body { color: red; } {sha}", {"sha": "deadbeef"})
        self.assertEqual(text, "body { color: red; } deadbeef")

    def test_unknown_placeholder_empty(self) -> None:
        self.assertEqual(notify.render_template("x{missing}y", {}), "xy")

    def test_load_template_file(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "note.html"
            path.write_text("<p>{repository}</p>", encoding="utf-8")
            layout, inline, html = notify.load_body_template("", str(path))
            self.assertEqual(layout, "<p>{repository}</p>")
            self.assertEqual(inline, "")
            self.assertTrue(html)

    def test_inline_body_is_the_template(self) -> None:
        layout, inline, html = notify.load_body_template(
            '<h1>{repository}</h1><p class="x">done</p>',
            "",
        )
        self.assertIn("{repository}", layout)
        self.assertEqual(inline, "")
        self.assertTrue(html)

    def test_body_file_is_the_template(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "inline.html"
            path.write_text("<p>hello {actor}</p>", encoding="utf-8")
            layout, inline, html = notify.load_body_template("", "", str(path))
            self.assertEqual(layout, "<p>hello {actor}</p>")
            self.assertEqual(inline, "")
            self.assertTrue(html)

    def test_file_layout_inserts_body_placeholder(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "layout.html"
            path.write_text("<html><body>{body}</body></html>", encoding="utf-8")
            layout, inline, html = notify.load_body_template("<p>{repository}</p>", str(path))
            self.assertEqual(layout, "<html><body>{body}</body></html>")
            self.assertEqual(inline, "<p>{repository}</p>")
            self.assertTrue(html)

    def test_template_vars_must_be_object(self) -> None:
        with self.assertRaises(ValueError):
            notify.parse_template_vars("[1]")


class MemberEmailTests(unittest.TestCase):
    def test_prefers_api_email(self) -> None:
        self.assertEqual(
            notify.member_email("alice", "alice@corp.com", "example.com"),
            "alice@corp.com",
        )

    def test_falls_back_to_domain(self) -> None:
        self.assertEqual(notify.member_email("alice", "", "example.com"), "alice@example.com")

    def test_empty_when_neither(self) -> None:
        self.assertEqual(notify.member_email("alice", "", ""), "")


class TeamResolveTests(unittest.TestCase):
    def test_expands_teams_and_skips_duplicate_logins(self) -> None:
        client = FakeGithub(
            {
                "/repos/acme/widgets/teams": [{"slug": "platform"}, {"slug": "sre"}],
                "/orgs/acme/teams/platform/members": [{"login": "alice"}, {"login": "bob"}],
                "/orgs/acme/teams/sre/members": [{"login": "alice"}, {"login": "cara"}],
                "/users/alice": {"email": "alice@corp.com"},
                "/users/bob": {"email": None},
                "/users/cara": {"email": ""},
            }
        )
        emails, slugs = notify.resolve_team_emails(client, "acme", "widgets", "example.com")
        self.assertEqual(slugs, ["platform", "sre"])
        self.assertEqual(emails, ["alice@corp.com", "bob@example.com", "cara@example.com"])


class RunTests(unittest.TestCase):
    def test_direct_recipients_skip_github(self) -> None:
        client = FakeGithub({})
        sent: list[Any] = []
        code = notify.run(
            _args(
                resolve_teams="false",
                recipients="ops@example.com",
                dry_run="true",
                subject="[{event_name}] {repository}",
            ),
            client=client,
            smtp_send=lambda *a, **k: sent.append(a),
        )
        self.assertEqual(code, 0)
        self.assertEqual(client.calls, [])
        self.assertEqual(sent, [])

    def test_empty_recipients_fail(self) -> None:
        client = FakeGithub({"/repos/acme/widgets/teams": []})
        code = notify.run(_args(recipients="", resolve_teams="true"), client=client)
        self.assertEqual(code, 1)

    def test_merges_direct_and_team_emails(self) -> None:
        client = FakeGithub(
            {
                "/repos/acme/widgets/teams": [{"slug": "platform"}],
                "/orgs/acme/teams/platform/members": [{"login": "alice"}],
                "/users/alice": {"email": "alice@corp.com"},
            }
        )
        captured: dict[str, str] = {}

        def smtp_send(host, port, username, password, use_tls, message):  # type: ignore[no-untyped-def]
            captured["to"] = message["To"]
            captured["subject"] = message["Subject"]
            captured["host"] = host
            captured["port"] = str(port)

        code = notify.run(
            _args(
                recipients="release@example.com",
                dry_run="false",
                attach_artifacts="false",
                attach_logs="false",
                subject="go {repository}",
            ),
            client=client,
            smtp_send=smtp_send,
        )
        self.assertEqual(code, 0)
        self.assertIn("release@example.com", captured["to"])
        self.assertIn("alice@corp.com", captured["to"])
        self.assertEqual(captured["subject"], "go acme/widgets")
        self.assertEqual(captured["host"], "smtp.example.com")
        self.assertEqual(captured["port"], "587")

    def test_other_repo_name_uses_owner(self) -> None:
        client = FakeGithub(
            {
                "/repos/acme/other-service/teams": [{"slug": "platform"}],
                "/orgs/acme/teams/platform/members": [{"login": "bob"}],
                "/users/bob": {"email": "bob@corp.com"},
            }
        )
        code = notify.run(
            _args(repository="other-service", repository_owner="acme", dry_run="true"),
            client=client,
        )
        self.assertEqual(code, 0)
        self.assertTrue(any(c.startswith("/repos/acme/other-service/teams") for c in client.calls))

    def test_inline_html_body_template(self) -> None:
        captured: dict[str, str] = {}

        def smtp_send(host, port, username, password, use_tls, message):  # type: ignore[no-untyped-def]
            captured["body"] = message.get_body(preferencelist=("html", "plain")).get_content()
            captured["subtype"] = message.get_body(preferencelist=("html", "plain")).get_content_type()

        code = notify.run(
            _args(
                resolve_teams="false",
                recipients="ops@example.com",
                dry_run="false",
                body='<h1>"{repository}"</h1><p>conclusion={{conclusion}}</p>',
                template_vars='{"conclusion":"failure"}',
            ),
            client=FakeGithub({}),
            smtp_send=smtp_send,
        )
        self.assertEqual(code, 0)
        self.assertEqual(captured["subtype"], "text/html")
        self.assertIn('"acme/widgets"', captured["body"])
        self.assertIn("failure", captured["body"])

    def test_layout_file_with_inline_body(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "layout.html"
            path.write_text("<div>{body}</div>", encoding="utf-8")
            captured: dict[str, str] = {}

            def smtp_send(host, port, username, password, use_tls, message):  # type: ignore[no-untyped-def]
                captured["body"] = message.get_body(preferencelist=("html", "plain")).get_content()

            code = notify.run(
                _args(
                    resolve_teams="false",
                    recipients="ops@example.com",
                    dry_run="false",
                    template_file=str(path),
                    body="<p>{workflow}</p>",
                ),
                client=FakeGithub({}),
                smtp_send=smtp_send,
            )
            self.assertEqual(code, 0)
            self.assertIn("<div><p>CI</p></div>", captured["body"])

    def test_custom_template_file_and_vars(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "mail.html"
            path.write_text("<h1>{{conclusion}}</h1><p>{repository}</p>", encoding="utf-8")
            out = Path(tmp) / "github_output"
            captured: dict[str, str] = {}

            def smtp_send(host, port, username, password, use_tls, message):  # type: ignore[no-untyped-def]
                captured["body"] = message.get_body(preferencelist=("html", "plain")).get_content()
                captured["subtype"] = message.get_body(preferencelist=("html", "plain")).get_content_type()

            code = notify.run(
                _args(
                    resolve_teams="false",
                    recipients="ops@example.com",
                    dry_run="false",
                    template_file=str(path),
                    template_vars=json.dumps({"conclusion": "failure"}),
                    output=str(out),
                ),
                client=FakeGithub({}),
                smtp_send=smtp_send,
            )
            self.assertEqual(code, 0)
            self.assertIn("failure", captured["body"])
            self.assertIn("acme/widgets", captured["body"])
            self.assertEqual(captured["subtype"], "text/html")
            text = out.read_text(encoding="utf-8")
            self.assertIn("sent=true", text)
            self.assertIn("recipient_count=1", text)

    def test_smtp_host_port_split(self) -> None:
        self.assertEqual(notify.parse_smtp_endpoint("mail.example.com:2525", 587), ("mail.example.com", 2525))


if __name__ == "__main__":
    unittest.main()
