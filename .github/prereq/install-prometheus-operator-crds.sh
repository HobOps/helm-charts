#!/usr/bin/env bash
# Install Prometheus Operator CRDs only (no controller).
#
# Uses the release "stripped-down-crds.yaml" asset (OpenAPI schemas retained for
# API-server validation; description noise removed).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=.github/prereq/_lib.sh
source "${ROOT_DIR}/.github/prereq/_lib.sh"

PROMETHEUS_OPERATOR_VERSION="${PROMETHEUS_OPERATOR_VERSION:-v0.93.0}"
PROMETHEUS_OPERATOR_CRDS_URL="${PROMETHEUS_OPERATOR_CRDS_URL:-https://github.com/prometheus-operator/prometheus-operator/releases/download/${PROMETHEUS_OPERATOR_VERSION}/stripped-down-crds.yaml}"

require_bins kubectl

if kubectl get crd servicemonitors.monitoring.coreos.com >/dev/null 2>&1 \
  && kubectl get crd podmonitors.monitoring.coreos.com >/dev/null 2>&1 \
  && kubectl get crd probes.monitoring.coreos.com >/dev/null 2>&1 \
  && kubectl get crd prometheusrules.monitoring.coreos.com >/dev/null 2>&1 \
  && kubectl get crd prometheuses.monitoring.coreos.com >/dev/null 2>&1 \
  && kubectl get crd alertmanagers.monitoring.coreos.com >/dev/null 2>&1 \
  && kubectl get crd thanosrulers.monitoring.coreos.com >/dev/null 2>&1 \
  && kubectl get crd prometheusagents.monitoring.coreos.com >/dev/null 2>&1 \
  && kubectl get crd scrapeconfigs.monitoring.coreos.com >/dev/null 2>&1 \
  && kubectl get crd alertmanagerconfigs.monitoring.coreos.com >/dev/null 2>&1; then
  log "Prometheus Operator CRDs already present"
  exit 0
fi

log "Installing Prometheus Operator CRDs (${PROMETHEUS_OPERATOR_VERSION})"
kubectl apply --server-side --force-conflicts -f "${PROMETHEUS_OPERATOR_CRDS_URL}"

CRD_WAIT_TIMEOUT_S=180 wait_crd_established \
  crd/servicemonitors.monitoring.coreos.com \
  crd/podmonitors.monitoring.coreos.com \
  crd/probes.monitoring.coreos.com \
  crd/prometheusrules.monitoring.coreos.com \
  crd/prometheuses.monitoring.coreos.com \
  crd/alertmanagers.monitoring.coreos.com \
  crd/thanosrulers.monitoring.coreos.com \
  crd/prometheusagents.monitoring.coreos.com \
  crd/scrapeconfigs.monitoring.coreos.com \
  crd/alertmanagerconfigs.monitoring.coreos.com

log "Prometheus Operator CRDs ready"
