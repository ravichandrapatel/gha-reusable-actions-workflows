#!/usr/bin/env bash
# FILE_NAME: s2i-build.sh
# DESCRIPTION: Run Red Hat source-to-image build against staged binary source.
# VERSION: 1.0.0
# AUTHORS: DevOps Team
set -euo pipefail

SOURCE=""
BUILDER_IMAGE=""
IMAGE=""
TLS_VERIFY="true"
PULL_POLICY="if-not-present"
LOG_LEVEL="1"

usage() {
  echo "ERROR: unknown argument $1" >&2
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source) SOURCE="$2"; shift 2 ;;
    --builder-image) BUILDER_IMAGE="$2"; shift 2 ;;
    --image) IMAGE="$2"; shift 2 ;;
    --tls-verify) TLS_VERIFY="$2"; shift 2 ;;
    --pull-policy) PULL_POLICY="$2"; shift 2 ;;
    --loglevel) LOG_LEVEL="$2"; shift 2 ;;
    *) usage "$1" ;;
  esac
done

if [[ -z "${SOURCE}" || -z "${BUILDER_IMAGE}" || -z "${IMAGE}" ]]; then
  echo "ERROR: --source, --builder-image, and --image are required" >&2
  exit 1
fi

if [[ ! "${BUILDER_IMAGE}" =~ ^[A-Za-z0-9._:/-]+$ ]]; then
  echo "ERROR: builder_image is not a valid image reference" >&2
  exit 1
fi

if [[ "${TLS_VERIFY}" != "true" && "${TLS_VERIFY}" != "false" ]]; then
  echo "ERROR: tls_verify must be true or false" >&2
  exit 1
fi

case "${PULL_POLICY}" in
  always|if-not-present|never) ;;
  *)
    echo "ERROR: pull_policy must be always, if-not-present, or never" >&2
    exit 1
    ;;
esac

if [[ ! -d "${SOURCE}" ]]; then
  echo "ERROR: source directory not found: ${SOURCE}" >&2
  exit 1
fi
if [[ -z "$(ls -A "${SOURCE}" 2>/dev/null)" ]]; then
  echo "ERROR: source directory is empty: ${SOURCE}" >&2
  exit 1
fi

if ! command -v s2i >/dev/null; then
  echo "ERROR: s2i not found on PATH" >&2
  exit 1
fi
if ! command -v buildah >/dev/null; then
  echo "ERROR: buildah not found on PATH (required for s2i on this runner)" >&2
  exit 1
fi

echo "s2i source : ${SOURCE}"
echo "s2i builder : ${BUILDER_IMAGE}"
echo "s2i image : ${IMAGE}"

s2i build \
  --loglevel="${LOG_LEVEL}" \
  --pull-policy="${PULL_POLICY}" \
  --tls-verify="${TLS_VERIFY}" \
  "${SOURCE}" \
  "${BUILDER_IMAGE}" \
  "${IMAGE}"
