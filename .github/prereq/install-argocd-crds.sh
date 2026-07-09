#!/usr/bin/env bash
# Install Argo CD CRDs only (Application, AppProject, ApplicationSet).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=.github/prereq/_lib.sh
source "${ROOT_DIR}/.github/prereq/_lib.sh"

ARGOCD_VERSION="${ARGOCD_VERSION:-v3.4.4}"
ARGOCD_CRDS_URL="${ARGOCD_CRDS_URL:-https://github.com/argoproj/argo-cd/manifests/crds?ref=${ARGOCD_VERSION}}"

require_bins kubectl

if kubectl get crd applications.argoproj.io >/dev/null 2>&1 \
  && kubectl get crd appprojects.argoproj.io >/dev/null 2>&1 \
  && kubectl get crd applicationsets.argoproj.io >/dev/null 2>&1; then
  log "Argo CD CRDs already present"
  exit 0
fi

log "Installing Argo CD CRDs (${ARGOCD_VERSION})"
kubectl apply --server-side --force-conflicts -k "${ARGOCD_CRDS_URL}"

# Wait one CRD at a time; batch wait can race while status.conditions is still nil.
for crd in \
  applications.argoproj.io \
  appprojects.argoproj.io \
  applicationsets.argoproj.io; do
  kubectl wait --for=condition=Established "crd/${crd}" --timeout=120s
done

log "Argo CD CRDs ready"
