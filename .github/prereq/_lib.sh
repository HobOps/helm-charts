#!/usr/bin/env bash
# Shared helpers for Kind prereq install scripts.
set -euo pipefail

log() {
  printf '==> %s\n' "$*"
}

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

require_bins() {
  local missing=()
  local bin
  for bin in "$@"; do
    if ! command -v "${bin}" >/dev/null 2>&1; then
      missing+=("${bin}")
    fi
  done
  if ((${#missing[@]})); then
    die "missing required binary: ${missing[*]}"
  fi
}
