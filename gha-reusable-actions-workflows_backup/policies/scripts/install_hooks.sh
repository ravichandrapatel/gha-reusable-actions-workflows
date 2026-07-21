#!/usr/bin/env bash
# =============================================================================
# FILE_NAME: install_hooks.sh
# DESCRIPTION: Machine-wide installer for SPVS hook tooling (pre-commit, bandit,
#              conftest, actionlint). Optionally installs repo pre-commit hooks
#              when run inside a clone with .pre-commit-config.yaml.
# VERSION: 1.3.0
# EXIT_CODES/SIGNALS: 0 success, non-zero on install failure
# AUTHORS: DevOps Team
# =============================================================================
#
# Usage:
#   bash policies/scripts/install_hooks.sh
#
# Installs into:
#   ~/.venv/bin          — pre-commit, bandit (latest)
#   ~/.local/bin         — actionlint v1.7.12, conftest v0.56.0

set -euo pipefail

PROJECT_PREFIX="[INSTALL-HOOKS]"
LOCAL_BIN="${HOME}/.local/bin"
HOME_VENV="${HOME}/.venv"
ACTIONLINT_VERSION="1.7.12"
CONFTEST_VERSION="0.56.0"

# INTENT: Emit operational log lines with a consistent prefix.
# INPUT: Log message string.
# OUTPUT: None.
# SIDE_EFFECTS: Writes to stdout.
_log() {
    echo "${PROJECT_PREFIX} $*"
}

# INTENT: Create and activate the shared home Python virtual environment.
# INPUT: None.
# OUTPUT: None.
# SIDE_EFFECTS: Creates ${HOME_VENV}; activates it for the current shell.
setup_home_venv() {
    if ! command -v python3 &>/dev/null; then
        echo "${PROJECT_PREFIX} ERROR: python3 is required." >&2
        exit 1
    fi

    if [[ ! -d "${HOME_VENV}" ]]; then
        _log "Creating virtual environment at ${HOME_VENV}..."
        python3 -m venv "${HOME_VENV}"
    else
        _log "Using existing virtual environment at ${HOME_VENV}"
    fi

    # shellcheck source=/dev/null
    source "${HOME_VENV}/bin/activate"
    export VIRTUAL_ENV="${HOME_VENV}"
}

# INTENT: Install pre-commit and bandit into ${HOME_VENV}.
# INPUT: None.
# OUTPUT: None.
# SIDE_EFFECTS: Installs Python packages into the home venv.
install_python_tools() {
    setup_home_venv
    _log "Installing pre-commit and bandit into ${HOME_VENV}..."
    python -m pip install --upgrade pip
    pip install --upgrade pre-commit bandit
}

# INTENT: Map uname to actionlint release archive suffix.
# INPUT: None.
# OUTPUT: Echoes archive suffix (e.g. linux_amd64).
# SIDE_EFFECTS: None.
_actionlint_platform() {
    local os arch
    os="$(uname -s)"
    arch="$(uname -m)"
    case "${os}-${arch}" in
        Linux-x86_64) echo "linux_amd64" ;;
        Linux-aarch64 | Linux-arm64) echo "linux_arm64" ;;
        Darwin-x86_64) echo "darwin_amd64" ;;
        Darwin-arm64) echo "darwin_arm64" ;;
        *)
            echo "${PROJECT_PREFIX} ERROR: Unsupported platform for actionlint: ${os} ${arch}" >&2
            exit 1
            ;;
    esac
}

