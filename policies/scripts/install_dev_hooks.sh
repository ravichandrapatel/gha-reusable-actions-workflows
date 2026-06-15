#!/usr/bin/env bash
# =============================================================================
# FILE_NAME: install_dev_hooks.sh
# DESCRIPTION: Install SPVS dev tooling (venv or pipx), system CLIs, and pre-commit hooks.
# VERSION: 1.0.0
# EXIT_CODES/SIGNALS: 0 success, 1 install failure, 2 usage error
# AUTHORS: DevOps Team
# =============================================================================
set -euo pipefail

PROJECT_PREFIX="[SPVS-DEV-INSTALL]"

ACTIONLINT_VERSION="1.7.7"
ACTIONLINT_SHA256="023070a287cd8cccd71515fedc843f1985bf96c436b7effaecce67290e7e0757"
YQ_VERSION="4.44.5"
YQ_SHA256_linux_amd64="cc9ee4d476717d2b90e4f20cf2bf31f9d6bfba830227960f6e0401db74270311"
YQ_SHA256_linux_arm64="7b9c0272212f468f7751996e4e66fec56f9e8b2d5140ffcfc5beaf1af9a7097e"

REPO_ROOT=""
INSTALL_MODE="venv"
SKIP_SYSTEM="false"
SKIP_HOOKS="false"
VENV_DIR=""
PIPX_BIN="${HOME}/.local/bin"

# shellcheck disable=SC2329
_log() {
  # INTENT: Central logger with greppable debug codes.
  # INPUT: message string.
  # OUTPUT: None.
  # SIDE_EFFECTS: writes to stdout.
  printf '%s %s\n' "${PROJECT_PREFIX}" "$*"
}

# shellcheck disable=SC2329
usage() {
  # INTENT: Print CLI usage.
  # INPUT: none.
  # OUTPUT: usage text on stdout.
  # SIDE_EFFECTS: none.
  cat <<'EOF'
Usage: install_dev_hooks.sh [options]

Install Python dev tools, optional system CLIs, write .env, and register pre-commit hooks.

Options:
  --mode venv|pipx   Python install strategy (default: venv)
  --skip-system      Skip shellcheck/actionlint/yq installation
  --skip-hooks       Skip pre-commit install (tools only)
  -h, --help         Show this help

After install:
  source .env
  pre-commit run --all-files
EOF
}

# shellcheck disable=SC2329
parse_args() {
  # INTENT: Parse CLI arguments into globals.
  # INPUT: script arguments.
  # OUTPUT: None.
  # SIDE_EFFECTS: sets INSTALL_MODE, SKIP_* flags.
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --mode)
        INSTALL_MODE="${2:-}"
        shift 2
        ;;
      --skip-system)
        SKIP_SYSTEM="true"
        shift
        ;;
      --skip-hooks)
        SKIP_HOOKS="true"
        shift
        ;;
      -h | --help)
        usage
        exit 0
        ;;
      *)
        _log "[DBG-910] Unknown argument: $1"
        usage >&2
        exit 2
        ;;
    esac
  done

  case "${INSTALL_MODE}" in
    venv | pipx) ;;
    *)
      _log "[DBG-910] Invalid --mode: ${INSTALL_MODE} (use venv or pipx)"
      exit 2
      ;;
  esac
}

# shellcheck disable=SC2329
require_command() {
  # INTENT: Fail when a required CLI is missing.
  # INPUT: command name.
  # OUTPUT: None.
  # SIDE_EFFECTS: exits 1 when command is not on PATH.
  local cmd="$1"
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    _log "[DBG-920] Required command not found: ${cmd}"
    exit 1
  fi
}

# shellcheck disable=SC2329
detect_platform() {
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
      _log "[DBG-910] Unsupported CPU architecture: ${arch}"
      exit 1
      ;;
  esac
}

# shellcheck disable=SC2329
install_shellcheck() {
  # INTENT: Install shellcheck via apt or Homebrew when missing.
  # INPUT: none.
  # OUTPUT: None.
  # SIDE_EFFECTS: may invoke package manager.
  if command -v shellcheck >/dev/null 2>&1; then
    _log "[DBG-001] shellcheck already installed: $(command -v shellcheck)"
    return 0
  fi

  _log "[DBG-002] Installing shellcheck"
  if command -v apt-get >/dev/null 2>&1; then
    require_command sudo
    sudo apt-get update -qq
    sudo apt-get install -y shellcheck
  elif command -v brew >/dev/null 2>&1; then
    brew install shellcheck
  else
    _log "[DBG-910] Cannot install shellcheck automatically; install via apt or brew"
    exit 1
  fi
}

