#!/usr/bin/env bash
# Install the minimum Kind operators needed for common-library Kind CI.
#
# Flow:
#   1. Assert Kind StorageClass (local-path as "standard"; Kind ships this)
#   2. Gateway API CRDs (required for Traefik kubernetesGateway)
#   3. helmfile sync  — Traefik, cert-manager (+ future Helm operators)
#
# Usage:
#   ./.github/prereq/install-all.sh
#
# In GitHub Actions, prefer installing helmfile/Helm via
# mamezou-tech/setup-helmfile before calling this script. Locally, this script
# will download helmfile into a cache dir if it is not already on PATH.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PREREQ_DIR="${ROOT_DIR}/.github/prereq"

# shellcheck source=.github/prereq/_lib.sh
source "${PREREQ_DIR}/_lib.sh"

HELMFILE_VERSION="${HELMFILE_VERSION:-v1.7.0}"
HELMFILE_BIN="${HELMFILE_BIN:-}"
STORAGE_CLASS_NAME="${LOCAL_PATH_STORAGE_CLASS:-standard}"
PROVISIONER="${LOCAL_PATH_PROVISIONER:-rancher.io/local-path}"

ensure_helmfile() {
  if [[ -n "${HELMFILE_BIN}" && -x "${HELMFILE_BIN}" ]]; then
    return
  fi
  if command -v helmfile >/dev/null 2>&1; then
    HELMFILE_BIN="$(command -v helmfile)"
    return
  fi

  # Local/dev fallback only. CI should use mamezou-tech/setup-helmfile.
  local os arch asset cache_dir
  os="$(uname -s | tr '[:upper:]' '[:lower:]')"
  case "$(uname -m)" in
    x86_64 | amd64) arch="amd64" ;;
    arm64 | aarch64) arch="arm64" ;;
    *) die "unsupported architecture: $(uname -m)" ;;
  esac
  cache_dir="${HELMFILE_CACHE_DIR:-${HOME}/.cache/hobops-helmfile/${HELMFILE_VERSION}}"
  HELMFILE_BIN="${cache_dir}/helmfile"
  if [[ -x "${HELMFILE_BIN}" ]]; then
    return
  fi

  asset="helmfile_${HELMFILE_VERSION#v}_${os}_${arch}.tar.gz"
  mkdir -p "${cache_dir}"
  log "Downloading helmfile ${HELMFILE_VERSION} (${os}/${arch}) for local use"
  curl -fsSL "https://github.com/helmfile/helmfile/releases/download/${HELMFILE_VERSION}/${asset}" \
    -o "${cache_dir}/helmfile.tar.gz"
  tar -xzf "${cache_dir}/helmfile.tar.gz" -C "${cache_dir}" helmfile
  chmod +x "${HELMFILE_BIN}"
  rm -f "${cache_dir}/helmfile.tar.gz"
}

assert_kind_storage() {
  if ! kubectl get storageclass "${STORAGE_CLASS_NAME}" >/dev/null 2>&1; then
    die "StorageClass/${STORAGE_CLASS_NAME} missing (expected Kind local-path default)"
  fi
  local provisioner
  provisioner="$(kubectl get storageclass "${STORAGE_CLASS_NAME}" -o jsonpath='{.provisioner}')"
  if [[ "${provisioner}" != "${PROVISIONER}" ]]; then
    die "StorageClass/${STORAGE_CLASS_NAME} provisioner is ${provisioner} (want ${PROVISIONER})"
  fi
  log "Using Kind StorageClass/${STORAGE_CLASS_NAME} (${provisioner})"
}

require_bins kubectl helm curl

log "Installing Kind prereqs for common-library testing"
assert_kind_storage
"${PREREQ_DIR}/install-gateway-api-crds.sh"

ensure_helmfile
log "Syncing Helm operators via helmfile (${HELMFILE_BIN})"
(
  cd "${PREREQ_DIR}"
  "${HELMFILE_BIN}" sync
)

if ! kubectl get ingressclass traefik >/dev/null 2>&1; then
  die "IngressClass/traefik was not created"
fi
if ! kubectl get gatewayclass traefik >/dev/null 2>&1; then
  die "GatewayClass/traefik was not created (is providers.kubernetesGateway enabled?)"
fi
# Prefer CRD objects over api-resources (discovery cache can lag right after install).
if ! kubectl get crd certificates.cert-manager.io >/dev/null 2>&1; then
  die "cert-manager CRDs are not available"
fi

log "All Kind prereqs installed"
