#!/usr/bin/env bash
# FILE_NAME: owasp-nvd-cache-sync.sh
# DESCRIPTION: Download OWASP Dependency-Check NVD data via NVD API key; archive for artifact/Nexus publish.
# VERSION: 1.0.0
# EXIT_CODES/SIGNALS: 0 success, 1 failure.
# AUTHORS: DevOps Team
set -euo pipefail

DC_CURRENT_URL="${DC_CURRENT_URL:-https://dependency-check.github.io/DependencyCheck/current.txt}"
DC_VERSION_FILE="${DC_VERSION_FILE:-actions/security/owasp-dependency-check/container/dc-version.env}"
WORK_ROOT="${WORK_ROOT:-${RUNNER_TEMP:-/tmp}/owasp-nvd-cache}"
OUTPUT_DIR="${OUTPUT_DIR:-${GITHUB_WORKSPACE:-.}/owasp-nvd-cache-out}"
STAMP="${STAMP:-$(date -u +%Y%m%dT%H%M%SZ)}"

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: required command not found: $1" >&2
    exit 1
  }
}

resolve_dc_version() {
  if [[ -f "${DC_VERSION_FILE}" ]]; then
    grep -E '^DC_VERSION=' "${DC_VERSION_FILE}" | cut -d= -f2- | tr -d '[:space:]'
    return 0
  fi
  curl -fsSL "${DC_CURRENT_URL}" | tr -d '[:space:]'
}

download_dependency_check() {
  local version="$1"
  local install_dir="${WORK_ROOT}/dependency-check"
  local zip_path="${WORK_ROOT}/dependency-check.zip"

  mkdir -p "${WORK_ROOT}"
  curl -fsSL \
    "https://github.com/dependency-check/DependencyCheck/releases/download/v${version}/dependency-check-${version}-release.zip" \
    -o "${zip_path}"
  rm -rf "${install_dir}"
  unzip -q "${zip_path}" -d "${WORK_ROOT}"
  mv "${WORK_ROOT}/dependency-check" "${install_dir}"
  rm -f "${zip_path}"
  printf '%s\n' "${install_dir}"
}

download_nvd_data() {
  local dc_home="$1"
  local data_dir="${WORK_ROOT}/data"

  rm -rf "${data_dir}"
  mkdir -p "${data_dir}"

  local -a update_args=(
    --data "${data_dir}"
    --updateonly
    --nvdApiKey "${NVD_API_KEY}"
  )

  echo "Downloading NVD database via NVD API into ${data_dir}..."
  "${dc_home}/bin/dependency-check.sh" "${update_args[@]}"
  printf '%s\n' "${data_dir}"
}

create_archive() {
  local data_dir="$1"
  local dc_version="$2"
  local archive_name="owasp-nvd-cache-${STAMP}.tar.gz"
  local archive_path="${OUTPUT_DIR}/${archive_name}"
  local latest_path="${OUTPUT_DIR}/owasp-nvd-cache-latest.tar.gz"
  local manifest_path="${OUTPUT_DIR}/manifest.json"

  mkdir -p "${OUTPUT_DIR}"
  tar -C "${data_dir}" -czf "${archive_path}" .
  cp -f "${archive_path}" "${latest_path}"

  cat > "${manifest_path}" <<EOF
{
  "generated_at": "${STAMP}",
  "dependency_check_version": "${dc_version}",
  "source": "nvd-api",
  "archive": "${archive_name}",
  "latest": "owasp-nvd-cache-latest.tar.gz"
}
EOF

  echo "Archive: ${archive_path}"
  echo "Latest copy: ${latest_path}"
  echo "Manifest: ${manifest_path}"
}

publish_nexus() {
  local archive_path="$1"
  local latest_path="$2"
  local manifest_path="$3"
  local archive_name
  archive_name="$(basename "${archive_path}")"

  if [[ -z "${NEXUS_NVD_CACHE_URL:-}" ]]; then
    echo "NEXUS_NVD_CACHE_URL is unset; skipping Nexus upload."
    return 0
  fi
  if [[ -z "${NEXUS_USERNAME:-}" || -z "${NEXUS_PASSWORD:-}" ]]; then
    echo "ERROR: NEXUS_NVD_CACHE_URL is set but NEXUS_USERNAME / NEXUS_PASSWORD are missing" >&2
    exit 1
  fi

  local base="${NEXUS_NVD_CACHE_URL%/}"
  echo "Uploading NVD cache to Nexus prefix ${base}..."

  curl -fsS -u "${NEXUS_USERNAME}:${NEXUS_PASSWORD}" \
    --upload-file "${archive_path}" \
    "${base}/${archive_name}"

  curl -fsS -u "${NEXUS_USERNAME}:${NEXUS_PASSWORD}" \
    --upload-file "${latest_path}" \
    "${base}/owasp-nvd-cache-latest.tar.gz"

  curl -fsS -u "${NEXUS_USERNAME}:${NEXUS_PASSWORD}" \
    --upload-file "${manifest_path}" \
    "${base}/manifest.json"

  echo "Nexus upload complete."
}

main() {
  require_cmd curl
  require_cmd unzip
  require_cmd tar
  require_cmd java

  if [[ -z "${NVD_API_KEY:-}" ]]; then
    echo "ERROR: NVD_API_KEY is required" >&2
    exit 1
  fi

  local dc_version
  dc_version="$(resolve_dc_version)"
  if [[ -z "${dc_version}" ]]; then
    echo "ERROR: could not resolve Dependency-Check version" >&2
    exit 1
  fi
  echo "Dependency-Check version: ${dc_version}"

  local dc_home data_dir
  dc_home="$(download_dependency_check "${dc_version}")"
  data_dir="$(download_nvd_data "${dc_home}")"
  create_archive "${data_dir}" "${dc_version}"

  if [[ "${PUBLISH_NEXUS}" == "true" || "${PUBLISH_NEXUS}" == "True" ]]; then
    publish_nexus \
      "${OUTPUT_DIR}/owasp-nvd-cache-${STAMP}.tar.gz" \
      "${OUTPUT_DIR}/owasp-nvd-cache-latest.tar.gz" \
      "${OUTPUT_DIR}/manifest.json"
  fi
}

main "$@"
