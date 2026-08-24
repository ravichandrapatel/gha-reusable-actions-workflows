#!/usr/bin/env bash
# =============================================================================
# FILE_NAME: release-manager-execute.sh
# DESCRIPTION: Release Manager execute stage — tag, sync, promote, rollback.
# VERSION: 1.1.0
# EXIT_CODES/SIGNALS: 0 on success, 1 on failure.
# AUTHORS: DevOps Team
# =============================================================================
set -euo pipefail

# Required env (map from workflow via env:): MODE, COMPONENT_PATH, COMPONENT_NAME,
# COMPONENT_TYPE, VERSION, SAFE_NAME, WF_FILE, SCANNED_SHA

: "${MODE:?MODE is required}"
: "${COMPONENT_PATH:?COMPONENT_PATH is required}"
: "${COMPONENT_NAME:?COMPONENT_NAME is required}"
: "${COMPONENT_TYPE:?COMPONENT_TYPE is required}"
: "${VERSION:?VERSION is required}"
: "${SAFE_NAME:?SAFE_NAME is required}"
: "${SCANNED_SHA:?SCANNED_SHA is required}"

# shellcheck source=release-manager-lib.sh
# shellcheck disable=SC1090
source "${BASH_SOURCE[0]%/*}/release-manager-lib.sh"

STABLE_TAG="${SAFE_NAME}/v1"
VERSION_TAG="${SAFE_NAME}/v${VERSION}"
VERSIONED_TAG_GLOB="${SAFE_NAME}/v*.*.*"

echo "[DBG-030] Starting execution for mode: ${MODE}"

if [[ "${MODE}" == "release" || "${MODE}" == "release-promote" ]]; then
  release_manager_prepare_main_branch
  release_manager_assert_component_unchanged_since_scan "${SCANNED_SHA}" "${COMPONENT_PATH}"

  if [[ "${COMPONENT_TYPE}" == "workflow" ]]; then
    SRC_WF="${COMPONENT_PATH}/${WF_FILE}"
    DEST_WF=".github/workflows/${COMPONENT_NAME}.yml"
    echo "[DBG-035] Syncing workflow file from ${SRC_WF} to ${DEST_WF}"
    mkdir -p .github/workflows
    cp "${SRC_WF}" "${DEST_WF}"
    git add "${DEST_WF}"
    if git diff --cached --quiet; then
      echo "[DBG-036] No changes to commit for workflow sync"
    else
      git commit -m "DCDT-0000 chore(release): sync workflow ${COMPONENT_NAME} to ${VERSION}"
      release_manager_sync_main_with_retry
      git push origin main
    fi
    echo "[DBG-037] Successfully synced workflow to main"
  fi

  release_manager_sync_main_with_retry
  release_manager_assert_release_tag_commit "${SCANNED_SHA}" "${COMPONENT_TYPE}" "${COMPONENT_NAME}"
  echo "[DBG-031] Creating versioned tag: ${VERSION_TAG} at $(git rev-parse HEAD)"
  git tag -a "${VERSION_TAG}" -m "Release ${VERSION_TAG}"
  git push origin "${VERSION_TAG}"
  echo "[DBG-032] Successfully pushed versioned tag"
fi

if [[ "${MODE}" == "promote" || "${MODE}" == "release-promote" ]]; then
  if [[ "${MODE}" == "promote" ]]; then
    release_manager_prepare_main_branch
  fi
  echo "[DBG-033] Starting promotion of ${VERSION_TAG} to ${STABLE_TAG}"
  echo "[DBG-033a] Updating stable tag ${STABLE_TAG} to commit of ${VERSION_TAG}"
  git tag -d "${STABLE_TAG}" 2>/dev/null || true
  TARGET_COMMIT="$(git rev-parse "${VERSION_TAG}^{commit}")"
  if [[ "${MODE}" == "promote" && "${TARGET_COMMIT}" != "${SCANNED_SHA}" ]]; then
    echo "[ERR-T-13] ${VERSION_TAG} commit (${TARGET_COMMIT}) != scan_commit (${SCANNED_SHA}). Aborting promote." >&2
    exit 1
  fi
  git tag -a "${STABLE_TAG}" "${TARGET_COMMIT}" -m "Promote to ${VERSION_TAG}"
  release_manager_assert_stable_tag_is_commit "${STABLE_TAG}"
  echo "[DBG-033b] Pushing stable tag to remote"
  release_manager_delete_remote_tag_if_present "${STABLE_TAG}"
  git push origin "${STABLE_TAG}"
  echo "[DBG-034] Successfully updated stable tag"

elif [[ "${MODE}" == "rollback" ]]; then
  release_manager_prepare_main_branch
  echo "[DBG-038] Starting rollback for ${STABLE_TAG}"
  PREV_TAG="$(release_manager_find_prev_versioned_tag "${VERSION_TAG}" "${VERSIONED_TAG_GLOB}")"
  if [[ -z "${PREV_TAG}" || "${PREV_TAG}" == "${VERSION_TAG}" ]]; then
    echo "[ERR-T-07] No previous version found for rollback from ${VERSION_TAG}." >&2
    exit 1
  fi
  echo "[DBG-039] Identified previous version: ${PREV_TAG}"
  TARGET_COMMIT="$(git rev-parse "${PREV_TAG}^{commit}")"
  if [[ "${TARGET_COMMIT}" != "${SCANNED_SHA}" ]]; then
    echo "[ERR-T-13] ${PREV_TAG} commit (${TARGET_COMMIT}) != scan_commit (${SCANNED_SHA}). Aborting rollback." >&2
    exit 1
  fi

  if [[ "${COMPONENT_TYPE}" == "workflow" ]]; then
    DEST_WF=".github/workflows/${COMPONENT_NAME}.yml"
    PREV_WF_FILE="$(release_manager_discover_workflow_file_at_ref "${PREV_TAG}" "${COMPONENT_PATH}")"
    echo "[DBG-041] Restoring workflow file from tag ${PREV_TAG} (${PREV_WF_FILE})"
    git checkout "${PREV_TAG}" -- "${COMPONENT_PATH}/${PREV_WF_FILE}"
    cp "${COMPONENT_PATH}/${PREV_WF_FILE}" "${DEST_WF}"
    git checkout HEAD -- "${COMPONENT_PATH}/${PREV_WF_FILE}"
    git add "${DEST_WF}"
    if git diff --cached --quiet; then
      echo "[DBG-042] No changes to commit for workflow rollback"
    else
      git commit -m "DCDT-0000 chore(release): rollback workflow ${COMPONENT_NAME} to ${PREV_TAG}"
      release_manager_sync_main_with_retry
      git push origin main
    fi
    echo "[DBG-043] Successfully restored workflow file to main"
  fi

  echo "[DBG-040] Updating stable tag ${STABLE_TAG} to commit of ${PREV_TAG}"
  git tag -d "${STABLE_TAG}" 2>/dev/null || true
  git tag -a "${STABLE_TAG}" "${TARGET_COMMIT}" -m "Rollback to ${PREV_TAG}"
  release_manager_assert_stable_tag_is_commit "${STABLE_TAG}"
  release_manager_delete_remote_tag_if_present "${STABLE_TAG}"
  git push origin "${STABLE_TAG}"
  echo "[DBG-040a] Successfully rolled back stable tag to ${PREV_TAG}"
fi
