#!/usr/bin/env bash
# Install lightweight stubs so Ingress / Gateway fixtures can reference a class
# without running Traefik (or any controller).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=.github/prereq/_lib.sh
source "${ROOT_DIR}/.github/prereq/_lib.sh"

INGRESS_CLASS_NAME="${INGRESS_CLASS_NAME:-traefik}"
GATEWAY_CLASS_NAME="${GATEWAY_CLASS_NAME:-traefik}"

require_bins kubectl

if kubectl get ingressclass "${INGRESS_CLASS_NAME}" >/dev/null 2>&1; then
  log "IngressClass/${INGRESS_CLASS_NAME} already present"
else
  log "Ensuring IngressClass/${INGRESS_CLASS_NAME} stub"
  kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: IngressClass
metadata:
  name: ${INGRESS_CLASS_NAME}
  annotations:
    hobops.io/ci-stub: "true"
spec:
  controller: hobops.io/ci-stub
EOF
fi

if kubectl get gatewayclass "${GATEWAY_CLASS_NAME}" >/dev/null 2>&1; then
  log "GatewayClass/${GATEWAY_CLASS_NAME} already present"
else
  log "Ensuring GatewayClass/${GATEWAY_CLASS_NAME} stub"
  kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: ${GATEWAY_CLASS_NAME}
  annotations:
    hobops.io/ci-stub: "true"
spec:
  controllerName: hobops.io/ci-stub
EOF
fi

log "Class stubs ready"
