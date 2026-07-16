#!/usr/bin/env bash
# Install Istio CRDs only (includes VirtualService). Controllers are NOT installed.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=.github/prereq/_lib.sh
source "${ROOT_DIR}/.github/prereq/_lib.sh"

ISTIO_VERSION="${ISTIO_VERSION:-1.30.2}"
ISTIO_CRDS_URL="${ISTIO_CRDS_URL:-https://raw.githubusercontent.com/istio/istio/${ISTIO_VERSION}/manifests/charts/base/files/crd-all.gen.yaml}"

require_bins kubectl

if kubectl get crd virtualservices.networking.istio.io >/dev/null 2>&1; then
  log "Istio CRDs already present"
  exit 0
fi

log "Installing Istio CRDs (${ISTIO_VERSION})"
kubectl apply --server-side --force-conflicts -f "${ISTIO_CRDS_URL}"

wait_crd_established \
  crd/virtualservices.networking.istio.io

log "Istio CRDs ready"
