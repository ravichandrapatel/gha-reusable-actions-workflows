#!/usr/bin/env bash
# FILE_NAME: maven.sh
# DESCRIPTION: Run Maven with caller-supplied goals and options.
# VERSION: 1.1.0
# EXIT_CODES/SIGNALS: 0 success, 1 failure.
# AUTHORS: DevOps Team
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

: "${MAVEN_EXECUTABLE:=mvn}"
: "${MAVEN_ARGS:?MAVEN_ARGS is required}"
: "${WORKING_DIRECTORY:=${GITHUB_WORKSPACE:-.}}"

if ! command -v "${MAVEN_EXECUTABLE}" >/dev/null 2>&1; then
  echo "::error::Maven executable not found on PATH: ${MAVEN_EXECUTABLE}" >&2
  exit 1
fi

if [[ ! -d "${WORKING_DIRECTORY}" ]]; then
  echo "::error::working directory does not exist: ${WORKING_DIRECTORY}" >&2
  exit 1
fi

cd "${WORKING_DIRECTORY}"

if [[ "${JAVA_SETUP:-auto}" != "skip" && -n "${JAVA_VERSION:-}" ]]; then
  # shellcheck source=select-java.sh
  source "${SCRIPT_DIR}/select-java.sh"
  select_java_home "${JAVA_VERSION}"
elif [[ "${JAVA_SETUP:-auto}" == "require" && -z "${JAVA_HOME:-}" ]]; then
  echo "::error::JAVA_HOME is not set and java-setup=require" >&2
  exit 1
fi

if [[ -n "${SETTINGS_FILE:-}" ]]; then
  if [[ ! -f "${SETTINGS_FILE}" ]]; then
    echo "::error::Maven settings file not found: ${SETTINGS_FILE}" >&2
    exit 1
  fi
  SETTINGS_FLAG=(-s "${SETTINGS_FILE}")
else
  SETTINGS_FLAG=()
fi

if [[ -n "${MAVEN_OPTS:-}" ]]; then
  export MAVEN_OPTS
fi

echo "Running Maven in ${WORKING_DIRECTORY}"
echo "+ ${MAVEN_EXECUTABLE} ${SETTINGS_FLAG[*]:-} ${MAVEN_ARGS}"

set +e
# shellcheck disable=SC2086
"${MAVEN_EXECUTABLE}" "${SETTINGS_FLAG[@]}" ${MAVEN_ARGS}
exit_code=$?
set -e

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  echo "exit_code=${exit_code}" >> "${GITHUB_OUTPUT}"
fi

if [[ "${exit_code}" -ne 0 ]]; then
  echo "::error::Maven exited with code ${exit_code}" >&2
  exit "${exit_code}"
fi

if [[ -f pom.xml ]] && command -v "${MAVEN_EXECUTABLE}" >/dev/null 2>&1; then
  project_version="$(
    # shellcheck disable=SC2086
    "${MAVEN_EXECUTABLE}" "${SETTINGS_FLAG[@]}" -q \
      -DforceStdout help:evaluate -Dexpression=project.version 2>/dev/null || true
  )"
  if [[ -n "${project_version}" && -n "${GITHUB_OUTPUT:-}" ]]; then
    echo "project_version=${project_version}" >> "${GITHUB_OUTPUT}"
  fi
fi
