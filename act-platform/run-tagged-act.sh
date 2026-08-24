#!/usr/bin/env bash
# =============================================================================
# FILE_NAME: run-tagged-act.sh
# DESCRIPTION: Run house workflows/actions with act, keeping @{safe_name}/vX.Y.Z refs.
# VERSION: 1.1.0
# EXIT_CODES/SIGNALS: 0 ok, 1 fail, 2 usage
# AUTHORS: Platform Team
# =============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

COMPONENT_PATH=""
WORKFLOW_FILE=""
EVENT="workflow_dispatch"
JOB=""
DRYRUN=0
LIST=0
ENSURE_TAGS=1
APP_DIR=""
MAP_DIR=""
ACT_ARGS=()

usage() {
  cat <<'EOF'
Usage: ./act-platform/run-tagged-act.sh [options] [-- extra act flags]

  --component PATH   Sync workflows/{cat}/{name} → .github/workflows/{name}.yml
  -W, --workflow FILE
                     act -W (default: .act/callers/ng-ui-build-pipeline.yml)
  -e, --event NAME   act event (default: workflow_dispatch)
  -j, --job ID       Run one job
  --list             act --list only
  --dryrun           act --dryrun (resolve tags, do not execute)
  --no-tags          Do not create missing local {safe_name}/v* tags
  --app-dir DIR      act -C DIR (caller app, e.g. temp/ng-ui-act-fixture)
  --map-dir DIR      Overlay for --local-repository (default: this clone)
  -h, --help         Show help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --component) COMPONENT_PATH="${2:?}"; shift 2 ;;
    -W|--workflow) WORKFLOW_FILE="${2:?}"; shift 2 ;;
    -e|--event) EVENT="${2:?}"; shift 2 ;;
    -j|--job) JOB="${2:?}"; shift 2 ;;
    --list) LIST=1; shift ;;
    --dryrun) DRYRUN=1; shift ;;
    --no-tags) ENSURE_TAGS=0; shift ;;
    --app-dir) APP_DIR="${2:?}"; shift 2 ;;
    --map-dir) MAP_DIR="${2:?}"; shift 2 ;;
    --) shift; ACT_ARGS+=("$@"); break ;;
    -*) echo "error: unknown option: $1" >&2; usage >&2; exit 2 ;;
    *) echo "error: unexpected argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [[ "${DOCKER_HOST:-}" == *containerd.sock* ]] || [[ -z "${DOCKER_HOST:-}" ]]; then
  if [[ -S /var/run/docker.sock ]]; then
    export DOCKER_HOST="unix:///var/run/docker.sock"
    echo "[DBG] DOCKER_HOST=${DOCKER_HOST}"
  fi
fi

if ! command -v act >/dev/null 2>&1; then
  echo "[ERR] act not on PATH" >&2
  exit 1
fi
if ! docker info >/dev/null 2>&1; then
  echo "[ERR] Docker engine not reachable (DOCKER_HOST=${DOCKER_HOST:-unset})" >&2
  exit 1
fi

ORIGIN_URL="$(git remote get-url origin 2>/dev/null || true)"
REPO_SLUG="ravichandrapatel/gha-reusable-actions-workflows"
if [[ "${ORIGIN_URL}" =~ github.com[:/]+([^/]+)/([^/.]+) ]]; then
  REPO_SLUG="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
fi

if [[ -n "${COMPONENT_PATH}" ]]; then
  bash "${ROOT}/act-platform/sync-workflows-for-act.sh" "${COMPONENT_PATH}"
fi

if [[ -n "${APP_DIR}" ]]; then
  APP_DIR="$(cd "${APP_DIR}" && pwd)"
fi
if [[ -n "${MAP_DIR}" ]]; then
  MAP_DIR="$(cd "${MAP_DIR}" && pwd)"
else
  MAP_DIR="${ROOT}"
fi

if [[ -z "${WORKFLOW_FILE}" ]]; then
  if [[ -n "${APP_DIR}" && -f "${APP_DIR}/.github/workflows/ci.yml" ]]; then
    WORKFLOW_FILE=".github/workflows/ci.yml"
  else
    WORKFLOW_FILE=".act/callers/ng-ui-build-pipeline.yml"
  fi
fi
if [[ ! -f "${WORKFLOW_FILE}" && -n "${APP_DIR}" && -f "${APP_DIR}/${WORKFLOW_FILE}" ]]; then
  :
elif [[ ! -f "${WORKFLOW_FILE}" && -f "${ROOT}/${WORKFLOW_FILE}" ]]; then
  :
elif [[ ! -f "${WORKFLOW_FILE}" ]]; then
  echo "[ERR] workflow file not found: ${WORKFLOW_FILE}" >&2
  exit 1
fi

