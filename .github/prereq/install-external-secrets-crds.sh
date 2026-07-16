#!/usr/bin/env bash
# Install External Secrets Operator CRDs only (no controller).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=.github/prereq/_lib.sh
source "${ROOT_DIR}/.github/prereq/_lib.sh"

EXTERNAL_SECRETS_VERSION="${EXTERNAL_SECRETS_VERSION:-v2.7.0}"
EXTERNAL_SECRETS_CRDS_URL="${EXTERNAL_SECRETS_CRDS_URL:-https://raw.githubusercontent.com/external-secrets/external-secrets/${EXTERNAL_SECRETS_VERSION}/deploy/crds/bundle.yaml}"

require_bins kubectl

if kubectl get crd externalsecrets.external-secrets.io >/dev/null 2>&1 \
  && kubectl get crd secretstores.external-secrets.io >/dev/null 2>&1 \
  && kubectl get crd clustersecretstores.external-secrets.io >/dev/null 2>&1 \
  && kubectl get crd clusterexternalsecrets.external-secrets.io >/dev/null 2>&1 \
  && kubectl get crd pushsecrets.external-secrets.io >/dev/null 2>&1; then
  log "External Secrets CRDs already present"
  exit 0
fi

log "Installing External Secrets CRDs (${EXTERNAL_SECRETS_VERSION})"
kubectl apply --server-side --force-conflicts -f "${EXTERNAL_SECRETS_CRDS_URL}"

CRD_WAIT_TIMEOUT_S=180 wait_crd_established \
  crd/externalsecrets.external-secrets.io \
  crd/secretstores.external-secrets.io \
  crd/clustersecretstores.external-secrets.io \
  crd/clusterexternalsecrets.external-secrets.io \
  crd/pushsecrets.external-secrets.io

log "External Secrets CRDs ready"
