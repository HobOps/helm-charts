#!/usr/bin/env bash
# Install Kubernetes Gateway API CRDs (standard channel).
# Used by Kind CI for API-server schema validation of Gateway / HTTPRoute / etc.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=.github/prereq/_lib.sh
source "${ROOT_DIR}/.github/prereq/_lib.sh"

# Pin to a Gateway API release compatible with Kind CI (K8s >= 1.31).
GATEWAY_API_VERSION="${GATEWAY_API_VERSION:-v1.5.1}"
GATEWAY_API_URL="${GATEWAY_API_MANIFEST_URL:-https://github.com/kubernetes-sigs/gateway-api/releases/download/${GATEWAY_API_VERSION}/standard-install.yaml}"

require_bins kubectl

if kubectl get crd gateways.gateway.networking.k8s.io >/dev/null 2>&1 \
  && kubectl get crd httproutes.gateway.networking.k8s.io >/dev/null 2>&1 \
  && kubectl get crd gatewayclasses.gateway.networking.k8s.io >/dev/null 2>&1; then
  log "Gateway API CRDs already present"
  exit 0
fi

log "Installing Gateway API CRDs (${GATEWAY_API_VERSION})"
kubectl apply --server-side --force-conflicts -f "${GATEWAY_API_URL}"

wait_crd_established \
  crd/gateways.gateway.networking.k8s.io \
  crd/gatewayclasses.gateway.networking.k8s.io \
  crd/httproutes.gateway.networking.k8s.io

log "Gateway API CRDs ready"