# shellcheck disable=SC2329
install_actionlint() {
  # INTENT: Install pinned actionlint under .cache/actionlint when missing.
  # INPUT: none.
  # OUTPUT: None.
  # SIDE_EFFECTS: downloads binary into repo .cache/.
  local cache_dir="${REPO_ROOT}/.cache/actionlint"
  local platform archive url bin

  if command -v actionlint >/dev/null 2>&1; then
    _log "[DBG-003] actionlint already installed: $(command -v actionlint)"
    return 0
  fi

  platform="$(detect_platform)"
  archive="actionlint_${ACTIONLINT_VERSION}_${platform}.tar.gz"
  url="https://github.com/rhysd/actionlint/releases/download/v${ACTIONLINT_VERSION}/${archive}"
  bin="${cache_dir}/actionlint"

  if [[ -x "${bin}" ]]; then
    _log "[DBG-004] Using cached actionlint: ${bin}"
    return 0
  fi

  require_command curl
  require_command tar
  require_command sha256sum

  _log "[DBG-005] Installing actionlint ${ACTIONLINT_VERSION} to ${cache_dir}"
  mkdir -p "${cache_dir}"
  curl -fsSL -o "${cache_dir}/${archive}" "${url}"
  if [[ "${platform}" == "linux_amd64" ]]; then
    echo "${ACTIONLINT_SHA256}  ${cache_dir}/${archive}" | sha256sum -c -
  else
    _log "[DBG-006] Skipping SHA256 verify for ${platform} (pin verify on amd64 only)"
  fi
  tar xzf "${cache_dir}/${archive}" -C "${cache_dir}" actionlint
  rm -f "${cache_dir}/${archive}"
  chmod +x "${bin}"
}

# shellcheck disable=SC2329
_yq_pinned_sha256() {
  # INTENT: Return pinned SHA256 for a yq release archive on supported platforms.
  # INPUT: platform suffix (linux_amd64 or linux_arm64).
  # OUTPUT: sha256 hex printed to stdout (empty if unsupported).
  # SIDE_EFFECTS: none.
  local platform="$1"

  case "${platform}" in
    linux_amd64)
      printf '%s' "${YQ_SHA256_linux_amd64}"
      ;;
    linux_arm64)
      printf '%s' "${YQ_SHA256_linux_arm64}"
      ;;
    *)
      printf '%s' ""
      ;;
  esac
}

# shellcheck disable=SC2329
install_yq() {
  # INTENT: Install pinned mikefarah/yq v4 under .cache/yq when missing or wrong flavor.
  # INPUT: none.
  # OUTPUT: None.
  # SIDE_EFFECTS: downloads binary into repo .cache/.
  local cache_dir="${REPO_ROOT}/.cache/yq"
  local platform archive url bin expected_sha

  if command -v yq >/dev/null 2>&1; then
    if yq --version 2>/dev/null | grep -q "mikefarah/yq"; then
      _log "[DBG-007] yq already installed: $(yq --version 2>/dev/null | head -n1)"
      return 0
    fi
    _log "[DBG-008] Found non-mikefarah yq; installing mikefarah/yq beside it"
  fi

  platform="$(detect_platform)"
  archive="yq_${platform}.tar.gz"
  url="https://github.com/mikefarah/yq/releases/download/v${YQ_VERSION}/${archive}"
  bin="${cache_dir}/yq"

  if [[ -x "${bin}" ]]; then
    _log "[DBG-009] Using cached yq: ${bin}"
    return 0
  fi

  require_command curl
  require_command tar
  require_command sha256sum

  expected_sha="$(_yq_pinned_sha256 "${platform}")"
  if [[ -z "${expected_sha}" ]]; then
    _log "[DBG-910] No pinned SHA256 for yq on ${platform}"
    exit 1
  fi

  _log "[DBG-010] Installing yq ${YQ_VERSION} to ${cache_dir}"
  mkdir -p "${cache_dir}"
  curl -fsSL -o "${cache_dir}/${archive}" "${url}"
  echo "${expected_sha}  ${cache_dir}/${archive}" | sha256sum -c -
  tar xzf "${cache_dir}/${archive}" -C "${cache_dir}"
  rm -f "${cache_dir}/${archive}"
  if [[ -f "${cache_dir}/yq_${platform}" ]]; then
    mv "${cache_dir}/yq_${platform}" "${bin}"
  elif [[ -f "${cache_dir}/yq" ]]; then
    :
  else
    _log "[DBG-910] yq binary not found after extracting ${archive}"
    exit 1
  fi
  chmod +x "${bin}"
}

