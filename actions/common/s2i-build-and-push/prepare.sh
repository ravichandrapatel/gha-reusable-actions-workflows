#!/usr/bin/env bash
# FILE_NAME: prepare.sh
# DESCRIPTION: Stage a pre-built artifact as an S2I source directory.
# VERSION: 1.1.0
# AUTHORS: DevOps Team
set -euo pipefail

ARTIFACT=""
APP_BUILD_TYPE=""
SOURCE_DIR=""
OUTPUT="${OUTPUT:-${GITHUB_OUTPUT:-}}"
WORKSPACE="${WORKSPACE:-${GITHUB_WORKSPACE:-.}}"

usage() {
  echo "ERROR: unknown argument $1" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --artifact) ARTIFACT="$2"; shift 2 ;;
    --app-build-type) APP_BUILD_TYPE="$2"; shift 2 ;;
    --source) SOURCE_DIR="$2"; shift 2 ;;
    --output) OUTPUT="$2"; shift 2 ;;
    --workspace) WORKSPACE="$2"; shift 2 ;;
    *) usage "$1" ;;
  esac
done

if [[ -z "${ARTIFACT}" || -z "${APP_BUILD_TYPE}" ]]; then
  echo "ERROR: --artifact and --app-build-type are required" >&2
  exit 1
fi

case "${APP_BUILD_TYPE}" in
  maven|dotnet|other) ;;
  ng-ui)
    echo "ERROR: app_build_type ng-ui uses docker-build-and-push with a Dockerfile, not S2I" >&2
    exit 1
    ;;
  *)
    echo "ERROR: app_build_type must be maven, dotnet, or other" >&2
    exit 1
    ;;
esac

if [[ "${ARTIFACT}" != /* ]]; then
  ARTIFACT="${WORKSPACE%/}/${ARTIFACT}"
fi
if [[ ! -e "${ARTIFACT}" ]]; then
  echo "ERROR: artifact not found: ${ARTIFACT}" >&2
  exit 1
fi

if [[ -z "${SOURCE_DIR}" ]]; then
  SOURCE_DIR="${RUNNER_TEMP:-/tmp}/s2i-source"
fi
if [[ "${SOURCE_DIR}" != /* ]]; then
  SOURCE_DIR="${WORKSPACE%/}/${SOURCE_DIR}"
fi

rm -rf "${SOURCE_DIR}"
mkdir -p "${SOURCE_DIR}"

if [[ -d "${ARTIFACT}" ]]; then
  if [[ -z "$(ls -A "${ARTIFACT}" 2>/dev/null)" ]]; then
    echo "ERROR: artifact directory is empty: ${ARTIFACT}" >&2
    exit 1
  fi
  cp -a "${ARTIFACT}"/. "${SOURCE_DIR}/"
else
  cp -a "${ARTIFACT}" "${SOURCE_DIR}/$(basename "${ARTIFACT}")"
fi

if [[ -z "$(ls -A "${SOURCE_DIR}" 2>/dev/null)" ]]; then
  echo "ERROR: no files staged from artifact: ${ARTIFACT}" >&2
  exit 1
fi

if [[ "${APP_BUILD_TYPE}" == "maven" ]]; then
  runtime_bin="$(find "${SOURCE_DIR}" -type f \( -name '*.jar' -o -name '*.war' \) ! -name '*-sources.jar' ! -name '*-javadoc.jar' -print -quit)"
  if [[ -z "${runtime_bin}" ]]; then
    echo "ERROR: maven artifact must include a .jar or .war (not sources/javadoc)" >&2
    exit 1
  fi
fi

echo "app_build_type : ${APP_BUILD_TYPE}"
echo "artifact : ${ARTIFACT}"
echo "source : ${SOURCE_DIR}"
if [[ -n "${OUTPUT}" ]]; then
  {
    echo "app_build_type=${APP_BUILD_TYPE}"
    echo "artifact=${ARTIFACT}"
    echo "source=${SOURCE_DIR}"
  } >> "${OUTPUT}"
fi
