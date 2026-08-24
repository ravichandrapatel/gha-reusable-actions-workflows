"""
FILE_NAME: ensure_tags.py
DESCRIPTION: Merge organizations/product/platform tags onto a SonarQube project.
VERSION: 1.0.0
AUTHORS: DevOps Team
"""

from __future__ import annotations

import argparse
import base64
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

TAG_RE = re.compile(r"[^a-z0-9_+#./-]+")
PROJECT_KEY_RE = re.compile(r"^[A-Za-z0-9_.:-]+$")


def sanitize_segment(value: str) -> str:
    """INTENT: Make a SonarQube-safe tag segment.
    INPUT: raw organization, product, or platform value
    OUTPUT: lowercase hyphenated segment
    ROLE: helper
    SIDE_EFFECTS: none
    """
    text = TAG_RE.sub("-", value.strip().lower())
    text = re.sub(r"-{2,}", "-", text).strip("-")
    if not text:
        raise ValueError("tag segment is empty after sanitize")
    return text[:80]


def desired_tags(organization: str, product: str, platform: str) -> list[str]:
    """INTENT: Build the three required project tags.
    INPUT: organization, product, platform
    OUTPUT: [organizations-*, product-*, platform-*]
    ROLE: helper
    SIDE_EFFECTS: none
    """
    return [
        f"organizations-{sanitize_segment(organization)}",
        f"product-{sanitize_segment(product)}",
        f"platform-{sanitize_segment(platform)}",
    ]


def merge_tags(existing: list[str], wanted: list[str]) -> tuple[list[str], list[str], list[str]]:
    """INTENT: Add missing wanted tags; keep unmatched existing tags.
    INPUT: current tags, desired tags
    OUTPUT: (final, added, matched)
    ROLE: helper
    SIDE_EFFECTS: none
    """
    current = [str(item).strip() for item in existing if str(item).strip()]
    seen = {item.lower() for item in current}
    added: list[str] = []
    matched: list[str] = []
    final = list(current)
    for tag in wanted:
        if tag.lower() in seen:
            matched.append(tag)
            continue
        added.append(tag)
        final.append(tag)
        seen.add(tag.lower())
    return final, added, matched


def _auth_headers(token: str) -> dict[str, str]:
    basic = base64.b64encode(f"{token}:".encode("utf-8")).decode("ascii")
    return {
        "Authorization": f"Basic {basic}",
        "Accept": "application/json",
    }


def _request(
    method: str,
    url: str,
    token: str,
    data: bytes | None = None,
    content_type: str = "",
) -> tuple[int, str]:
    headers = _auth_headers(token)
    if content_type:
        headers["Content-Type"] = content_type
    parsed = urllib.parse.urlparse(url)
    if parsed.scheme not in {"http", "https"}:
        raise RuntimeError("refusing non-http(s) SonarQube URL")
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:  # nosec B310
            body = resp.read().decode("utf-8", errors="replace")
            return int(resp.status), body
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        return int(exc.code), body


def fetch_tags(host: str, token: str, project_key: str, attempts: int = 5) -> list[str]:
    """INTENT: Read current tags; retry while the project is not visible yet.
    INPUT: host, token, project key
    OUTPUT: existing tags
    ROLE: sonar api client
    SIDE_EFFECTS: HTTP GET to SonarQube
    """
    query = urllib.parse.urlencode({"component": project_key})
    url = f"{host}/api/components/show?{query}"
    last_status = 0
    last_body = ""
    for attempt in range(1, attempts + 1):
        status, body = _request("GET", url, token)
        last_status, last_body = status, body
        if status == 200:
            payload = json.loads(body)
            component = payload.get("component")
            if not isinstance(component, dict):
                raise RuntimeError("SonarQube components/show returned no component")
            tags = component.get("tags") or []
            if not isinstance(tags, list):
                raise RuntimeError("SonarQube component tags were not a list")
            return [str(item) for item in tags]
        if status in {401, 403}:
            raise RuntimeError(
                f"SonarQube auth failed ({status}); token needs Administer on the project"
            )
        if status == 404 and attempt < attempts:
            print(f"project not visible yet (attempt {attempt}/{attempts}); retrying", file=sys.stderr)
            time.sleep(2)
            continue
        raise RuntimeError(f"SonarQube components/show failed ({last_status}): {last_body[:300]}")
    raise RuntimeError(f"SonarQube components/show failed ({last_status}): {last_body[:300]}")


