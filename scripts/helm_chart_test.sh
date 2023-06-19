#!/bin/bash
set -e
CHART=$1
EXAMPLE_VALUES=$2
if [ -z "$CHART" ]; then
  echo "CHART is not set"
  exit 1
fi
if [ -z "$EXAMPLE_VALUES" ]; then
  echo "EXAMPLE_VALUES is not set"
  exit 1
fi

helm lint ${CHART} -f ${EXAMPLE_VALUES}
helm template test-release ${CHART} -f ${EXAMPLE_VALUES}