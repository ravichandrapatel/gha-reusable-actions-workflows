#!/usr/bin/env bash
# Install act-platform into any GitHub Actions repo (plug-and-play).
#
# Usage:
#   ./bootstrap.sh [TARGET] [--force] [--build]
#   ./bootstrap.sh --help
#
# Copies this kit to TARGET/act-platform/ (skipped when TARGET already hosts
# this kit), installs root .actrc + .act/ examples, appends gitignore hints.
set -euo pipefail

KIT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIT_PARENT="$(cd "${KIT_ROOT}/.." && pwd)"
MARKER="# act-platform secrets"

usage() {
  cat <<'EOF'
Usage: ./bootstrap.sh [TARGET] [--force] [--build]

  TARGET   Destination repo root (default: .)
  --force  Overwrite existing .actrc / .act files
  --build  Run build-images.sh after install

Installs:
  - TARGET/act-platform/   (full kit; skipped if TARGET already hosts this kit)
  - TARGET/.actrc
  - TARGET/.act/           (events README, secrets.example, vars.example)
  - Appends gitignore.snippet to TARGET/.gitignore when marker missing
EOF
}

TARGET="."
FORCE=0
BUILD=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --force)
      FORCE=1
      shift
      ;;
    --build)
      BUILD=1
      shift
      ;;
    -*)
      echo "error: unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
    *)
      TARGET="$1"
      shift
      ;;
  esac
done

if [[ ! -d "${TARGET}" ]]; then
  echo "error: TARGET is not a directory: ${TARGET}" >&2
  exit 1
fi

TARGET_ABS="$(cd "${TARGET}" && pwd)"
DEST_KIT="${TARGET_ABS}/act-platform"
DEST_ACTRC="${TARGET_ABS}/.actrc"
DEST_ACT="${TARGET_ABS}/.act"

if [[ "${FORCE}" -ne 1 ]]; then
  if [[ -e "${DEST_ACTRC}" || -e "${DEST_ACT}" ]]; then
    echo "error: ${DEST_ACTRC} and/or ${DEST_ACT} already exist; re-run with --force to overwrite" >&2
    exit 1
  fi
fi

install_templates() {
  local dest_actrc="${DEST_ACTRC}"
  local dest_act="${DEST_ACT}"

  mkdir -p "${dest_act}/events"
  cp "${KIT_ROOT}/templates/actrc" "${dest_actrc}"
  cp "${KIT_ROOT}/templates/act/events/README.md" "${dest_act}/events/README.md"
  cp "${KIT_ROOT}/templates/act/secrets.example" "${dest_act}/secrets.example"
  cp "${KIT_ROOT}/templates/act/vars.example" "${dest_act}/vars.example"

  local gi="${TARGET_ABS}/.gitignore"
  if [[ -f "${gi}" ]] && grep -Fq "${MARKER}" "${gi}"; then
    :
  elif [[ -f "${gi}" ]]; then
    {
      echo ""
      cat "${KIT_ROOT}/templates/gitignore.snippet"
    } >>"${gi}"
  else
    cp "${KIT_ROOT}/templates/gitignore.snippet" "${gi}"
  fi
}

# Copy kit unless TARGET already is this kit's parent (avoid act-platform/act-platform).
if [[ "${TARGET_ABS}" == "${KIT_PARENT}" ]]; then
  echo "==> Host install (kit already at ${KIT_ROOT}); templates only"
else
  echo "==> Copying kit -> ${DEST_KIT}"
  mkdir -p "${DEST_KIT}"
  # Exclude nothing critical; copy tree. Do not follow into nested dest if re-run.
  if command -v rsync >/dev/null 2>&1; then
    rsync -a --delete \
      --exclude '.git' \
      "${KIT_ROOT}/" "${DEST_KIT}/"
  else
    rm -rf "${DEST_KIT}"
    mkdir -p "${DEST_KIT}"
    cp -a "${KIT_ROOT}/." "${DEST_KIT}/"
  fi
fi

install_templates

echo "==> Installed .actrc and .act/ under ${TARGET_ABS}"

if [[ "${BUILD}" -eq 1 ]]; then
  BUILD_KIT="${KIT_ROOT}"
  if [[ "${TARGET_ABS}" != "${KIT_PARENT}" ]]; then
    BUILD_KIT="${DEST_KIT}"
  fi
  echo "==> Building images via ${BUILD_KIT}/build-images.sh"
  bash "${BUILD_KIT}/build-images.sh"
fi

echo "==> Next:"
echo "    1. Install act: https://nektosact.com / https://github.com/nektos/act"
echo "    2. Build images (if not --build): ${DEST_KIT}/build-images.sh  (or ${KIT_ROOT}/build-images.sh on host)"
echo "    3. From repo root: act --list"
echo "    4. Copy .act/secrets.example -> .secrets (gitignored) as needed"