# shellcheck disable=SC2329
install_system_tools() {
  # INTENT: Install shellcheck, actionlint, and yq unless skipped.
  # INPUT: none.
  # OUTPUT: None.
  # SIDE_EFFECTS: package installs and binary downloads.
  if [[ "${SKIP_SYSTEM}" == "true" ]]; then
    _log "[DBG-011] Skipping system tool installation (--skip-system)"
    return 0
  fi

  install_shellcheck
  install_actionlint
  install_yq
}

# shellcheck disable=SC2329
install_python_venv() {
  # INTENT: Create .venv and pip-install requirements-dev.txt.
  # INPUT: none.
  # OUTPUT: None.
  # SIDE_EFFECTS: creates .venv and installs packages.
  require_command python3

  _log "[DBG-012] Creating virtualenv at ${VENV_DIR}"
  python3 -m venv "${VENV_DIR}"
  "${VENV_DIR}/bin/pip" install --upgrade pip
  "${VENV_DIR}/bin/pip" install -r "${REPO_ROOT}/requirements-dev.txt"
}

# shellcheck disable=SC2329
install_python_pipx() {
  # INTENT: Install dev Python CLIs with pipx.
  # INPUT: none.
  # OUTPUT: None.
  # SIDE_EFFECTS: pipx installs under ~/.local/pipx or PIPX_HOME.
  require_command pipx
  require_command python3

  _log "[DBG-013] Installing Python tools with pipx"
  pipx install --force "pre-commit>=3.5.0"
  pipx install --force "checkov==3.2.529"
  pipx install --force "bandit==1.8.2"

  if [[ -d "${PIPX_BIN}" ]]; then
    export PATH="${PIPX_BIN}:${PATH}"
  fi
}

# shellcheck disable=SC2329
write_env_file() {
  # INTENT: Write repo-root .env so hooks and shells share PATH.
  # INPUT: none.
  # OUTPUT: None.
  # SIDE_EFFECTS: writes ${REPO_ROOT}/.env.
  local env_file="${REPO_ROOT}/.env"
  local path_prefix=""

  if [[ "${INSTALL_MODE}" == "venv" ]]; then
    path_prefix="${VENV_DIR}/bin:"
  else
    path_prefix="${PIPX_BIN}:"
  fi

  cat > "${env_file}" <<EOF
# Generated by policies/scripts/install_dev_hooks.sh — do not edit by hand.
# Usage (from repo root): source .env
export SPVS_REPO_ROOT="${REPO_ROOT}"
export SPVS_HOOK_VERBOSE="\${SPVS_HOOK_VERBOSE:-0}"
export PATH="${path_prefix}${REPO_ROOT}/.cache/actionlint:${REPO_ROOT}/.cache/yq:\${PATH}"
EOF

  _log "[DBG-014] Wrote ${env_file}"
}

