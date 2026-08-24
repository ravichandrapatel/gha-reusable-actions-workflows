#!/usr/bin/env bash
# =============================================================================
# FILE_NAME: release-manager-lib.sh
# DESCRIPTION: Shared Release Manager helpers (sourced by execute + validate).
# VERSION: 1.0.0
# EXIT_CODES/SIGNALS: Functions exit 1 on failure; sourced only.
# AUTHORS: DevOps Team
# =============================================================================

release_manager_sync_main_with_retry() {
  local attempt max_attempts=3
  for attempt in $(seq 1 "${max_attempts}"); do
    if git pull --rebase origin main; then
      return 0
    fi
    echo "[WARN-T-09] git pull --rebase attempt ${attempt}/${max_attempts} failed" >&2
    sleep $((attempt * 2))
  done
  echo "[ERR-T-09] git pull --rebase failed after ${max_attempts} attempts" >&2
  return 1
}

release_manager_prepare_main_branch() {
  git checkout main
  release_manager_sync_main_with_retry
}

release_manager_assert_component_unchanged_since_scan() {
  local scanned_sha="$1"
  local component_path="$2"
  if git diff --quiet "${scanned_sha}" HEAD -- "${component_path}"; then
    return 0
  fi
  echo "[ERR-T-08] Component changed on main since security scan (${scanned_sha}). Re-run release." >&2
  git diff --stat "${scanned_sha}" HEAD -- "${component_path}" >&2 || true
  exit 1
}

# Refuse to tag when HEAD includes changes outside scan scope since SCANNED_SHA.
# Actions: HEAD must equal SCANNED_SHA.
# Workflows: only .github/workflows/{name}.yml may differ (sync copy).
release_manager_assert_release_tag_commit() {
  local scanned_sha="$1"
  local component_type="$2"
  local component_name="$3"
  local head_sha
  head_sha="$(git rev-parse HEAD)"
  if [[ "${head_sha}" == "${scanned_sha}" ]]; then
    return 0
  fi
  local -a changed=()
  mapfile -t changed < <(git diff --name-only "${scanned_sha}" HEAD)
  if [[ ${#changed[@]} -eq 0 ]]; then
    return 0
  fi
  if [[ "${component_type}" == "workflow" && ${#changed[@]} -eq 1 \
    && "${changed[0]}" == ".github/workflows/${component_name}.yml" ]]; then
    return 0
  fi
  echo "[ERR-T-12] Refusing to tag: HEAD includes changes beyond scan scope since ${scanned_sha}." >&2
  git diff --stat "${scanned_sha}" HEAD >&2 || true
  exit 1
}

release_manager_assert_stable_tag_is_commit() {
  local tag="$1"
  local inner
  inner="$(git cat-file -p "refs/tags/${tag}" | awk '/^type / { print $2; exit }')"
  if [[ "${inner}" != "commit" ]]; then
    echo "[ERR-T-11] ${tag} points at '${inner:-unknown}', not commit. Nested tags break act (@v1 fails, @vX.Y.Z works)." >&2
    exit 1
  fi
  echo "[DBG-033c] ${tag} -> commit $(git rev-parse "${tag}^{commit}")"
}

release_manager_delete_remote_tag_if_present() {
  local tag="$1"
  if git ls-remote --exit-code --tags origin "refs/tags/${tag}" >/dev/null 2>&1; then
    git push origin ":refs/tags/${tag}"
  fi
}

release_manager_discover_workflow_file_at_ref() {
  local ref="$1"
  local component_path="$2"
  local -a files=()
  local path base
  while IFS= read -r path; do
    base="${path##*/}"
    case "${base}" in
      *.yml | *.yaml) files+=("${base}") ;;
    esac
  done < <(git ls-tree -r --name-only "${ref}" "${component_path}" 2>/dev/null || true)

  if [[ ${#files[@]} -eq 0 ]]; then
    echo "[ERR-T-14] No workflow yaml under ${component_path} at ${ref}" >&2
    exit 1
  fi
  if [[ ${#files[@]} -gt 1 ]]; then
    echo "[ERR-T-14b] Multiple workflow yaml files at ${ref}: ${files[*]}" >&2
    exit 1
  fi
  printf '%s' "${files[0]}"
}

# Print the versioned tag immediately before target_tag in sort -V order, or empty.
release_manager_find_prev_versioned_tag() {
  local target_tag="$1"
  local versioned_glob="$2"
  local -a version_tags=()
  local prev_tag="" i
  mapfile -t version_tags < <(git tag -l "${versioned_glob}" | sort -V)
  for i in "${!version_tags[@]}"; do
    if [[ "${version_tags[$i]}" == "${target_tag}" ]]; then
      if [[ "${i}" -gt 0 ]]; then
        prev_tag="${version_tags[$((i - 1))]}"
      fi
      break
    fi
  done
  printf '%s' "${prev_tag}"
}