collect_refs() {
  local search_roots=("${ROOT}/.act/callers" "${ROOT}/.github/workflows" "${ROOT}/actions" "${ROOT}/workflows")
  if [[ -n "${APP_DIR}" ]]; then
    search_roots+=("${APP_DIR}")
  fi
  if [[ "${MAP_DIR}" != "${ROOT}" ]]; then
    search_roots+=("${MAP_DIR}")
  fi
  local f
  while IFS= read -r -d '' f; do
    grep -Eho "uses:[[:space:]]*${REPO_SLUG}[^[:space:]]+" "${f}" 2>/dev/null || true
  done < <(find "${search_roots[@]}" -type f \( -name '*.yml' -o -name '*.yaml' \) -print0 2>/dev/null)
}

mapfile -t USES_LINES < <(collect_refs | sed 's/uses:[[:space:]]*//' | sort -u)

LOCAL_REPO_FLAGS=()
declare -A SEEN_REF=()

for uses in "${USES_LINES[@]:-}"; do
  [[ -z "${uses}" ]] && continue
  if [[ "${uses}" != *"@"* ]]; then
    continue
  fi
  ref="${uses##*@}"
  if [[ -n "${SEEN_REF[${ref}]:-}" ]]; then
    continue
  fi
  SEEN_REF["${ref}"]=1
  LOCAL_REPO_FLAGS+=(--local-repository "${REPO_SLUG}@${ref}=${MAP_DIR}")
  echo "[MAP] ${REPO_SLUG}@${ref} -> ${MAP_DIR}"

  if [[ "${ENSURE_TAGS}" -eq 1 && "${ref}" == */v* ]]; then
    if git -C "${ROOT}" rev-parse "refs/tags/${ref}" >/dev/null 2>&1; then
      echo "[TAG] exists ${ref}"
    else
      git -C "${ROOT}" tag "${ref}" HEAD
      echo "[TAG] created local ${ref} -> HEAD (not pushed)"
    fi
  fi
done

if [[ -n "${COMPONENT_PATH}" ]]; then
  cname="$(basename "${COMPONENT_PATH}")"
  for t in "${cname}/v1" "${cname}/v1.0.0"; do
    if [[ -z "${SEEN_REF[${t}]:-}" ]]; then
      LOCAL_REPO_FLAGS+=(--local-repository "${REPO_SLUG}@${t}=${MAP_DIR}")
      SEEN_REF["${t}"]=1
      echo "[MAP] ${REPO_SLUG}@${t} -> ${MAP_DIR}"
    fi
    if [[ "${ENSURE_TAGS}" -eq 1 ]] && ! git -C "${ROOT}" rev-parse "refs/tags/${t}" >/dev/null 2>&1; then
      git -C "${ROOT}" tag "${t}" HEAD
      echo "[TAG] created local ${t} -> HEAD (not pushed)"
    fi
  done
fi

PLATFORM_FLAGS=()
if ! docker image inspect gha-act-ubuntu:dev >/dev/null 2>&1; then
  echo "[DBG] gha-act-ubuntu:dev missing; using catthehacker/ubuntu:act-latest"
  PLATFORM_FLAGS+=(-P "ubuntu-latest=catthehacker/ubuntu:act-latest")
fi

DIR_FLAGS=()
if [[ -n "${APP_DIR}" ]]; then
  DIR_FLAGS+=(-C "${APP_DIR}")
  echo "[DBG] act workdir ${APP_DIR}"
fi

EVENT_FLAGS=()
if [[ -n "${APP_DIR}" && -f "${APP_DIR}/.act/events/${EVENT}.json" ]]; then
  EVENT_FLAGS+=(-e "${APP_DIR}/.act/events/${EVENT}.json")
elif [[ -f "${ROOT}/.act/events/${EVENT}.json" ]]; then
  EVENT_FLAGS+=(-e "${ROOT}/.act/events/${EVENT}.json")
fi

JOB_FLAGS=()
if [[ -n "${JOB}" ]]; then
  JOB_FLAGS+=(-j "${JOB}")
fi

ARTIFACT_FLAGS=(--artifact-server-path "${ROOT}/temp/act-artifacts")
mkdir -p "${ROOT}/temp/act-artifacts"

CMD=(act "${EVENT}" "${DIR_FLAGS[@]}" -W "${WORKFLOW_FILE}" "${EVENT_FLAGS[@]}" "${PLATFORM_FLAGS[@]}" "${LOCAL_REPO_FLAGS[@]}" "${ARTIFACT_FLAGS[@]}" "${JOB_FLAGS[@]}")
if [[ "${LIST}" -eq 1 ]]; then
  CMD=(act --list "${DIR_FLAGS[@]}" -W "${WORKFLOW_FILE}" "${PLATFORM_FLAGS[@]}" "${LOCAL_REPO_FLAGS[@]}" "${ARTIFACT_FLAGS[@]}")
elif [[ "${DRYRUN}" -eq 1 ]]; then
  CMD+=(--dryrun)
fi
CMD+=("${ACT_ARGS[@]}")

echo "[RUN] ${CMD[*]}"
exec "${CMD[@]}"
