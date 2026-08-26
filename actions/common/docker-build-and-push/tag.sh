#!/usr/bin/env bash
# FILE_NAME: tag.sh
# DESCRIPTION: Image path registry/org/product/app; tag date-version-build-branch-sha-archetype-parentversion.
# VERSION: 1.3.0
# AUTHORS: DevOps Team
set -euo pipefail

sanitize() {
  local text="$1"
  text="$(printf '%s' "${text}" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9._-]+/-/g; s/-{2,}/-/g; s/^[-._]+//; s/[-._]+$//')"
  if [[ -z "${text}" ]]; then
    echo "ERROR: empty tag segment after sanitize" >&2
    exit 1
  fi
  printf '%s' "${text}"
}

slice() {
  local text="$1"
  local max_len="$2"
  printf '%s' "${text:0:${max_len}}"
}

pad5() {
  local text="$1"
  while [[ "${#text}" -lt 5 ]]; do
    text="0${text}"
  done
  printf '%s' "${text: -5}"
}

REGISTRY="${REGISTRY:-}"
ORGANIZATION="${ORGANIZATION:-}"
PRODUCT="${PRODUCT:-}"
APPLICATION="${APPLICATION:-}"
PROJECT_VERSION="${PROJECT_VERSION:-}"
PARENT_VERSION="${PARENT_VERSION:-}"
REPO="${REPO:-${GITHUB_REPOSITORY:-}}"
BRANCH="${BRANCH:-${GITHUB_HEAD_REF:-${GITHUB_REF_NAME:-}}}"
SHA="${SHA:-${GIT_SHA:-${GITHUB_SHA:-}}}"
BUILD_NUMBER="${BUILD_NUMBER:-${GITHUB_RUN_NUMBER:-}}"
DATE_STAMP="${DATE_STAMP:-}"
OUTPUT="${OUTPUT:-${GITHUB_OUTPUT:-}}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --registry) REGISTRY="$2"; shift 2 ;;
    --organization) ORGANIZATION="$2"; shift 2 ;;
    --product) PRODUCT="$2"; shift 2 ;;
    --application) APPLICATION="$2"; shift 2 ;;
    --project-version) PROJECT_VERSION="$2"; shift 2 ;;
    --parent-version) PARENT_VERSION="$2"; shift 2 ;;
    --repo) REPO="$2"; shift 2 ;;
    --branch) BRANCH="$2"; shift 2 ;;
    --sha) SHA="$2"; shift 2 ;;
    --build-number) BUILD_NUMBER="$2"; shift 2 ;;
    --date) DATE_STAMP="$2"; shift 2 ;;
    --output) OUTPUT="$2"; shift 2 ;;
    *) echo "ERROR: unknown argument $1" >&2; exit 1 ;;
  esac
done

REGISTRY="$(printf '%s' "${REGISTRY}" | sed 's:/*$::')"
BRANCH="${BRANCH#refs/heads/}"
if [[ -z "${REGISTRY}" || -z "${ORGANIZATION}" || -z "${PRODUCT}" || -z "${APPLICATION}" || -z "${PROJECT_VERSION}" || -z "${PARENT_VERSION}" ]]; then
  echo "ERROR: registry, organization, product, application, project-version, and parent-version are required" >&2
  exit 1
fi
if [[ -z "${SHA}" ]]; then
  echo "ERROR: pass --sha or set GITHUB_SHA" >&2
  exit 1
fi
if [[ -z "${BUILD_NUMBER}" ]]; then
  echo "ERROR: pass --build-number or set GITHUB_RUN_NUMBER" >&2
  exit 1
fi
if [[ -z "${BRANCH}" ]]; then
  echo "ERROR: pass --branch or set GITHUB_HEAD_REF / GITHUB_REF_NAME" >&2
  exit 1
fi

APP_ARCHETYPE=""
if [[ -n "${REPO}" ]]; then
  REPO_NAME="${REPO##*/}"
  IFS='-' read -r -a parts <<< "${REPO_NAME}"
  if [[ "${#parts[@]}" -ge 2 ]]; then
    last=$((${#parts[@]} - 1))
    prev=$((last - 1))
    APP_ARCHETYPE="$(sanitize "${parts[prev]}-${parts[last]}")"
  fi
fi
if [[ -z "${APP_ARCHETYPE}" ]]; then
  echo "ERROR: app_archetype requires a repo name with at least two hyphen segments (pass --repo or set GITHUB_REPOSITORY)" >&2
  exit 1
fi
if [[ -z "${DATE_STAMP}" ]]; then
  DATE_STAMP="$(date -u +%Y%m%d)"
fi
ORG="$(sanitize "${ORGANIZATION}")"
PRODUCT_NAME="$(sanitize "${PRODUCT}")"
APP_NAME="$(sanitize "${APPLICATION}")"
# Tag segment uses numeric/version only — drop Maven -SNAPSHOT qualifier.
SNAP_VERSION="$(sanitize "$(printf '%s' "${PROJECT_VERSION}" | sed -E 's/-[Ss][Nn][Aa][Pp][Ss][Hh][Oo][Tt]$//')")"
PARENT_VER="$(sanitize "${PARENT_VERSION}")"
SHORT_BRANCH="$(slice "$(sanitize "${BRANCH}")" 3)"
SHORT_SHA="$(slice "$(sanitize "${SHA}")" 5)"
BUILD_ID="$(pad5 "$(sanitize "${BUILD_NUMBER}")")"
TAG="${DATE_STAMP}-${SNAP_VERSION}-${BUILD_ID}-${SHORT_BRANCH}-${SHORT_SHA}-${APP_ARCHETYPE}-${PARENT_VER}"
IMAGE="$(sanitize "${REGISTRY}")/${ORG}/${PRODUCT_NAME}/${APP_NAME}:${TAG}"

echo "tag : ${TAG}"
echo "image : ${IMAGE}"
echo "app_archetype : ${APP_ARCHETYPE}"
echo "application_name : ${APP_NAME}"
echo "product : ${PRODUCT_NAME}"
echo "organization : ${ORG}"
echo "project_version : ${SNAP_VERSION}"
echo "parent_version : ${PARENT_VER}"
echo "short_branch : ${SHORT_BRANCH}"
echo "short_sha : ${SHORT_SHA}"
echo "build_number : ${BUILD_ID}"
if [[ -n "${OUTPUT}" ]]; then
  {
    echo "tag=${TAG}"
    echo "image=${IMAGE}"
    echo "app_archetype=${APP_ARCHETYPE}"
    echo "application_name=${APP_NAME}"
    echo "product=${PRODUCT_NAME}"
    echo "organization=${ORG}"
    echo "project_version=${SNAP_VERSION}"
    echo "parent_version=${PARENT_VER}"
    echo "short_branch=${SHORT_BRANCH}"
    echo "short_sha=${SHORT_SHA}"
    echo "build_number=${BUILD_ID}"
  } >> "${OUTPUT}"
fi
