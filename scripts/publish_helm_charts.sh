#!/bin/bash
set -e
# https://helm.sh/docs/topics/chart_repository/
export CHARTS_PATH="charts"
export RELEASE_PATH="$(mktemp -d)"
for CHART in $(ls $CHARTS_PATH); do
  helm package -u ${CHARTS_PATH}/${CHART} -d ${RELEASE_PATH};
done
helm repo index ${RELEASE_PATH}
gsutil cp "${RELEASE_PATH}/*.tgz" gs://hobops-helm-charts/
gsutil -h "Content-Type:text/html" -h "Cache-Control:public, max-age=0" cp "${RELEASE_PATH}/index.yaml" gs://hobops-helm-charts/index.yaml
rm -rf ${RELEASE_PATH}