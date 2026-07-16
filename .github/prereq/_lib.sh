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

# Wait until CRD(s) are Established.
#
# Fresh CRDs often have status.conditions == nil for a short window after apply.
# kubectl wait does not retry that state — it fails immediately with:
#   .status.conditions accessor error: <nil> is of the type <nil>, expected []interface{}
# Retry until the field exists and Established is true.
wait_crd_established() {
  local timeout_s="${CRD_WAIT_TIMEOUT_S:-120}"
  local attempt_timeout_s=2
  local deadline attempt_end
  local -a crds=("$@")

  if ((${#crds[@]} == 0)); then
    die "wait_crd_established: no CRDs given"
  fi

  deadline=$((SECONDS + timeout_s))
  while ((SECONDS < deadline)); do
    if kubectl wait --for=condition=Established \
      --timeout="${attempt_timeout_s}s" \
      "${crds[@]}" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done

  # Final attempt without swallowing errors (clear failure message).
  attempt_end=$((deadline - SECONDS))
  if ((attempt_end < 1)); then
    attempt_end=1
  fi
  kubectl wait --for=condition=Established \
    --timeout="${attempt_end}s" \
    "${crds[@]}"
}
