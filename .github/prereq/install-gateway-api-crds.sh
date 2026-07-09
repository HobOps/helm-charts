#!/usr/bin/env bash
# Install Kubernetes Gateway API CRDs (standard channel).
# Required before enabling Traefik providers.kubernetesGateway (chart no longer ships them).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=.github/prereq/_lib.sh
source "${ROOT_DIR}/.github/prereq/_lib.sh"

# Traefik v3.7 / chart 41.x recommends Gateway API v1.5.1 standard channel.
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

kubectl wait --for=condition=Established \
  crd/gateways.gateway.networking.k8s.io \
  crd/gatewayclasses.gateway.networking.k8s.io \
  crd/httproutes.gateway.networking.k8s.io \
  --timeout=120s

log "Gateway API CRDs ready"
