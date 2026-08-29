#!/usr/bin/env bash
# Install RabbitMQ Cluster Operator + Messaging Topology Operator CRDs only.
#
# Controllers are NOT installed. Manifests are filtered to CustomResourceDefinition
# documents so Kind CI can validate chart fixtures against the API server.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=.github/prereq/_lib.sh
source "${ROOT_DIR}/.github/prereq/_lib.sh"

RABBITMQ_CLUSTER_OPERATOR_VERSION="${RABBITMQ_CLUSTER_OPERATOR_VERSION:-v2.22.5}"
RABBITMQ_TOPOLOGY_OPERATOR_VERSION="${RABBITMQ_TOPOLOGY_OPERATOR_VERSION:-v1.20.2}"

CLUSTER_OPERATOR_URL="${RABBITMQ_CLUSTER_OPERATOR_URL:-https://github.com/rabbitmq/cluster-operator/releases/download/${RABBITMQ_CLUSTER_OPERATOR_VERSION}/cluster-operator.yml}"
TOPOLOGY_OPERATOR_URL="${RABBITMQ_TOPOLOGY_OPERATOR_URL:-https://github.com/rabbitmq/messaging-topology-operator/releases/download/${RABBITMQ_TOPOLOGY_OPERATOR_VERSION}/messaging-topology-operator.yaml}"

require_bins kubectl python3 curl

apply_crds_from_url() {
  local url="$1"
  local label="$2"
  local tmp
  tmp="$(mktemp)"
  # Filter multi-doc YAML to CRDs only (stdlib Python; no PyYAML required).
  curl -fsSL "${url}" | python3 -c '
import sys
docs = sys.stdin.read().split("---")
out = []
for doc in docs:
    # crude kind detection without a full YAML parse
    kind = None
    for line in doc.splitlines():
        if line.startswith("kind:"):
            kind = line.split(":", 1)[1].strip()
            break
    if kind == "CustomResourceDefinition":
        out.append(doc.strip())
if not out:
    sys.stderr.write("no CRDs found in stream\n")
    sys.exit(1)
sys.stdout.write("---\n" + "\n---\n".join(out) + "\n")
' >"${tmp}"
  log "Applying ${label} CRDs from ${url}"
  kubectl apply --server-side --force-conflicts -f "${tmp}"
  rm -f "${tmp}"
}

if kubectl get crd rabbitmqclusters.rabbitmq.com >/dev/null 2>&1 \
  && kubectl get crd vhosts.rabbitmq.com >/dev/null 2>&1 \
  && kubectl get crd exchanges.rabbitmq.com >/dev/null 2>&1 \
  && kubectl get crd queues.rabbitmq.com >/dev/null 2>&1 \
  && kubectl get crd bindings.rabbitmq.com >/dev/null 2>&1 \
  && kubectl get crd users.rabbitmq.com >/dev/null 2>&1 \
  && kubectl get crd permissions.rabbitmq.com >/dev/null 2>&1 \
  && kubectl get crd topicpermissions.rabbitmq.com >/dev/null 2>&1 \
  && kubectl get crd policies.rabbitmq.com >/dev/null 2>&1 \
  && kubectl get crd operatorpolicies.rabbitmq.com >/dev/null 2>&1 \
  && kubectl get crd federations.rabbitmq.com >/dev/null 2>&1 \
  && kubectl get crd shovels.rabbitmq.com >/dev/null 2>&1 \
  && kubectl get crd schemareplications.rabbitmq.com >/dev/null 2>&1 \
  && kubectl get crd superstreams.rabbitmq.com >/dev/null 2>&1; then
  log "RabbitMQ operator CRDs already present"
  exit 0
fi

log "Installing RabbitMQ operator CRDs (cluster ${RABBITMQ_CLUSTER_OPERATOR_VERSION}, topology ${RABBITMQ_TOPOLOGY_OPERATOR_VERSION})"
apply_crds_from_url "${CLUSTER_OPERATOR_URL}" "cluster-operator"
apply_crds_from_url "${TOPOLOGY_OPERATOR_URL}" "messaging-topology-operator"

CRD_WAIT_TIMEOUT_S=180 wait_crd_established \
  crd/rabbitmqclusters.rabbitmq.com \
  crd/vhosts.rabbitmq.com \
  crd/exchanges.rabbitmq.com \
  crd/queues.rabbitmq.com \
  crd/bindings.rabbitmq.com \
  crd/users.rabbitmq.com \
  crd/permissions.rabbitmq.com \
  crd/topicpermissions.rabbitmq.com \
  crd/policies.rabbitmq.com \
  crd/operatorpolicies.rabbitmq.com \
  crd/federations.rabbitmq.com \
  crd/shovels.rabbitmq.com \
  crd/schemareplications.rabbitmq.com \
  crd/superstreams.rabbitmq.com

log "RabbitMQ operator CRDs ready"
