#!/usr/bin/env bash
# Package and publish Helm charts to the GCS repo (gs://hobops-helm-charts).
# Default: only common-library. Override with CHARTS="chart1 chart2".
set -euo pipefail

CHARTS_PATH="${CHARTS_PATH:-charts}"
CHARTS="${CHARTS:-common-library}"
RELEASE_PATH="$(mktemp -d)"
trap 'rm -rf "${RELEASE_PATH}"' EXIT

echo "==> Syncing existing chart repo into ${RELEASE_PATH}"
gsutil -m rsync "gs://hobops-helm-charts/" "${RELEASE_PATH}/"

for chart in ${CHARTS}; do
  chart_dir="${CHARTS_PATH}/${chart}"
  if [[ ! -f "${chart_dir}/Chart.yaml" ]]; then
    echo "ERROR: missing Chart.yaml in ${chart_dir}" >&2
    exit 1
  fi
  echo "==> Packaging ${chart_dir}"
  helm package -u "${chart_dir}" -d "${RELEASE_PATH}"
done

echo "==> Rebuilding index.yaml"
helm repo index "${RELEASE_PATH}"

echo "==> Uploading packages and index"
# shellcheck disable=SC2086
gsutil cp ${RELEASE_PATH}/*.tgz gs://hobops-helm-charts/
gsutil -h "Content-Type:text/html" -h "Cache-Control:public, max-age=0" \
  cp "${RELEASE_PATH}/index.yaml" gs://hobops-helm-charts/index.yaml

echo "==> Publish complete (${CHARTS})"
