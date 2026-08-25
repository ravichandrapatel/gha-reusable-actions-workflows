#!/usr/bin/env bash
# =============================================================================
# FILE_NAME: act-lib.sh
# DESCRIPTION: Shared helpers for act-platform local workflow runs.
# VERSION: 1.0.0
# EXIT_CODES/SIGNALS: Sourced only.
# AUTHORS: Platform Team
# =============================================================================

act_lib_root() {
  cd "$(dirname "${BASH_SOURCE[1]:-${BASH_SOURCE[0]}}")/.." && pwd
}

act_lib_ensure_docker_host() {
  if [[ "${DOCKER_HOST:-}" == *containerd.sock* ]] || [[ -z "${DOCKER_HOST:-}" ]]; then
    if [[ -S /var/run/docker.sock ]]; then
      export DOCKER_HOST="unix:///var/run/docker.sock"
      echo "[DBG] DOCKER_HOST=${DOCKER_HOST}"
    fi
  fi
}

act_lib_repo_slug() {
  local root="$1"
  local origin_url repo_slug="ravichandrapatel/gha-reusable-actions-workflows"
  origin_url="$(git -C "${root}" remote get-url origin 2>/dev/null || true)"
  if [[ "${origin_url}" =~ github.com[:/]+([^/]+)/([^/.]+) ]]; then
    repo_slug="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
  fi
  printf '%s' "${repo_slug}"
}

# Sync workflows/*/* → .github/workflows/{name}.yml when stale or missing.
act_lib_sync_if_stale() {
  local root="$1"
  shift
  bash "${root}/act-platform/sync-workflows-for-act.sh" --if-stale "$@"
}

# Resolve -W path: accept workflows/{cat}/{name} source paths for act.
act_lib_resolve_workflow_path() {
  local root="$1"
  local workflow_path="$2"
  local component name resolved

  if [[ "${workflow_path}" =~ ^workflows/[^/]+/[^/]+$ ]]; then
    component="${workflow_path}"
    act_lib_sync_if_stale "${root}" "${component}" >/dev/null
    name="$(basename "${component}")"
    resolved="${root}/.github/workflows/${name}.yml"
  elif [[ "${workflow_path}" =~ ^workflows/[^/]+/[^/]+/workflow\.ya?ml$ ]]; then
    component="${workflow_path%/workflow.yml}"
    component="${component%/workflow.yaml}"
    act_lib_sync_if_stale "${root}" "${component}" >/dev/null
    name="$(basename "${component}")"
    resolved="${root}/.github/workflows/${name}.yml"
  elif [[ "${workflow_path}" =~ \.github/workflows/([^/]+)\.ya?ml$ ]]; then
    name="${BASH_REMATCH[1]}"
    component="$(find "${root}/workflows" -mindepth 2 -maxdepth 2 -type d -name "${name}" 2>/dev/null | head -n1 || true)"
    if [[ -n "${component}" ]]; then
      act_lib_sync_if_stale "${root}" "${component#"${root}"/}" >/dev/null
    fi
    if [[ "${workflow_path}" != /* ]]; then
      resolved="${root}/${workflow_path}"
    else
      resolved="${workflow_path}"
    fi
  elif [[ "${workflow_path}" != /* ]]; then
    resolved="${root}/${workflow_path}"
  else
    resolved="${workflow_path}"
  fi

  if [[ ! -f "${resolved}" ]]; then
    echo "[ERR] workflow file not found: ${resolved}" >&2
    return 1
  fi
  printf '%s' "${resolved}"
}

act_lib_platform_flags() {
  if ! docker image inspect gha-act-ubuntu:dev >/dev/null 2>&1; then
    echo "[DBG] gha-act-ubuntu:dev missing; using catthehacker/ubuntu:act-latest" >&2
    printf '%s\n' '-P' 'ubuntu-latest=catthehacker/ubuntu:act-latest'
  fi
}

# Build --local-repository flags and ensure local version tags for house refs.
act_lib_local_repo_flags() {
  local root="$1"
  local map_dir="$2"
  local ensure_tags="$3"
  shift 3
  local -a search_roots=("$@")
  local repo_slug uses ref f
  local -a flags=()
  declare -A seen_ref=()

  repo_slug="$(act_lib_repo_slug "${root}")"

  while IFS= read -r uses; do
    [[ -z "${uses}" || "${uses}" != *"@"* ]] && continue
    ref="${uses##*@}"
    [[ -n "${seen_ref[${ref}]:-}" ]] && continue
    seen_ref["${ref}"]=1
    flags+=(--local-repository "${repo_slug}@${ref}=${map_dir}")
    echo "[MAP] ${repo_slug}@${ref} -> ${map_dir}" >&2
    if [[ "${ensure_tags}" -eq 1 && "${ref}" == */v* ]]; then
      if git -C "${root}" rev-parse "refs/tags/${ref}" >/dev/null 2>&1; then
        echo "[TAG] exists ${ref}" >&2
      else
        git -C "${root}" tag "${ref}" HEAD
        echo "[TAG] created local ${ref} -> HEAD (not pushed)" >&2
      fi
    fi
  done < <(
    find "${search_roots[@]}" -type f \( -name '*.yml' -o -name '*.yaml' \) -print0 2>/dev/null \
      | while IFS= read -r -d '' f; do
          grep -Eho "uses:[[:space:]]*${repo_slug}[^[:space:]]+" "${f}" 2>/dev/null || true
        done \
      | sed 's/uses:[[:space:]]*//' | sort -u
  )

  printf '%s\n' "${flags[@]}"
}

act_lib_ensure_component_tags() {
  local root="$1"
  local component_path="$2"
  local map_dir="$3"
  local ensure_tags="$4"
  local cname repo_slug t
  local -a extra_flags=()

  [[ -n "${component_path}" ]] || return 0
  cname="$(basename "${component_path}")"
  repo_slug="$(act_lib_repo_slug "${root}")"
  for t in "${cname}/v1" "${cname}/v1.0.0"; do
    extra_flags+=(--local-repository "${repo_slug}@${t}=${map_dir}")
    echo "[MAP] ${repo_slug}@${t} -> ${map_dir}" >&2
    if [[ "${ensure_tags}" -eq 1 ]] && ! git -C "${root}" rev-parse "refs/tags/${t}" >/dev/null 2>&1; then
      git -C "${root}" tag "${t}" HEAD
      echo "[TAG] created local ${t} -> HEAD (not pushed)" >&2
    fi
  done
  printf '%s\n' "${extra_flags[@]}"
}
