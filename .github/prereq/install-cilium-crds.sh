#!/usr/bin/env bash
# Install the Cilium CRDs used by common-library templates (no agent/operator).
#
# The CRD manifests live in the Cilium source tree (the operator normally
# installs them). Only the kinds with a common-library template are applied,
# straight from the pinned tag, so Kind CI can validate fixtures against the
# real OpenAPI schemas.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=.github/prereq/_lib.sh
source "${ROOT_DIR}/.github/prereq/_lib.sh"

CILIUM_VERSION="${CILIUM_VERSION:-v1.20.2}"
CILIUM_CRDS_BASE_URL="${CILIUM_CRDS_BASE_URL:-https://raw.githubusercontent.com/cilium/cilium/${CILIUM_VERSION}/pkg/k8s/apis/cilium.io/client/crds/v2}"

CILIUM_CRDS=(
  ciliumbgpclusterconfigs
  ciliumbgppeerconfigs
  ciliumbgpadvertisements
  ciliumloadbalancerippools
  ciliumegressgatewaypolicies
  ciliumnetworkpolicies
  ciliumclusterwidenetworkpolicies
)

require_bins kubectl

missing=0
for crd in "${CILIUM_CRDS[@]}"; do
  if ! kubectl get crd "${crd}.cilium.io" >/dev/null 2>&1; then
    missing=1
  fi
done
if ((missing == 0)); then
  log "Cilium CRDs already present"
  exit 0
fi

log "Installing Cilium CRDs (${CILIUM_VERSION})"
for crd in "${CILIUM_CRDS[@]}"; do
  kubectl apply --server-side --force-conflicts -f "${CILIUM_CRDS_BASE_URL}/${crd}.yaml"
done

wait_targets=()
for crd in "${CILIUM_CRDS[@]}"; do
  wait_targets+=("crd/${crd}.cilium.io")
done
CRD_WAIT_TIMEOUT_S=180 wait_crd_established "${wait_targets[@]}"

log "Cilium CRDs ready"
