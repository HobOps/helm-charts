#!/usr/bin/env bash
# Create a GitHub Release + tag for a chart from Chart.yaml.
# Usage: ./scripts/create_github_release.sh common-library
# Tag format: <chart>-v<version>  (e.g. common-library-v1.3.1)
set -euo pipefail

CHART="${1:-common-library}"
CHART_DIR="charts/${CHART}"
CHART_YAML="${CHART_DIR}/Chart.yaml"
CHANGELOG="${CHART_DIR}/CHANGELOG.md"

if [[ ! -f "${CHART_YAML}" ]]; then
  echo "ERROR: ${CHART_YAML} not found" >&2
  exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "ERROR: gh CLI is required" >&2
  exit 1
fi

VERSION="$(
  awk -F': *' '/^version:/ { gsub(/["'\'' ]/, "", $2); print $2; exit }' "${CHART_YAML}"
)"
if [[ -z "${VERSION}" ]]; then
  echo "ERROR: version not found in ${CHART_YAML}" >&2
  exit 1
fi

TAG="${CHART}-v${VERSION}"
PACKAGE="${CHART}-${VERSION}.tgz"

TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT
helm package -u "${CHART_DIR}" -d "${TMP}"
PACKAGE_PATH="${TMP}/${PACKAGE}"

if [[ ! -f "${PACKAGE_PATH}" ]]; then
  echo "ERROR: expected package ${PACKAGE_PATH}" >&2
  exit 1
fi

if gh release view "${TAG}" >/dev/null 2>&1; then
  echo "ERROR: GitHub release ${TAG} already exists (bump Chart.yaml version)" >&2
  exit 1
fi

NOTES_FILE="${TMP}/notes.md"
python3 - "${CHANGELOG}" "${VERSION}" "${NOTES_FILE}" "${CHART}" <<'PY'
import sys
from pathlib import Path

changelog = Path(sys.argv[1])
version = sys.argv[2]
out = Path(sys.argv[3])
chart = sys.argv[4]
if not changelog.exists():
    out.write_text(f"Release {version} of {chart}.\n")
    raise SystemExit(0)

lines = changelog.read_text().splitlines()
section = []
capture = False
header = f"## [{version}]"
for line in lines:
    if line.startswith("## ["):
        if capture:
            break
        if line.startswith(header):
            capture = True
            section.append(line)
            continue
    elif capture:
        section.append(line)
if not section:
    section = [f"## [{version}]", "", f"Release {version} of {chart}."]
out.write_text("\n".join(section).rstrip() + "\n")
PY

echo "==> Creating GitHub release ${TAG}"
gh release create "${TAG}" "${PACKAGE_PATH}" \
  --title "${CHART} ${VERSION}" \
  --notes-file "${NOTES_FILE}"

echo "==> Release ${TAG} created"
