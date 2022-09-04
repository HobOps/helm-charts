#!/bin/bash
set -e
ct lint --lint-conf scripts/lintconf.yaml --target-branch main --check-version-increment --all