def set_tags(host: str, token: str, project_key: str, tags: list[str]) -> None:
    """INTENT: Replace the project tag set with the merged list.
    INPUT: host, token, project key, final tags
    OUTPUT: none
    ROLE: sonar api client
    SIDE_EFFECTS: HTTP POST api/project_tags/set
    """
    url = f"{host}/api/project_tags/set"
    encoded = urllib.parse.urlencode(
        {"project": project_key, "tags": ",".join(tags)}
    ).encode("utf-8")
    status, body = _request(
        "POST",
        url,
        token,
        data=encoded,
        content_type="application/x-www-form-urlencoded",
    )
    if status in {200, 204}:
        return
    if status in {401, 403}:
        raise RuntimeError(
            f"SonarQube tag update failed ({status}); token needs Administer on the project"
        )
    raise RuntimeError(f"SonarQube project_tags/set failed ({status}): {body[:300]}")


def write_outputs(path: str, outputs: dict[str, str]) -> None:
    """INTENT: Append action outputs when --output is set.
    INPUT: file path, key/value map
    OUTPUT: none
    ROLE: helper
    SIDE_EFFECTS: appends to output file
    """
    with open(path, "a", encoding="utf-8") as fh:
        fh.writelines(f"{key}={value}\n" for key, value in outputs.items())


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Ensure organizations/product/platform tags on a SonarQube project"
    )
    parser.add_argument("--host-url", default="")
    parser.add_argument("--token", default="")
    parser.add_argument("--project-key", default="")
    parser.add_argument("--organization", default="")
    parser.add_argument("--product", default="")
    parser.add_argument("--platform", default="cap")
    parser.add_argument("--output", default="")
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print desired/merged tags without calling SonarQube",
    )
    args = parser.parse_args()

    host = args.host_url.strip().rstrip("/")
    token = args.token.strip() or os.environ.get("SONAR_TOKEN", "").strip()
    project_key = args.project_key.strip()
    organization = args.organization.strip()
    product = args.product.strip()
    platform = args.platform.strip() or "cap"

    if not project_key or not PROJECT_KEY_RE.match(project_key):
        print("ERROR: --project-key must match [A-Za-z0-9_.:-]+", file=sys.stderr)
        return 1
    if not organization or not product:
        print("ERROR: --organization and --product are required", file=sys.stderr)
        return 1
    if not args.dry_run and (not host or not token):
        print("ERROR: --host-url and --token are required unless --dry-run", file=sys.stderr)
        return 1
    if host and not host.startswith(("http://", "https://")):
        print("ERROR: --host-url must start with http:// or https://", file=sys.stderr)
        return 1

    try:
        wanted = desired_tags(organization, product, platform)
        existing = [] if args.dry_run else fetch_tags(host, token, project_key)
        final, added, matched = merge_tags(existing, wanted)
        if added and not args.dry_run:
            set_tags(host, token, project_key, final)
    except (ValueError, RuntimeError, json.JSONDecodeError, OSError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1

    outputs = {
        "tags": ",".join(final),
        "tags_added": ",".join(added),
        "tags_matched": ",".join(matched),
        "tags_updated": "true" if added and not args.dry_run else "false",
    }
    for key, value in outputs.items():
        print(f"{key} : {value}")
    if args.output.strip():
        write_outputs(args.output.strip(), outputs)
    return 0


if __name__ == "__main__":
    sys.exit(main())