# INTENT: Install pinned actionlint release with SHA256 verification.
# INPUT: None.
# OUTPUT: None.
# SIDE_EFFECTS: Downloads binary; writes to ${LOCAL_BIN}/actionlint.
install_actionlint() {
    local platform archive url checksum tmpdir dest
    platform="$(_actionlint_platform)"
    archive="actionlint_${ACTIONLINT_VERSION}_${platform}.tar.gz"
    url="https://github.com/rhysd/actionlint/releases/download/v${ACTIONLINT_VERSION}/${archive}"
    dest="${LOCAL_BIN}/actionlint"

    mkdir -p "${LOCAL_BIN}"

    if command -v actionlint &>/dev/null; then
        if actionlint -version 2>&1 | grep -q "v${ACTIONLINT_VERSION}"; then
            _log "actionlint v${ACTIONLINT_VERSION} already installed"
            return 0
        fi
    fi

    tmpdir="$(mktemp -d)"
    # shellcheck disable=SC2064
    trap "rm -rf '${tmpdir}'" RETURN

    _log "Downloading actionlint v${ACTIONLINT_VERSION} (${platform})..."
    curl -fsSL -o "${tmpdir}/${archive}" "${url}"

    checksum="$(
        curl -fsSL \
            "https://github.com/rhysd/actionlint/releases/download/v${ACTIONLINT_VERSION}/actionlint_${ACTIONLINT_VERSION}_checksums.txt" \
            | awk -v file="${archive}" '$2 == file { print $1 }'
    )"
    if [[ -z "${checksum}" ]]; then
        echo "${PROJECT_PREFIX} ERROR: Could not resolve SHA256 for ${archive}" >&2
        exit 1
    fi
    echo "${checksum}  ${tmpdir}/${archive}" | sha256sum -c -

    tar xzf "${tmpdir}/${archive}" -C "${tmpdir}" actionlint
    install -m 755 "${tmpdir}/actionlint" "${dest}"
    _log "Installed actionlint v${ACTIONLINT_VERSION} to ${dest}"
}

# INTENT: Map uname to Conftest release archive suffix.
# INPUT: None.
# OUTPUT: Echoes archive suffix (e.g. Linux_x86_64).
# SIDE_EFFECTS: None.
_conftest_platform() {
    local os arch
    os="$(uname -s)"
    arch="$(uname -m)"
    case "${os}-${arch}" in
        Linux-x86_64) echo "Linux_x86_64" ;;
        Linux-aarch64 | Linux-arm64) echo "Linux_arm64" ;;
        Darwin-x86_64) echo "Darwin_x86_64" ;;
        Darwin-arm64) echo "Darwin_arm64" ;;
        *)
            echo "${PROJECT_PREFIX} ERROR: Unsupported platform for conftest: ${os} ${arch}" >&2
            exit 1
            ;;
    esac
}

# INTENT: Install pinned Conftest release to ${LOCAL_BIN}/conftest.
# INPUT: None.
# OUTPUT: None.
# SIDE_EFFECTS: Downloads binary; writes to ${LOCAL_BIN}/conftest.
install_conftest() {
    local platform archive url dest tmpdir
    platform="$(_conftest_platform)"
    archive="conftest_${CONFTEST_VERSION}_${platform}.tar.gz"
    url="https://github.com/open-policy-agent/conftest/releases/download/v${CONFTEST_VERSION}/${archive}"
    dest="${LOCAL_BIN}/conftest"

    mkdir -p "${LOCAL_BIN}"

    if command -v conftest &>/dev/null; then
        if conftest --version 2>&1 | grep -q "Conftest: ${CONFTEST_VERSION}"; then
            _log "conftest v${CONFTEST_VERSION} already installed"
            return 0
        fi
    fi

    tmpdir="$(mktemp -d)"
    # shellcheck disable=SC2064
    trap "rm -rf '${tmpdir}'" RETURN

    _log "Downloading conftest v${CONFTEST_VERSION} (${platform})..."
    curl -fsSL -o "${tmpdir}/${archive}" "${url}"
    tar xzf "${tmpdir}/${archive}" -C "${tmpdir}" conftest
    install -m 755 "${tmpdir}/conftest" "${dest}"
    _log "Installed conftest v${CONFTEST_VERSION} to ${dest}"
}

# INTENT: Ensure home venv and user-local bin are on PATH for this session.
# INPUT: None.
# OUTPUT: Echoes "1" when PATH was modified, otherwise "0".
# SIDE_EFFECTS: Exports PATH when required directories are missing.
ensure_tooling_on_path() {
    local path_updated="0"

    case ":${PATH}:" in
        *":${HOME_VENV}/bin:"*) ;;
        *)
            export PATH="${HOME_VENV}/bin:${PATH}"
            path_updated="1"
            ;;
    esac

    case ":${PATH}:" in
        *":${LOCAL_BIN}:"*) ;;
        *)
            export PATH="${LOCAL_BIN}:${PATH}"
            path_updated="1"
            ;;
    esac

    echo "${path_updated}"
}

