# Kind prereq installers for common-library CI
#
# Run against a Kind cluster (local or GitHub Actions `helm/kind-action`):
#
#   ./.github/prereq/install-all.sh
#
# In CI, install tools first with `mamezou-tech/setup-helmfile` (helmfile + Helm),
# then call this script. Locally, `install-all.sh` downloads helmfile if missing.
#
# This installs:
#   1. Assert Kind StorageClass `standard` (local-path; already shipped by Kind)
#   2. Gateway API CRDs (standard channel; required by Traefik kubernetesGateway)
#   3. Helm operators via [helmfile.yaml](helmfile.yaml) (`helmfile sync`)
#
# ## Layout
#
# | Path | Role |
# |------|------|
# | `install-all.sh` | Orchestrator (storage assert + Gateway CRDs + helmfile) |
# | `install-gateway-api-crds.sh` | Gateway API CRDs (kubectl apply) |
# | `helmfile.yaml` | Declared Helm releases (Traefik, cert-manager, …) |
# | `values/<release>.yaml` | Per-release chart values |
# | `_lib.sh` | Shared bash helpers |
#
# ## Minimum operators
#
# | Operator | Why | How |
# |----------|-----|-----|
# | **Kind local-path** | PVC / StorageClass (`standard`) | Provided by Kind (assert only) |
# | **Gateway API CRDs** | Gateway / GatewayClass / HTTPRoute types | `install-gateway-api-crds.sh` |
# | **Traefik** | IngressClass + Gateway API controller | helmfile release `traefik` |
# | **cert-manager** | Certificate / Issuer / ClusterIssuer | helmfile release `cert-manager` |
#
# ## Adding another operator later
#
# 1. Add the chart repo under `repositories:` in `helmfile.yaml` (if needed).
# 2. Add a `releases:` entry with pinned `version` and `labels`.
# 3. Add `values/<name>.yaml` with Kind-friendly settings (no LoadBalancer if avoidable).
# 4. Re-run `./.github/prereq/install-all.sh` (or `helmfile -f .github/prereq/helmfile.yaml sync`).
#
# Candidates not yet declared: Argo CD, External Secrets, KEDA.
#
# ## Direct helmfile usage
#
# ```bash
# cd .github/prereq
# helmfile sync                 # install/upgrade all releases
# helmfile list                 # show releases
# helmfile destroy              # tear down Helm releases
# helmfile -l component=ingress sync
# ```
#
# ## Environment overrides
#
# - `HELMFILE_VERSION` — helmfile binary to download if missing (default `v1.7.0`)
# - `HELMFILE_BIN` — path to an existing helmfile binary
# - `HELMFILE_CACHE_DIR` — download cache (default `~/.cache/hobops-helmfile/<version>`)
# - `LOCAL_PATH_STORAGE_CLASS` (default `standard`; assert only)
# - `GATEWAY_API_VERSION` (default `v1.5.1`)
# - Chart versions: edit `helmfile.yaml` (pinned for reproducible CI)
#
# ## Kubernetes version
#
# Gateway API v1.5.x CRDs require Kubernetes **>= 1.31** (`isIP` CEL library and
# `ValidatingAdmissionPolicy`). CI uses `helm/kind-action` v1.14.0 (kind v0.31 /
# kubectl v1.35). Locally, create Kind with a matching node image, e.g.:
#
#   kind create cluster --name common-library-ci --image kindest/node:v1.32.2
