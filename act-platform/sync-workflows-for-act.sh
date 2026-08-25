#!/usr/bin/env bash
# =============================================================================
# FILE_NAME: sync-workflows-for-act.sh
# DESCRIPTION: Copy source workflows/ → .github/workflows/ for local act (no release).
# VERSION: 1.1.0
# EXIT_CODES/SIGNALS: 0 ok, 1 drift/error, 2 usage
# AUTHORS: Platform Team
# =============================================================================
# Architecture (unchanged):
#   Source of truth: workflows/{category}/{name}/workflow.yml
#   Live (GitHub + act): .github/workflows/{name}.yml
# Release Manager performs this copy on mode=release; this script does it locally
# so act can exercise edits before a real release.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DRY_RUN=0
CHECK=0
IF_STALE=0
TARGET_PATH=""

usage() {
  cat <<'EOF'
Usage: ./act-platform/sync-workflows-for-act.sh [options] [component_path]

  component_path  Optional. e.g. workflows/common/dummy-workflow
                  Default: sync every workflows/*/*/workflow.y{a,}ml

  --dry-run       Print planned copies; do not write
  --check         Exit 1 if any live file differs from source (no write)
  --if-stale      Copy only when live file is missing or differs from source
  -h, --help      Show help

Examples:
  ./act-platform/sync-workflows-for-act.sh
  ./act-platform/sync-workflows-for-act.sh workflows/common/dummy-workflow
  ./act-platform/sync-workflows-for-act.sh --check
  act --list   # after sync, live files are visible to act
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    --check)
      CHECK=1
      shift
      ;;
    --if-stale)
      IF_STALE=1
      shift
      ;;
    -*)
      echo "error: unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
    *)
      TARGET_PATH="$1"
      shift
      ;;
  esac
done

cd "${ROOT}"

sync_one() {
  # INTENT: Mirror one source workflow.yml into .github/workflows/{name}.yml
  # INPUT: absolute or repo-relative path to component directory
  # OUTPUT: 0; prints status lines
  local component_path="$1"
  local name src dest

  if [[ ! -d "${component_path}" ]]; then
    echo "[ERR] not a directory: ${component_path}" >&2
    return 1
  fi

  name="$(basename "${component_path}")"
  src=""
  if [[ -f "${component_path}/workflow.yml" ]]; then
    src="${component_path}/workflow.yml"
  elif [[ -f "${component_path}/workflow.yaml" ]]; then
    src="${component_path}/workflow.yaml"
  else
    echo "[ERR] no workflow.yml in ${component_path}" >&2
    return 1
  fi

  dest=".github/workflows/${name}.yml"
  mkdir -p .github/workflows

  if [[ "${CHECK}" -eq 1 ]]; then
    if [[ ! -f "${dest}" ]]; then
      echo "[DRIFT] missing live file: ${dest} (source ${src})"
      return 1
    fi
    if ! diff -q "${src}" "${dest}" >/dev/null; then
      echo "[DRIFT] ${src} != ${dest}"
      return 1
    fi
    echo "[OK] ${dest} matches ${src}"
    return 0
  fi

  if [[ "${IF_STALE}" -eq 1 && -f "${dest}" ]] && diff -q "${src}" "${dest}" >/dev/null; then
    echo "[OK] ${dest} already matches ${src}"
    return 0
  fi

  if [[ "${DRY_RUN}" -eq 1 ]]; then
    echo "[DRY] cp ${src} -> ${dest}"
    return 0
  fi

  cp "${src}" "${dest}"
  echo "[SYNC] ${src} -> ${dest}"
}

DRIFT=0

if [[ -n "${TARGET_PATH}" ]]; then
  if ! sync_one "${TARGET_PATH}"; then
    DRIFT=1
  fi
else
  shopt -s nullglob
  for dir in workflows/*/*; do
    [[ -d "${dir}" ]] || continue
    if [[ -f "${dir}/workflow.yml" || -f "${dir}/workflow.yaml" ]]; then
      if ! sync_one "${dir}"; then
        DRIFT=1
      fi
    fi
  done
  shopt -u nullglob
fi

if [[ "${CHECK}" -eq 1 && "${DRIFT}" -eq 1 ]]; then
  echo "[ERR] source/live drift detected. Run without --check to sync for act." >&2
  exit 1
fi

if [[ "${DRY_RUN}" -eq 0 && "${CHECK}" -eq 0 ]]; then
  echo "[DBG] Done. act only reads .github/workflows/ — source remains under workflows/."
  echo "[DBG] Next: act --list   or   act -l -W .github/workflows/<name>.yml"
fi
