#!/usr/bin/env bash
# Install the minimum Kind APIs needed for common-library Kind CI.
#
# Goal: validate that chart fixtures apply cleanly against the API server
# (schema / CEL / unknown fields). Controllers are intentionally NOT installed.
#
# Flow:
#   1. Assert Kind StorageClass (local-path as "standard"; Kind ships this)
#   2. Gateway API CRDs
#   3. cert-manager CRDs
#   4. Argo CD CRDs
#   5. External Secrets CRDs
#   6. KEDA CRDs
#   7. IngressClass + GatewayClass stubs (no Traefik)
#
# Usage:
#   ./.github/prereq/install-all.sh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PREREQ_DIR="${ROOT_DIR}/.github/prereq"

# shellcheck source=.github/prereq/_lib.sh
source "${PREREQ_DIR}/_lib.sh"

STORAGE_CLASS_NAME="${LOCAL_PATH_STORAGE_CLASS:-standard}"
PROVISIONER="${LOCAL_PATH_PROVISIONER:-rancher.io/local-path}"

assert_kind_storage() {
  if ! kubectl get storageclass "${STORAGE_CLASS_NAME}" >/dev/null 2>&1; then
    die "StorageClass/${STORAGE_CLASS_NAME} missing (expected Kind local-path default)"
  fi
  local provisioner
  provisioner="$(kubectl get storageclass "${STORAGE_CLASS_NAME}" -o jsonpath='{.provisioner}')"
  if [[ "${provisioner}" != "${PROVISIONER}" ]]; then
    die "StorageClass/${STORAGE_CLASS_NAME} provisioner is ${provisioner} (want ${PROVISIONER})"
  fi
  log "Using Kind StorageClass/${STORAGE_CLASS_NAME} (${provisioner})"
}

require_bins kubectl

log "Installing Kind prereqs for common-library testing (CRDs + stubs)"
assert_kind_storage
"${PREREQ_DIR}/install-gateway-api-crds.sh"
"${PREREQ_DIR}/install-cert-manager-crds.sh"
"${PREREQ_DIR}/install-argocd-crds.sh"
"${PREREQ_DIR}/install-external-secrets-crds.sh"
"${PREREQ_DIR}/install-keda-crds.sh"
"${PREREQ_DIR}/install-stubs.sh"

if ! kubectl get ingressclass traefik >/dev/null 2>&1; then
  die "IngressClass/traefik stub was not created"
fi
if ! kubectl get gatewayclass traefik >/dev/null 2>&1; then
  die "GatewayClass/traefik stub was not created"
fi
if ! kubectl get crd certificates.cert-manager.io >/dev/null 2>&1; then
  die "cert-manager CRDs are not available"
fi
if ! kubectl get crd gateways.gateway.networking.k8s.io >/dev/null 2>&1; then
  die "Gateway API CRDs are not available"
fi
if ! kubectl get crd applications.argoproj.io >/dev/null 2>&1; then
  die "Argo CD CRDs are not available"
fi
if ! kubectl get crd externalsecrets.external-secrets.io >/dev/null 2>&1; then
  die "External Secrets CRDs are not available"
fi
if ! kubectl get crd scaledobjects.keda.sh >/dev/null 2>&1; then
  die "KEDA CRDs are not available"
fi

log "All Kind prereqs installed"
