#!/usr/bin/env bash
# Install the MetalLB CRDs used by common-library templates (no controller,
# speaker or webhooks).
#
# The CRDs come from the pinned MetalLB tag (config/crd/bases). Only the kinds
# with a common-library template are applied, so Kind CI can validate fixtures
# against the real OpenAPI schemas. Without the MetalLB webhook there is no
# v1beta1 <-> v1beta2 conversion for BGPPeer; templates use v1beta2 (storage).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=.github/prereq/_lib.sh
source "${ROOT_DIR}/.github/prereq/_lib.sh"

METALLB_VERSION="${METALLB_VERSION:-v0.16.1}"
METALLB_CRDS_BASE_URL="${METALLB_CRDS_BASE_URL:-https://raw.githubusercontent.com/metallb/metallb/${METALLB_VERSION}/config/crd/bases}"

METALLB_CRDS=(
  ipaddresspools
  bgppeers
  bgpadvertisements
  bfdprofiles
  l2advertisements
  communities
)

require_bins kubectl

missing=0
for crd in "${METALLB_CRDS[@]}"; do
  if ! kubectl get crd "${crd}.metallb.io" >/dev/null 2>&1; then
    missing=1
  fi
done
if ((missing == 0)); then
  log "MetalLB CRDs already present"
  exit 0
fi

log "Installing MetalLB CRDs (${METALLB_VERSION})"
for crd in "${METALLB_CRDS[@]}"; do
  kubectl apply --server-side --force-conflicts -f "${METALLB_CRDS_BASE_URL}/metallb.io_${crd}.yaml"
done

wait_targets=()
for crd in "${METALLB_CRDS[@]}"; do
  wait_targets+=("crd/${crd}.metallb.io")
done
CRD_WAIT_TIMEOUT_S=180 wait_crd_established "${wait_targets[@]}"

log "MetalLB CRDs ready"