# INTENT: Install repo pre-commit hooks when .pre-commit-config.yaml is present.
# INPUT: None.
# OUTPUT: None.
# SIDE_EFFECTS: Runs pre-commit install in the current git repo when applicable.
configure_repo_hooks() {
    local repo_root

    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        _log "Not inside a git repository — skipping repo pre-commit install."
        return 0
    fi

    repo_root="$(git rev-parse --show-toplevel)"
    cd "${repo_root}"

    if [[ -f "${repo_root}/.pre-commit-config.yaml" ]]; then
        if [[ -f "${repo_root}/policies/scripts/hooks/run_actionlint.sh" ]]; then
            chmod +x "${repo_root}/policies/scripts/hooks/run_actionlint.sh"
        fi
        if [[ -f "${repo_root}/policies/scripts/hooks/run_spvs_gha.sh" ]]; then
            chmod +x "${repo_root}/policies/scripts/hooks/run_spvs_gha.sh"
        fi
        if [[ -f "${repo_root}/policies/scripts/spvs_conftest_run.sh" ]]; then
            chmod +x "${repo_root}/policies/scripts/spvs_conftest_run.sh"
        fi
        if [[ -f "${repo_root}/policies/scripts/spvs_conftest_report.py" ]]; then
            chmod +x "${repo_root}/policies/scripts/spvs_conftest_report.py"
        fi
        _log "Installing pre-commit hooks from ${repo_root}/.pre-commit-config.yaml"
        pre-commit install
    else
        _log "No .pre-commit-config.yaml found — skipping pre-commit install."
    fi
}

# INTENT: Configure global commit-msg hook for Git.
# INPUT: None.
# OUTPUT: None.
# SIDE_EFFECTS: Configures git global core.hooksPath and installs the hook.
configure_global_commit_hook() {
    local repo_root hooks_dir hook_src
    
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        _log "Not inside a git repository — skipping global commit-hook configuration."
        return 0
    fi

    repo_root="$(git rev-parse --show-toplevel)"
    hooks_dir="${HOME}/.git-templates/hooks"
    hook_src="${repo_root}/policies/scripts/hooks/commit-msg"
    lib_src="${repo_root}/policies/scripts/commit_message_lib.sh"
    
    _log "Configuring global commit-msg hook..."
    mkdir -p "${hooks_dir}"
    
    if [[ ! -f "${hook_src}" ]]; then
        _log "WARNING: Hook source ${hook_src} not found — skipping global config."
        return 0
    fi

    if [[ ! -f "${lib_src}" ]]; then
        _log "WARNING: Library source ${lib_src} not found — skipping global config."
        return 0
    fi
    
    cp "${hook_src}" "${hooks_dir}/commit-msg"
    cp "${lib_src}" "${hooks_dir}/commit_message_lib.sh"
    chmod +x "${hooks_dir}/commit-msg"
    chmod +x "${hooks_dir}/commit_message_lib.sh"
    
    git config --global core.hooksPath "${hooks_dir}"
    _log "Global git core.hooksPath set to ${hooks_dir}"
}

# 1. Machine-wide tooling
install_python_tools
install_actionlint
install_conftest
path_updated="$(ensure_tooling_on_path)"

_log "Installed tool versions:"
pre-commit --version
bandit --version
conftest --version
actionlint -version

# 2. Global commit-msg hook configuration
configure_global_commit_hook

# 3. Optional repo pre-commit install
configure_repo_hooks

_log "Success! Hook tooling is installed."
if [[ "${path_updated}" == "1" ]]; then
    _log "Add to your shell profile:"
    _log "  export PATH=\"${HOME_VENV}/bin:${LOCAL_BIN}:\${PATH}\""
fi
