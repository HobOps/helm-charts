#!/bin/bash
set -e
export CHARTS_PATH="charts"
export CHART_NAME="common-library"
export TEST_VALUES="test-values.yaml"
export RELEASE_NAME="test-release"
helm template --debug ${RELEASE_NAME} ${CHARTS_PATH}/${CHART_NAME} --values ${CHARTS_PATH}/${CHART_NAME}/${TEST_VALUES}