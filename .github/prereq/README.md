# Kind prereq installers for common-library CI

Run against a Kind cluster (local or GitHub Actions `helm/kind-action`):

```bash
./.github/prereq/install-all.sh
```

This installs **CRDs + lightweight stubs only** — enough for the API server to
accept/reject chart fixtures (schema, CEL, unknown fields). Controllers
(Traefik, cert-manager, Argo CD, …) are **not** installed.

## What gets installed

1. Assert Kind StorageClass `standard` (local-path; already shipped by Kind)
2. Gateway API CRDs (standard channel)
3. cert-manager CRDs
4. `IngressClass/traefik` + `GatewayClass/traefik` stubs (no controller)

## Layout

| Path | Role |
|------|------|
| `install-all.sh` | Orchestrator |
| `install-gateway-api-crds.sh` | Gateway API CRDs |
| `install-cert-manager-crds.sh` | cert-manager CRDs |
| `install-stubs.sh` | IngressClass + GatewayClass stubs |
| `_lib.sh` | Shared bash helpers |

## Extending coverage

For new CRD groups (Argo CD, External Secrets, KEDA), add a CRDs-only installer
script and call it from `install-all.sh`. Do not add full operators unless you
intentionally want reconciliation e2e.

## Environment overrides

- `GATEWAY_API_VERSION` (default `v1.5.1`)
- `CERT_MANAGER_VERSION` (default `v1.17.2`)
- `INGRESS_CLASS_NAME` / `GATEWAY_CLASS_NAME` (default `traefik`)
- `LOCAL_PATH_STORAGE_CLASS` (default `standard`; assert only)

## Kubernetes version

Gateway API v1.5.x CRDs require Kubernetes **>= 1.31** (`isIP` CEL library and
`ValidatingAdmissionPolicy`). CI uses `helm/kind-action` v1.14.0 (kind v0.31 /
kubectl v1.35). Locally, create Kind with a matching node image, e.g.:

```bash
kind create cluster --name common-library-ci --image kindest/node:v1.32.2
```
