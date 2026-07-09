# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.3.2] - 2026-07-09

### Changed
- Kind CI validates API-server acceptance only: CRDs + IngressClass/GatewayClass stubs (no Traefik/cert-manager controllers)
- `make test_kind` no longer waits for controllers (`WAIT_FLAGS` empty by default)

## [1.3.1] - 2026-07-08

### Fixed
- Kubernetes Service: omit empty `nodePort` so ClusterIP Services are valid for cluster apply
- Kubernetes Role / RoleBinding: set `metadata.namespace` to the release namespace
- CertManager ClusterIssuer: render `selfSigned` as a YAML object (empty `{}` was dropped by Helm `with`)

### Added
- `ci/` Kind fixtures and `make test_kind` / `make test_kind_all` for template-vs-cluster comparison
- `--resources auto` discovery in `compare-helm-vs-cluster.py`
- `.github/prereq` Kind operator bootstrap: Gateway API CRDs + helmfile (Traefik with Gateway API, cert-manager); relies on Kind’s built-in local-path StorageClass
- Unified `.github/workflows/common-library.yml`: PR CI (preflight/lint/Kind) and main publish (GCS + GitHub Release `common-library-vX.Y.Z`)

## [1.3.0] - 2026-07-08

### Added
- Templates for:
  - Kubernetes Gateway
  - Kubernetes GatewayClass
  - Kubernetes HTTPRoute (native spec only; unlike Ingress, HTTPRoute hostnames apply to all rules without duplication)

## [0.2.0] - 2023-09-20
### Added
- Templates for:
  - CertManager Certificate
  - CertManager Issuer
  - Kubernetes ClusterRole
  - Kubernetes ClusterRoleBinding
  - Kubernetes Role
  - Kubernetes RoleBinding
  - Kubernetes Service Account

### Changed
- Modified templates:
  - Kubernetes Job
- Breaking change: Updated the `acme` field in the `ClusterIssuer` template to match the style of other fields.
  This change requires updates to any existing configurations that use the `ClusterIssuer` template. Please see the
  file `examples/CertManager_ClusterIssuer.yaml` for an example of the new format.

### Changed
- Disabled CronJob template
