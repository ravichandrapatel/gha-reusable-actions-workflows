#!/usr/bin/env bash
# =============================================================================
# FILE_NAME: spvs_common_lib.sh
# DESCRIPTION: Shared SPVS shell helpers (logging, CLI checks, pinned tool bootstrap).
# VERSION: 1.0.0
# EXIT_CODES/SIGNALS: Sourced only; functions exit with caller-provided codes.
# AUTHORS: DevOps Team
# =============================================================================

SPVS_ACTIONLINT_VERSION="${SPVS_ACTIONLINT_VERSION:-1.7.7}"
SPVS_ACTIONLINT_SHA256_linux_amd64="${SPVS_ACTIONLINT_SHA256_linux_amd64:-023070a287cd8cccd71515fedc843f1985bf96c436b7effaecce67290e7e0757}"

# shellcheck disable=SC2329
spvs_require_command() {
  # INTENT: Fail when a required CLI is missing.
  # INPUT: command name; optional exit code (default 1).
  # OUTPUT: none.
  # SIDE_EFFECTS: exits with provided code when command is not on PATH.
  local cmd="$1"
  local exit_code="${2:-1}"
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    printf '[SPVS-COMMON] [DBG-920] Required command not found: %s\n' "${cmd}" >&2
    exit "${exit_code}"
  fi
}

# shellcheck disable=SC2329
spvs_detect_platform() {
  # INTENT: Map uname -m to release artifact architecture suffix.
  # INPUT: none.
  # OUTPUT: linux_amd64 or linux_arm64 printed to stdout.
  # SIDE_EFFECTS: none.
  local arch
  arch="$(uname -m)"
  case "${arch}" in
    x86_64 | amd64)
      printf '%s' "linux_amd64"
      ;;
    aarch64 | arm64)
      printf '%s' "linux_arm64"
      ;;
    *)
      printf '[SPVS-COMMON] [DBG-910] Unsupported CPU architecture: %s\n' "${arch}" >&2
      return 1
      ;;
  esac
}

# shellcheck disable=SC2329
spvs_ensure_actionlint() {
  # INTENT: Use actionlint from PATH or install a pinned binary under .cache/actionlint.
  # INPUT: repo root path; optional log callback name (function that accepts one message arg).
  # OUTPUT: none.
  # SIDE_EFFECTS: may download actionlint; prepends cache dir to PATH.
  local repo_root="$1"
  local log_fn="${2:-}"
  local cache_dir="${repo_root}/.cache/actionlint"
  local platform archive url bin expected_sha

  if command -v actionlint >/dev/null 2>&1; then
    return 0
  fi

  platform="$(spvs_detect_platform)" || exit 2
  archive="actionlint_${SPVS_ACTIONLINT_VERSION}_${platform}.tar.gz"
  url="https://github.com/rhysd/actionlint/releases/download/v${SPVS_ACTIONLINT_VERSION}/${archive}"
  bin="${cache_dir}/actionlint"

  if [[ -x "${bin}" ]]; then
    export PATH="${cache_dir}:${PATH}"
    return 0
  fi

  spvs_require_command curl 2
  spvs_require_command tar 2
  spvs_require_command sha256sum 2

  if [[ -n "${log_fn}" ]] && declare -F "${log_fn}" >/dev/null; then
    "${log_fn}" "[DBG-019] Installing actionlint ${SPVS_ACTIONLINT_VERSION} to ${cache_dir}"
  fi

  mkdir -p "${cache_dir}"
  curl -fsSL -o "${cache_dir}/${archive}" "${url}"
  if [[ "${platform}" == "linux_amd64" ]]; then
    expected_sha="${SPVS_ACTIONLINT_SHA256_linux_amd64}"
    echo "${expected_sha}  ${cache_dir}/${archive}" | sha256sum -c -
  fi
  tar xzf "${cache_dir}/${archive}" -C "${cache_dir}" actionlint
  rm -f "${cache_dir}/${archive}"
  chmod +x "${bin}"
  export PATH="${cache_dir}:${PATH}"
}

# shellcheck disable=SC2329,SC2034
spvs_add_glob_to_seen() {
  # INTENT: Add absolute paths for *.<suffix> files in a directory to an associative array.
  # INPUT: directory; suffix without dot; name of associative array variable.
  # OUTPUT: none.
  # SIDE_EFFECTS: mutates the target associative array.
  local dir="$1"
  local suffix="$2"
  local seen_name="$3"
  local -n seen_ref="${seen_name}"
  local file_path

  if [[ ! -d "${dir}" ]]; then
    return 0
  fi

  shopt -s nullglob
  for file_path in "${dir}"/*."${suffix}"; do
    if [[ -f "${file_path}" ]]; then
      seen_ref["${file_path}"]=1
    fi
  done
  shopt -u nullglob
}

# shellcheck disable=SC2329
spvs_sorted_keys() {
  # INTENT: Print sorted unique keys from an associative array name.
  # INPUT: associative array variable name.
  # OUTPUT: sorted keys one per line.
  # SIDE_EFFECTS: none.
  local -n keys_ref="$1"
  if [[ ${#keys_ref[@]} -gt 0 ]]; then
    printf '%s\n' "${!keys_ref[@]}" | LC_ALL=C sort -u
  fi
}
