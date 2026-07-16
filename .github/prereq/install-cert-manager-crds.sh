#!/usr/bin/env bash
# Install cert-manager CRDs only (no controller / webhook).
# Enough for API-server schema validation of Certificate / Issuer / ClusterIssuer.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=.github/prereq/_lib.sh
source "${ROOT_DIR}/.github/prereq/_lib.sh"

CERT_MANAGER_VERSION="${CERT_MANAGER_VERSION:-v1.17.2}"
CERT_MANAGER_CRDS_URL="${CERT_MANAGER_CRDS_URL:-https://github.com/cert-manager/cert-manager/releases/download/${CERT_MANAGER_VERSION}/cert-manager.crds.yaml}"

require_bins kubectl

if kubectl get crd certificates.cert-manager.io >/dev/null 2>&1 \
  && kubectl get crd issuers.cert-manager.io >/dev/null 2>&1 \
  && kubectl get crd clusterissuers.cert-manager.io >/dev/null 2>&1; then
  log "cert-manager CRDs already present"
  exit 0
fi

log "Installing cert-manager CRDs (${CERT_MANAGER_VERSION})"
kubectl apply --server-side --force-conflicts -f "${CERT_MANAGER_CRDS_URL}"

wait_crd_established \
  crd/certificates.cert-manager.io \
  crd/issuers.cert-manager.io \
  crd/clusterissuers.cert-manager.io

log "cert-manager CRDs ready"
