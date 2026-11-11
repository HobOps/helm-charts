#!/usr/bin/env bash
# Install CloudNativePG operator + barman-cloud plugin CRDs only.
#
# The operator, the plugin and their webhooks are NOT installed. The release
# manifests are filtered to CustomResourceDefinition documents so Kind CI can
# validate chart fixtures (Cluster, Database, ScheduledBackup, Pooler,
# ObjectStore) against the real OpenAPI schemas.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=.github/prereq/_lib.sh
source "${ROOT_DIR}/.github/prereq/_lib.sh"

CNPG_VERSION="${CNPG_VERSION:-1.30.1}"
BARMAN_CLOUD_PLUGIN_VERSION="${BARMAN_CLOUD_PLUGIN_VERSION:-v0.15.1}"

CNPG_URL="${CNPG_URL:-https://github.com/cloudnative-pg/cloudnative-pg/releases/download/v${CNPG_VERSION}/cnpg-${CNPG_VERSION}.yaml}"
BARMAN_CLOUD_PLUGIN_URL="${BARMAN_CLOUD_PLUGIN_URL:-https://github.com/cloudnative-pg/plugin-barman-cloud/releases/download/${BARMAN_CLOUD_PLUGIN_VERSION}/manifest.yaml}"

CNPG_CRDS=(
  crd/clusters.postgresql.cnpg.io
  crd/databases.postgresql.cnpg.io
  crd/scheduledbackups.postgresql.cnpg.io
  crd/poolers.postgresql.cnpg.io
  crd/objectstores.barmancloud.cnpg.io
)

require_bins kubectl python3 curl

apply_crds_from_url() {
  local url="$1"
  local label="$2"
  local tmp
  tmp="$(mktemp)"
  # Filter multi-doc YAML to CRDs only (stdlib Python; no PyYAML required).
  # Split on document separator lines only: CRD descriptions contain "----".
  curl -fsSL "${url}" | python3 -c '
import re
import sys
docs = re.split(r"(?m)^---[ \t]*$", sys.stdin.read())
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

missing=0
for crd in "${CNPG_CRDS[@]}"; do
  if ! kubectl get "${crd}" >/dev/null 2>&1; then
    missing=1
  fi
done
if ((missing == 0)); then
  log "CloudNativePG and barman-cloud CRDs already present"
  exit 0
fi

log "Installing CloudNativePG CRDs (operator ${CNPG_VERSION}, barman-cloud plugin ${BARMAN_CLOUD_PLUGIN_VERSION})"
apply_crds_from_url "${CNPG_URL}" "cloudnative-pg"
apply_crds_from_url "${BARMAN_CLOUD_PLUGIN_URL}" "plugin-barman-cloud"

CRD_WAIT_TIMEOUT_S=180 wait_crd_established "${CNPG_CRDS[@]}"

log "CloudNativePG and barman-cloud CRDs ready"
