#!/usr/bin/env bash
# FILE_NAME: select-java.sh
# DESCRIPTION: Select JAVA_HOME for a requested major version on self-hosted Linux runners.
# VERSION: 1.0.0
# EXIT_CODES/SIGNALS: 0 success, 1 failure.
# AUTHORS: DevOps Team
set -euo pipefail

normalize_java_major() {
  local raw="$1"
  raw="${raw#"${raw%%[![:space:]]*}"}"
  raw="${raw%"${raw##*[![:space:]]}"}"
  if [[ "${raw}" == 1.* ]]; then
    raw="${raw#1.}"
  fi
  printf '%s\n' "${raw}"
}

java_major_on_path() {
  local java_bin="$1"
  "${java_bin}" -version 2>&1 | awk -F '[".]' '/version/ { print $2; exit }'
}

select_java_home() {
  local requested
  requested="$(normalize_java_major "${1}")"
  if [[ -z "${requested}" || ! "${requested}" =~ ^[0-9]+$ ]]; then
    echo "::error::java-version must resolve to a numeric major version (got '${1}')" >&2
    return 1
  fi

  local -a candidates=()
  if [[ -d /usr/lib/jvm ]]; then
    while IFS= read -r path; do
      candidates+=("${path}")
    done < <(find /usr/lib/jvm -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort)
  fi
  candidates+=(
    "/usr/lib/jvm/java-${requested}-openjdk"
    "/usr/lib/jvm/java-${requested}"
    "/usr/lib/jvm/temurin-${requested}-jdk"
    "/usr/lib/jvm/amazon-corretto-${requested}"
    "/opt/java/openjdk"
  )

  local candidate major
  for candidate in "${candidates[@]}"; do
    [[ -x "${candidate}/bin/java" ]] || continue
    major="$(java_major_on_path "${candidate}/bin/java" || true)"
    if [[ "${major}" == "${requested}" ]]; then
      export JAVA_HOME="${candidate}"
      export PATH="${JAVA_HOME}/bin:${PATH}"
      echo "Selected JAVA_HOME=${JAVA_HOME} (requested Java ${requested})"
      java -version
      return 0
    fi
  done

  echo "::error::No Java ${requested} installation found for self-hosted runner." >&2
  echo "::error::Install JDK ${requested} on the runner or set JAVA_HOME before the Maven step." >&2
  return 1
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  : "${JAVA_VERSION:?JAVA_VERSION is required}"
  select_java_home "${JAVA_VERSION}"
fi
