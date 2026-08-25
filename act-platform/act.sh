#!/usr/bin/env bash
# =============================================================================
# FILE_NAME: act.sh
# DESCRIPTION: One-command local act — auto-sync workflows/, map tags, run act.
# VERSION: 1.0.0
# EXIT_CODES/SIGNALS: 0 ok, 1 fail, 2 usage
# AUTHORS: Platform Team
# =============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${ROOT}"

# shellcheck disable=SC1091
source "${ROOT}/act-platform/act-lib.sh"

TAGGED_MODE=0
COMPONENT_PATH=""
WORKFLOW_FILE=""
EVENT=""
JOB=""
LIST=0
DRYRUN=0
NO_SYNC=0
NO_TAGS=0
APP_DIR=""
MAP_DIR=""
ACT_ARGS=()

usage() {
  cat <<'EOF'
Usage: ./act-platform/act.sh [options] [-- extra act flags]

Local act with less ceremony:
  - auto-syncs workflows/*/* → .github/workflows/{name}.yml (when stale)
  - accepts source paths: -W workflows/{cat}/{name}
  - maps house @{safe_name}/v* refs to this clone
  - sets DOCKER_HOST on WSL when needed

Options:
  --tagged           Legacy run-tagged-act compatibility mode
  --component PATH   Sync one component; implies --tagged conveniences
  -W, --workflow F   Workflow file or workflows/{cat}/{name} source path
  -e, --event NAME   act event (default: workflow_dispatch when --tagged)
  -j, --job ID       Run one job
  --list             act --list
  --dryrun           act --dryrun
  --no-sync          Skip workflows/ → .github/workflows/ sync
  --no-tags          Do not create missing local {safe_name}/v* tags
  --app-dir DIR      act -C DIR
  --map-dir DIR      --local-repository target (default: this clone)
  -h, --help         Show help

Examples:
  ./act-platform/act.sh --list
  ./act-platform/act.sh -W workflows/programming/ng-ui-build-pipeline --list
  ./act-platform/act.sh -W workflows/programming/ng-ui-build-pipeline -e workflow_dispatch
  ./act-platform/act.sh -W .act/callers/retry-smoke.yml
  ./act-platform/act.sh --component workflows/programming/ng-ui-build-pipeline --dryrun
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    --tagged) TAGGED_MODE=1; shift ;;
    --component) COMPONENT_PATH="${2:?}"; TAGGED_MODE=1; shift 2 ;;
    -W|--workflow) WORKFLOW_FILE="${2:?}"; shift 2 ;;
    -e|--event) EVENT="${2:?}"; shift 2 ;;
    -j|--job) JOB="${2:?}"; shift 2 ;;
    --list) LIST=1; shift ;;
    --dryrun) DRYRUN=1; shift ;;
    --no-sync) NO_SYNC=1; shift ;;
    --no-tags) NO_TAGS=1; shift ;;
    --app-dir) APP_DIR="${2:?}"; shift 2 ;;
    --map-dir) MAP_DIR="${2:?}"; shift 2 ;;
    --) shift; ACT_ARGS+=("$@"); break ;;
    -*) ACT_ARGS+=("$1"); shift ;;
    *) ACT_ARGS+=("$1"); shift ;;
  esac
done

act_lib_ensure_docker_host

if ! command -v act >/dev/null 2>&1; then
  echo "[ERR] act not on PATH — install: https://nektos.github.io/act/" >&2
  exit 1
fi
if ! docker info >/dev/null 2>&1; then
  echo "[ERR] Docker engine not reachable (DOCKER_HOST=${DOCKER_HOST:-unset})" >&2
  exit 1
fi

if [[ "${NO_SYNC}" -eq 0 ]]; then
  if [[ -n "${COMPONENT_PATH}" ]]; then
    act_lib_sync_if_stale "${ROOT}" "${COMPONENT_PATH}"
  elif [[ -z "${WORKFLOW_FILE}" && "${LIST}" -eq 1 ]]; then
    act_lib_sync_if_stale "${ROOT}"
  elif [[ -n "${WORKFLOW_FILE}" ]]; then
    :
  else
    act_lib_sync_if_stale "${ROOT}"
  fi
fi

if [[ -n "${COMPONENT_PATH}" && -z "${WORKFLOW_FILE}" ]]; then
  WORKFLOW_FILE=".github/workflows/$(basename "${COMPONENT_PATH}").yml"
fi

if [[ -n "${WORKFLOW_FILE}" && "${NO_SYNC}" -eq 0 ]]; then
  WORKFLOW_FILE="$(act_lib_resolve_workflow_path "${ROOT}" "${WORKFLOW_FILE}")"
elif [[ -n "${WORKFLOW_FILE}" ]]; then
  if [[ "${WORKFLOW_FILE}" != /* ]]; then
    WORKFLOW_FILE="${ROOT}/${WORKFLOW_FILE}"
  fi
  if [[ ! -f "${WORKFLOW_FILE}" ]]; then
    echo "[ERR] workflow file not found: ${WORKFLOW_FILE}" >&2
    exit 1
  fi
fi

if [[ -n "${APP_DIR}" ]]; then
  APP_DIR="$(cd "${APP_DIR}" && pwd)"
fi
if [[ -n "${MAP_DIR}" ]]; then
  MAP_DIR="$(cd "${MAP_DIR}" && pwd)"
else
  MAP_DIR="${ROOT}"
fi

if [[ -z "${WORKFLOW_FILE}" && "${LIST}" -eq 0 ]]; then
  if [[ -n "${APP_DIR}" && -f "${APP_DIR}/.github/workflows/ci.yml" ]]; then
    WORKFLOW_FILE="${APP_DIR}/.github/workflows/ci.yml"
  elif [[ "${TAGGED_MODE}" -eq 1 && -f "${ROOT}/.act/callers/ng-ui-build-pipeline.yml" ]]; then
    WORKFLOW_FILE="${ROOT}/.act/callers/ng-ui-build-pipeline.yml"
  fi
fi

if [[ "${TAGGED_MODE}" -eq 1 && -z "${EVENT}" ]]; then
  EVENT="workflow_dispatch"
fi
if [[ "${LIST}" -eq 0 && -z "${EVENT}" && -n "${WORKFLOW_FILE}" ]]; then
  EVENT="workflow_dispatch"
fi

ENSURE_TAGS=1
if [[ "${NO_TAGS}" -eq 1 ]]; then
  ENSURE_TAGS=0
fi

LOCAL_REPO_FLAGS=()
if [[ -n "${WORKFLOW_FILE}" || "${TAGGED_MODE}" -eq 1 ]]; then
  SEARCH_ROOTS=("${ROOT}/.act/callers" "${ROOT}/.github/workflows" "${ROOT}/actions" "${ROOT}/workflows")
  if [[ -n "${WORKFLOW_FILE}" ]]; then
    SEARCH_ROOTS+=("$(dirname "${WORKFLOW_FILE}")")
  fi
  if [[ -n "${APP_DIR}" ]]; then
    SEARCH_ROOTS+=("${APP_DIR}")
  fi
  if [[ "${MAP_DIR}" != "${ROOT}" ]]; then
    SEARCH_ROOTS+=("${MAP_DIR}")
  fi
  mapfile -t LOCAL_REPO_FLAGS < <(act_lib_local_repo_flags "${ROOT}" "${MAP_DIR}" "${ENSURE_TAGS}" "${SEARCH_ROOTS[@]}")
  if [[ -n "${COMPONENT_PATH}" ]]; then
    mapfile -t _COMP_FLAGS < <(act_lib_ensure_component_tags "${ROOT}" "${COMPONENT_PATH}" "${MAP_DIR}" "${ENSURE_TAGS}")
    LOCAL_REPO_FLAGS+=("${_COMP_FLAGS[@]}")
  fi
fi

mapfile -t PLATFORM_FLAGS < <(act_lib_platform_flags)

DIR_FLAGS=()
if [[ -n "${APP_DIR}" ]]; then
  DIR_FLAGS+=(-C "${APP_DIR}")
  echo "[DBG] act workdir ${APP_DIR}"
fi

EVENT_FLAGS=()
if [[ -n "${EVENT}" ]]; then
  if [[ -n "${APP_DIR}" && -f "${APP_DIR}/.act/events/${EVENT}.json" ]]; then
    EVENT_FLAGS+=(-e "${APP_DIR}/.act/events/${EVENT}.json")
  elif [[ -f "${ROOT}/.act/events/${EVENT}.json" ]]; then
    EVENT_FLAGS+=(-e "${ROOT}/.act/events/${EVENT}.json")
  fi
fi

JOB_FLAGS=()
if [[ -n "${JOB}" ]]; then
  JOB_FLAGS+=(-j "${JOB}")
fi

ARTIFACT_FLAGS=(--artifact-server-path "${ROOT}/temp/act-artifacts")
mkdir -p "${ROOT}/temp/act-artifacts"

CMD=(act)
if [[ "${LIST}" -eq 1 ]]; then
  CMD+=(--list)
elif [[ -n "${EVENT}" ]]; then
  CMD+=("${EVENT}")
fi

CMD+=("${DIR_FLAGS[@]}")
if [[ -n "${WORKFLOW_FILE}" ]]; then
  CMD+=(-W "${WORKFLOW_FILE}")
fi
CMD+=("${EVENT_FLAGS[@]}" "${PLATFORM_FLAGS[@]}" "${LOCAL_REPO_FLAGS[@]}" "${ARTIFACT_FLAGS[@]}" "${JOB_FLAGS[@]}")
if [[ "${DRYRUN}" -eq 1 ]]; then
  CMD+=(--dryrun)
fi
CMD+=("${ACT_ARGS[@]}")

echo "[RUN] ${CMD[*]}"
exec "${CMD[@]}"
