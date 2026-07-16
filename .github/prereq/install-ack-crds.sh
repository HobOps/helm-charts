#!/usr/bin/env bash
# Install ACK CRDs only (IAM Policy/Role, S3 Bucket, Secrets Manager Secret).
# Controllers are intentionally NOT installed.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck source=.github/prereq/_lib.sh
source "${ROOT_DIR}/.github/prereq/_lib.sh"

ACK_IAM_VERSION="${ACK_IAM_VERSION:-v1.7.3}"
ACK_S3_VERSION="${ACK_S3_VERSION:-v1.8.1}"
ACK_SECRETSMANAGER_VERSION="${ACK_SECRETSMANAGER_VERSION:-v1.3.2}"

IAM_BASE="https://raw.githubusercontent.com/aws-controllers-k8s/iam-controller/${ACK_IAM_VERSION}/helm/crds"
S3_BASE="https://raw.githubusercontent.com/aws-controllers-k8s/s3-controller/${ACK_S3_VERSION}/helm/crds"
SM_BASE="https://raw.githubusercontent.com/aws-controllers-k8s/secretsmanager-controller/${ACK_SECRETSMANAGER_VERSION}/helm/crds"

require_bins kubectl

if kubectl get crd policies.iam.services.k8s.aws >/dev/null 2>&1 \
  && kubectl get crd roles.iam.services.k8s.aws >/dev/null 2>&1 \
  && kubectl get crd buckets.s3.services.k8s.aws >/dev/null 2>&1 \
  && kubectl get crd secrets.secretsmanager.services.k8s.aws >/dev/null 2>&1; then
  log "ACK CRDs already present"
  exit 0
fi

log "Installing ACK CRDs (iam ${ACK_IAM_VERSION}, s3 ${ACK_S3_VERSION}, secretsmanager ${ACK_SECRETSMANAGER_VERSION})"
kubectl apply --server-side --force-conflicts \
  -f "${IAM_BASE}/iam.services.k8s.aws_policies.yaml" \
  -f "${IAM_BASE}/iam.services.k8s.aws_roles.yaml" \
  -f "${S3_BASE}/s3.services.k8s.aws_buckets.yaml" \
  -f "${SM_BASE}/secretsmanager.services.k8s.aws_secrets.yaml"

wait_crd_established \
  crd/policies.iam.services.k8s.aws \
  crd/roles.iam.services.k8s.aws \
  crd/buckets.s3.services.k8s.aws \
  crd/secrets.secretsmanager.services.k8s.aws

log "ACK CRDs ready"
