#!/usr/bin/env bash
# =============================================================================
# FILE_NAME: run_terraform_hooks.sh
# DESCRIPTION: Shell-only pre-commit checks for staged Terraform files (fmt, validate, tflint).
# VERSION: 1.0.0
# EXIT_CODES/SIGNALS: 0 pass, 1 check failure, 2 missing tool
# AUTHORS: DevOps Team
# =============================================================================
set -euo pipefail

PROJECT_PREFIX="[SPVS-TERRAFORM-HOOK]"
SPVS_HOOK_VERBOSE="${SPVS_HOOK_VERBOSE:-0}"
SPVS_HOOK_SKIP_TERRAFORM="${SPVS_HOOK_SKIP_TERRAFORM:-0}"

_log() {
  [[ "${SPVS_HOOK_VERBOSE}" == "1" ]] || return 0
  printf '%s %s\n' "${PROJECT_PREFIX}" "$*" >&2
}

_log_err() {
  printf '%s %s\n' "${PROJECT_PREFIX}" "$*" >&2
}

require_command() {
  local cmd="$1"
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    _log_err "[DBG-920] Required command not found: ${cmd}"
    exit 2
  fi
}

collect_staged_tf_files() {
  local path=""
  STAGED_TF_FILES=()
  while IFS= read -r -d '' path; do
    case "${path}" in
      *.tf | *.tfvars)
        STAGED_TF_FILES+=("${path}")
        ;;
    esac
  done < <(git diff --cached --name-only -z --diff-filter=ACMR)
}

collect_module_roots() {
  local file="" dir=""
  local -A roots=()
  MODULE_ROOTS=()

  for file in "${STAGED_TF_FILES[@]}"; do
    dir="$(dirname "${file}")"
    if [[ "${dir}" == "." ]]; then
      roots["."]=1
    else
      roots["${dir}"]=1
    fi
  done

  for dir in "${!roots[@]}"; do
    MODULE_ROOTS+=("${dir}")
  done
}

run_terraform_fmt() {
  local file="" changed=0
  _log "[DBG-001] Running terraform fmt -check"
  for file in "${STAGED_TF_FILES[@]}"; do
    if ! terraform fmt -check -diff "${file}"; then
      changed=1
    fi
  done
  if [[ "${changed}" -eq 1 ]]; then
    _log_err "[DBG-901] terraform fmt check failed; run: terraform fmt"
    return 1
  fi
}

run_terraform_validate() {
  local dir="" file=""
  _log "[DBG-002] Running terraform validate per module"
  for dir in "${MODULE_ROOTS[@]}"; do
    shopt -s nullglob
    if [[ "${dir}" == "." ]]; then
      file=(./*.tf)
    else
      file=("${dir}"/*.tf)
    fi
    shopt -u nullglob
    if [[ ${#file[@]} -eq 0 ]] || [[ ! -e "${file[0]}" ]]; then
      continue
    fi
    _log "[DBG-003] terraform init/validate in ${dir}"
    (
      cd "${dir}"
      terraform init -backend=false -input=false >/dev/null
      terraform validate
    )
  done
}

run_tflint() {
  local dir=""
  if ! command -v tflint >/dev/null 2>&1; then
    _log "[DBG-904] tflint not installed; skipping"
    return 0
  fi

  _log "[DBG-004] Running tflint where .tflint.hcl exists"
  for dir in "${MODULE_ROOTS[@]}"; do
    if [[ -f "${dir}/.tflint.hcl" ]]; then
      (
        cd "${dir}"
        tflint --init >/dev/null 2>&1 || true
        tflint
      )
    fi
  done
}

main() {
  if [[ "${SPVS_HOOK_SKIP_TERRAFORM}" == "1" ]]; then
    _log "[DBG-905] Terraform hooks skipped (SPVS_HOOK_SKIP_TERRAFORM=1)"
    exit 0
  fi

  collect_staged_tf_files
  if [[ ${#STAGED_TF_FILES[@]} -eq 0 ]]; then
    _log "[DBG-000] No staged Terraform files; skipping"
    exit 0
  fi

  require_command terraform
  collect_module_roots

  run_terraform_fmt
  run_terraform_validate
  run_tflint
  _log "[DBG-006] Terraform hooks passed"
}

main "$@"
