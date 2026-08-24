#!/usr/bin/env bash
# FILE_NAME: kind-up.sh
# DESCRIPTION: Create a kind cluster and apply the kind/dev GitHub ARC overlay.
# VERSION: 0.3.2
# AUTHORS: ravichandrapatel
set -euo pipefail

# _log("[T-01] resolve paths and docker socket")
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "${ROOT}/.." && pwd)"
OVERLAY="${ROOT}/components/overlays/kind/dev"
export DOCKER_HOST="${DOCKER_HOST:-unix:///var/run/docker.sock}"
CLUSTER="${KIND_CLUSTER_NAME:-arc-dev}"
NAMESPACE="${ARC_NAMESPACE:-$(awk '/^namespace:/{print $2; exit}' "${OVERLAY}/kustomization.yaml")}"
PEM="${GITHUB_APP_PEM:-${REPO_ROOT}/thecaptainhub-platform-app.2026-07-29.private-key.pem}"

usage() {
  cat <<'EOF'
Usage: kustomize/scripts/kind-up.sh

Creates kind cluster arc-dev (or KIND_CLUSTER_NAME) and applies
components/overlays/kind/dev (controller + all three runner modes).

Reads namespace from the overlay `namespace:` field unless ARC_NAMESPACE is set.
Injects github-config from GitHub App id/installation id plus the repo-root PEM.
Does not print the private key.

Environment:
  DOCKER_HOST          default unix:///var/run/docker.sock
  KIND_CLUSTER_NAME    default arc-dev
  ARC_NAMESPACE        default: overlay kustomization.yaml namespace:
  GITHUB_APP_PEM       default: <repo>/thecaptainhub-platform-app.2026-07-29.private-key.pem
EOF
}

# _log("[T-02] parse args")
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown arg: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

# _log("[T-03] require PEM path without reading the key")
if [[ ! -f "${PEM}" ]]; then
  echo "missing GitHub App PEM at ${PEM}" >&2
  echo "set GITHUB_APP_PEM or place thecaptainhub-platform-app.2026-07-29.private-key.pem at repo root" >&2
  exit 1
fi

# _log("[T-04] create kind cluster if missing")
if ! kind get clusters | grep -qx "${CLUSTER}"; then
  echo "==> kind create cluster --name ${CLUSTER}"
  kind create cluster --name "${CLUSTER}" --wait 180s
else
  echo "==> kind cluster ${CLUSTER} already exists"
fi
kubectl cluster-info --context "kind-${CLUSTER}" >/dev/null
kubectl config use-context "kind-${CLUSTER}" >/dev/null

# _log("[T-05] apply CRDs server-side, then overlay without CRDs (client apply hits 256Ki annotation limit)")
CRD_DIR="${ROOT}/components/base/controller/0.13.1/charts/gha-runner-scale-set-controller-0.13.1/gha-runner-scale-set-controller/crds"
echo "==> apply CRDs --server-side from ${CRD_DIR}"
kubectl apply --server-side --force-conflicts -f "${CRD_DIR}"
kubectl wait --for=condition=Established crd/autoscalingrunnersets.actions.github.com --timeout=180s
kubectl wait --for=condition=Established crd/autoscalinglisteners.actions.github.com --timeout=180s
kubectl wait --for=condition=Established crd/ephemeralrunners.actions.github.com --timeout=180s
kubectl wait --for=condition=Established crd/ephemeralrunnersets.actions.github.com --timeout=180s
echo "==> kustomize build --enable-helm ${OVERLAY} (namespace=${NAMESPACE})"
kustomize build --enable-helm "${OVERLAY}" | python3 -c '
import sys
import yaml
docs = [d for d in yaml.safe_load_all(sys.stdin) if d and d.get("kind") != "CustomResourceDefinition"]
yaml.safe_dump_all(docs, sys.stdout, default_flow_style=False, sort_keys=False)
' | kubectl apply -f -

# _log("[T-06] upsert github-config with App ids + PEM (no key printed)")
kubectl -n "${NAMESPACE}" create secret generic github-config \
  --from-literal=github_app_id=3843629 \
  --from-literal=github_app_installation_id=149912085 \
  --from-file=github_app_private_key="${PEM}" \
  --dry-run=client -o yaml | kubectl apply -f -

# _log("[T-07] wait for controller")
kubectl -n "${NAMESPACE}" rollout status deploy/gha-runner-scale-set-controller-gha-rs-controller --timeout=180s

echo "==> resources in ${NAMESPACE}"
kubectl -n "${NAMESPACE}" get deploy,sa,secret,autoscalingrunnerset 2>/dev/null || true
echo "kind cluster ${CLUSTER} is ready. github-config uses GitHub App 3843629."