# shellcheck disable=SC2329
install_git_hooks() {
  # INTENT: Extend global core.hooksPath hooks with SPVS checks for repos that ship policies/.
  # INPUT: none.
  # OUTPUT: None.
  # SIDE_EFFECTS: writes commit-msg/pre-commit under global hooksPath; removes local override.
  local global_hooks_path=""
  local hooks_dir=""
  local commit_msg_hook=""
  local pre_commit_hook=""

  if [[ "${SKIP_HOOKS}" == "true" ]]; then
    _log "[DBG-015] Skipping git hook install (--skip-hooks)"
    return 0
  fi

  global_hooks_path="$(git config --global --get core.hooksPath 2>/dev/null || true)"
  if [[ -z "${global_hooks_path}" ]]; then
    _log "[DBG-910] Global core.hooksPath is not set; set it first, then re-run install"
    _log "[DBG-910] Example: git config --global core.hooksPath ~/.git-global-compliance/hooks"
    exit 1
  fi

  if [[ "${global_hooks_path}" != /* ]]; then
    global_hooks_path="${HOME}/${global_hooks_path#~/}"
  fi

  hooks_dir="${global_hooks_path}"
  commit_msg_hook="${hooks_dir}/commit-msg"
  pre_commit_hook="${hooks_dir}/pre-commit"

  mkdir -p "${hooks_dir}"

  # CHECKPOINT: keep global hooksPath authoritative; remove repo-local override if present.
  if git config --local --get core.hooksPath >/dev/null 2>&1; then
    git config --local --unset-all core.hooksPath
    _log "[DBG-016] Removed repo-local core.hooksPath override (global hooks restored)"
  fi

  if [[ -f "${commit_msg_hook}" ]] && ! grep -q 'SPVS-GLOBAL-HOOK' "${commit_msg_hook}" 2>/dev/null; then
    cp -a "${commit_msg_hook}" "${commit_msg_hook}.bak.$(date -u +%Y%m%dT%H%M%SZ)"
    _log "[DBG-016a] Backed up existing global commit-msg hook"
  fi

  cat > "${commit_msg_hook}" <<'EOF'
#!/usr/bin/env bash
# SPVS-GLOBAL-HOOK: managed by gha-reusable-actions-workflows install_dev_hooks.sh
set -euo pipefail

MSG_FILE="${1:?commit-msg hook requires message file argument}"

# Global compliance: drop Cursor co-author trailer when present.
sed -i '/Co-authored-by: Cursor <cursoragent@cursor.com>/d' "${MSG_FILE}"

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
VALIDATOR="${REPO_ROOT}/policies/scripts/validate_commit_message.sh"
if [[ -f "${VALIDATOR}" ]]; then
  if [[ -f "${REPO_ROOT}/.env" ]]; then
    # shellcheck disable=SC1091
    source "${REPO_ROOT}/.env"
  fi
  bash "${VALIDATOR}" "${MSG_FILE}"
fi
EOF

  cat > "${pre_commit_hook}" <<'EOF'
#!/usr/bin/env bash
# SPVS-GLOBAL-HOOK: managed by gha-reusable-actions-workflows install_dev_hooks.sh
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"
WRAPPER="${REPO_ROOT}/policies/scripts/pre_commit_spvs_wrapper.sh"
if [[ ! -f "${WRAPPER}" ]]; then
  exit 0
fi

cd "${REPO_ROOT}"
if [[ -f "${REPO_ROOT}/.env" ]]; then
  # shellcheck disable=SC1091
  source "${REPO_ROOT}/.env"
fi

mapfile -d '' -t STAGED_FILES < <(git diff --cached --name-only -z --diff-filter=ACMR)
if [[ ${#STAGED_FILES[@]} -eq 0 ]]; then
  exit 0
fi

exec bash "${WRAPPER}" "${STAGED_FILES[@]}"
EOF

  chmod +x "${commit_msg_hook}" "${pre_commit_hook}"
  _log "[DBG-017] Updated global hooks under ${hooks_dir}"
  _log "[DBG-017a] Global core.hooksPath unchanged; SPVS runs when policies/ exists in repo"
}

# shellcheck disable=SC2329
verify_tools() {
  # INTENT: Confirm required CLIs resolve after install.
  # INPUT: none.
  # OUTPUT: None.
  # SIDE_EFFECTS: exits 1 if a tool is missing.
  local tool
  local -a required=(pre-commit checkov bandit)

  if [[ "${SKIP_SYSTEM}" != "true" ]]; then
    required+=(shellcheck actionlint yq)
  fi

  # shellcheck disable=SC1091
  source "${REPO_ROOT}/.env"

  for tool in "${required[@]}"; do
    if ! command -v "${tool}" >/dev/null 2>&1; then
      _log "[DBG-910] Missing tool after install: ${tool}"
      exit 1
    fi
    _log "[DBG-017] OK ${tool} -> $(command -v "${tool}")"
  done
}

# shellcheck disable=SC2329
main() {
  # INTENT: Entrypoint for SPVS dev environment bootstrap.
  # INPUT: script arguments.
  # OUTPUT: None.
  # SIDE_EFFECTS: installs tools, writes .env, registers git hooks.
  parse_args "$@"

  REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  VENV_DIR="${REPO_ROOT}/.venv"

  _log "[DBG-000] Installing SPVS dev hooks (mode=${INSTALL_MODE})"
  cd "${REPO_ROOT}"

  install_system_tools

  if [[ "${INSTALL_MODE}" == "venv" ]]; then
    install_python_venv
  else
    install_python_pipx
  fi

  write_env_file
  install_git_hooks
  verify_tools

  _log "[DBG-018] Install complete. Run: source .env"
}

main "$@"
