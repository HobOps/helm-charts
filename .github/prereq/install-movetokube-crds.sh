#!/usr/bin/env bash
# Install Movetokube postgres-operator CRDs only (Postgres, PostgresUser).
# Controllers are intentionally NOT installed.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=.github/prereq/_lib.sh
source "${ROOT_DIR}/.github/prereq/_lib.sh"

# Tags are unprefixed (e.g. 2.4.0) or helm-chart style (ext-postgres-operator-3.0.0).
MOVETOKUBE_VERSION="${MOVETOKUBE_VERSION:-ext-postgres-operator-3.0.0}"
MOVETOKUBE_CRD_BASE="${MOVETOKUBE_CRD_BASE:-https://raw.githubusercontent.com/movetokube/postgres-operator/${MOVETOKUBE_VERSION}/config/crd/bases}"

require_bins kubectl

if kubectl get crd postgres.db.movetokube.com >/dev/null 2>&1 \
  && kubectl get crd postgresusers.db.movetokube.com >/dev/null 2>&1; then
  log "Movetokube CRDs already present"
  exit 0
fi

log "Installing Movetokube CRDs (${MOVETOKUBE_VERSION})"
kubectl apply --server-side --force-conflicts \
  -f "${MOVETOKUBE_CRD_BASE}/db.movetokube.com_postgres.yaml" \
  -f "${MOVETOKUBE_CRD_BASE}/db.movetokube.com_postgresusers.yaml"

wait_crd_established \
  crd/postgres.db.movetokube.com \
  crd/postgresusers.db.movetokube.com

log "Movetokube CRDs ready"
