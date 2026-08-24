#!/usr/bin/env bash
# =============================================================================
# FILE_NAME: peel-stable-tags.sh
# DESCRIPTION: Recreate nested {name}/v1 or {name}-v1 tags so they point at a commit.
# VERSION: 1.0.0
# EXIT_CODES/SIGNALS: 0 ok, 1 fail, 2 usage
# AUTHORS: Platform Team
# =============================================================================
# Why: git tag -a v1 v1.5.0 nests (v1 → tag object → commit). GitHub peels it;
# nektos/act does not → @v1 "unsupported object type", @v1.5.0 works.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

PUSH=0
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage: ./act-platform/peel-stable-tags.sh [--dry-run] [--push]

  Recreate nested stable tags (* /v1 and *-v1) at the peeled commit.
  Does not change vX.Y.Z tags. Does not create a new commit.

  --dry-run   Print nested tags; do not rewrite
  --push      After rewrite, delete+push each changed tag on origin
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --push) PUSH=1; shift ;;
    *) echo "error: unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

is_nested_annotated() {
  local tag="$1"
  local inner
  if [[ "$(git cat-file -t "refs/tags/${tag}")" != "tag" ]]; then
    return 1
  fi
  inner="$(git cat-file -p "refs/tags/${tag}" | awk '/^type / { print $2; exit }')"
  [[ "${inner}" == "tag" ]]
}

peel_tag() {
  local tag="$1"
  local commit
  commit="$(git rev-parse "${tag}^{commit}")"
  echo "[PEEL] ${tag} -> ${commit}"
  if [[ "${DRY_RUN}" -eq 1 ]]; then
    return 0
  fi
  git tag -d "${tag}"
  git tag -a "${tag}" "${commit}" -m "Peel ${tag} to commit (act-compatible)"
  if [[ "$(git cat-file -p "refs/tags/${tag}" | awk '/^type / { print $2; exit }')" != "commit" ]]; then
    echo "[ERR] ${tag} still not a commit after peel" >&2
    exit 1
  fi
  if [[ "${PUSH}" -eq 1 ]]; then
    git push origin ":refs/tags/${tag}" || true
    git push origin "${tag}"
    echo "[PUSH] ${tag}"
  fi
}

mapfile -t TAGS < <(git tag -l '*/v1' -l '*-v1' | sort)
if [[ "${#TAGS[@]}" -eq 0 ]]; then
  echo "[DBG] no */v1 or *-v1 tags"
  exit 0
fi

found=0
for tag in "${TAGS[@]}"; do
  if is_nested_annotated "${tag}"; then
    found=1
    peel_tag "${tag}"
  else
    echo "[OK] ${tag} already points at a commit"
  fi
done

if [[ "${found}" -eq 0 ]]; then
  echo "[DBG] no nested stable tags"
fi
