#!/usr/bin/env bash
# Install KEDA CRDs only (ScaledObject, ScaledJob, TriggerAuthentication, …).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=.github/prereq/_lib.sh
source "${ROOT_DIR}/.github/prereq/_lib.sh"

KEDA_VERSION="${KEDA_VERSION:-v2.20.1}"
KEDA_CRDS_URL="${KEDA_CRDS_URL:-https://github.com/kedacore/keda/releases/download/${KEDA_VERSION}/keda-${KEDA_VERSION#v}-crds.yaml}"

require_bins kubectl

if kubectl get crd scaledobjects.keda.sh >/dev/null 2>&1 \
  && kubectl get crd scaledjobs.keda.sh >/dev/null 2>&1 \
  && kubectl get crd triggerauthentications.keda.sh >/dev/null 2>&1; then
  log "KEDA CRDs already present"
  exit 0
fi

log "Installing KEDA CRDs (${KEDA_VERSION})"
kubectl apply --server-side --force-conflicts -f "${KEDA_CRDS_URL}"

wait_crd_established \
  crd/scaledobjects.keda.sh \
  crd/scaledjobs.keda.sh \
  crd/triggerauthentications.keda.sh

log "KEDA CRDs ready"
