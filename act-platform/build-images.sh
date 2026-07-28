#!/usr/bin/env bash
# Build portable local act runner images (Ubuntu + UBI9).
set -euo pipefail

KIT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UBUNTU_TAG="${ACT_UBUNTU_TAG:-gha-act-ubuntu:dev}"
UBI9_TAG="${ACT_UBI9_TAG:-gha-act-ubi9:dev}"

if ! command -v docker >/dev/null 2>&1; then
  echo "error: docker not found on PATH" >&2
  exit 1
fi

echo "==> Building ${UBUNTU_TAG}"
docker build -t "${UBUNTU_TAG}" -f "${KIT_ROOT}/image/ubuntu/Dockerfile" "${KIT_ROOT}/image/ubuntu"

echo "==> Building ${UBI9_TAG}"
docker build -t "${UBI9_TAG}" -f "${KIT_ROOT}/image/ubi9/Dockerfile" "${KIT_ROOT}/image/ubi9"

echo "==> Done"
docker images --format 'table {{.Repository}}:{{.Tag}}\t{{.ID}}\t{{.Size}}' | head -n 1
docker images --format 'table {{.Repository}}:{{.Tag}}\t{{.ID}}\t{{.Size}}' | grep -E 'gha-act-(ubuntu|ubi9)' || true
