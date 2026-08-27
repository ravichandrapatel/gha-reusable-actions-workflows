"""
FILE_NAME: read_maven_pom.py
DESCRIPTION: Extract Maven POM groupId, artifactId, packaging, project version, and multi-module flag.
VERSION: 1.2.0
AUTHORS: DevOps Team
"""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path

import defusedxml.ElementTree as ET

DEFAULT_PACKAGING = "jar"


def _tag(el: ET.Element) -> str:
    return el.tag.rsplit("}", 1)[-1]


def _child(el: ET.Element | None, name: str) -> ET.Element | None:
    if el is None:
        return None
    for child in el:
        if _tag(child) == name:
            return child
    return None


def _text(el: ET.Element | None) -> str:
    return "" if el is None or el.text is None else el.text.strip()


def _project_version(raw: str) -> str:
    """Project <version> only; drop a trailing -SNAPSHOT. Does not use parent."""
    value = raw.strip()
    suffix = "-SNAPSHOT"
    if value.casefold().endswith(suffix.casefold()):
        value = value[: -len(suffix)].strip()
    return value


def _is_multi_module(root: ET.Element) -> bool:
    modules_el = _child(root, "modules")
    if modules_el is None:
        return False
    for child in modules_el:
        if _tag(child) == "module" and _text(child):
            return True
    return False


def _resolve_pom(pom_file: str, working_directory: str) -> Path:
    rel = pom_file.strip() or "pom.xml"
    if rel.startswith("/") or rel.startswith("\\") or ".." in Path(rel).parts:
        print("ERROR: --pom must be a relative path without '..'", file=sys.stderr)
        raise ValueError("invalid pom path")
    root = (
        working_directory.strip()
        or os.environ.get("GITHUB_WORKSPACE", "").strip()
        or str(Path.cwd())
    )
    return Path(root) / rel


def read_pom(path: Path) -> dict[str, str]:
    try:
        root = ET.parse(path).getroot()
    except (OSError, ET.ParseError) as exc:
        print(f"ERROR: could not parse {path}: {exc}", file=sys.stderr)
        raise

    parent_el = _child(root, "parent")
    group_id = _text(_child(root, "groupId")) or _text(_child(parent_el, "groupId"))
    artifact_id = _text(_child(root, "artifactId"))
    packaging = _text(_child(root, "packaging")).casefold() or DEFAULT_PACKAGING
    version = _project_version(_text(_child(root, "version")))
    is_multi_module = "true" if _is_multi_module(root) else "false"

    missing = [
        name
        for name, value in (
            ("groupId", group_id),
            ("artifactId", artifact_id),
            ("version", version),
        )
        if not value
    ]
    if missing:
        print(
            f"ERROR: {path} missing {', '.join(missing)} "
            "(project <version> only; parent version is not used)",
            file=sys.stderr,
        )
        raise ValueError("invalid pom.xml")

    return {
        "group_id": group_id,
        "artifact_id": artifact_id,
        "packaging": packaging,
        "version": version,
        "is_multi_module": is_multi_module,
    }


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Extract groupId, artifactId, packaging, version, and multi-module flag from a Maven POM"
    )
    parser.add_argument("--pom", default="pom.xml")
    parser.add_argument("--working-directory", default="")
    parser.add_argument("--output", default="")
    args = parser.parse_args()

    try:
        path = _resolve_pom(args.pom, args.working_directory)
    except ValueError:
        return 1
    if not path.is_file():
        print(f"ERROR: missing {path}", file=sys.stderr)
        return 1

    try:
        outputs = read_pom(path)
    except (OSError, ET.ParseError, ValueError):
        return 1

    for key, value in outputs.items():
        print(f"{key} : {value}")
    if args.output.strip():
        with open(args.output.strip(), "a", encoding="utf-8") as fh:
            fh.writelines(f"{key}={value}\n" for key, value in outputs.items())
    return 0


if __name__ == "__main__":
    sys.exit(main())
