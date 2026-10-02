# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.9.0] - 2026-10-02

Rendered output changes for existing releases: Service `labels` and
`loadBalancerSourceRanges` are now emitted, and fields no longer leak between
Services. No values keys were renamed or removed.

### Added
- Service: `ipFamilyPolicy`, `ipFamilies`, `loadBalancerClass` and
  `allocateLoadBalancerNodePorts`, for dual-stack Services and LoadBalancer
  implementations such as Cilium LB IPAM / BGP.
- NetworkPolicy: `labels`.

### Fixed
- Service: per-service values are now read into template locals instead of being
  stored in `.Values`, so fields no longer leak from one Service into the next one
  in the same release (e.g. `loadBalancerIP`, `sessionAffinityConfig`, `type`,
  annotations). Applies to standalone Services and to Workload services.
- Service: `labels` (and Workload `serviceLabels`) were computed but never
  rendered; they are now emitted under `metadata.labels`.
- Service: `loadBalancerSourceRanges` is now rendered (it was accepted in values
  but ignored).
- NetworkPolicy: `egress` rules are now rendered (only `ingress` was supported).
- NetworkPolicy: an empty or missing `podSelector` is rendered as `podSelector: {}`
  (selects every pod; required for default-deny policies) instead of being omitted.

## [1.8.0] - 2026-08-29

### Added
- RabbitMQ Cluster Operator template: `RabbitmqCluster` (`rabbitmq.com/v1beta1`)
- RabbitMQ Messaging Topology Operator templates (`rabbitmq.com`):
  `Vhost`, `Exchange`, `Queue`, `Binding`, `User`, `Permission`,
  `TopicPermission`, `Policy`, `OperatorPolicy`, `Federation`, `Shovel`,
  `SchemaReplication` (`v1beta1`), and `SuperStream` (`v1alpha1`)
- Kind CI CRD installers + fixtures for RabbitMQ operator resources

### Fixed
- ExternalSecret: do not run Helm `tpl` on `target.template` so External Secrets
  Operator placeholders (`{{ .KEY }}`) survive rendering (e.g. credential
  remapping / `default_user.conf` for RabbitmqCluster)

## [1.7.0] - 2026-07-29

### Added
- Prometheus Operator templates (`monitoring.coreos.com`): ServiceMonitor,
  PodMonitor, Probe, PrometheusRule, Prometheus, Alertmanager, ThanosRuler,
  PrometheusAgent, ScrapeConfig, AlertmanagerConfig
- Kind CI CRDs + fixtures for Prometheus Operator resources

## [1.6.0] - 2026-07-16

### Added
- Kubernetes Namespace template
- Kubernetes PodDisruptionBudget template
- Movetokube Postgres and PostgresUser templates (`db.movetokube.com`)
- ACK IAM Role and IAM Policy templates (`iam.services.k8s.aws`)
- ACK Secrets Manager Secret template (`secretsmanager.services.k8s.aws`)
- ACK S3 Bucket template (`s3.services.k8s.aws`) for ActiveStorage / app buckets
- Istio VirtualService template (`networking.istio.io/v1`)
- Kind CI CRDs + fixtures for ACK, Istio, and Movetokube resources

### Changed
- Kubernetes Deployment: import common-library-v2 fields — `revisionHistoryLimit`,
  `terminationGracePeriodSeconds`, `topologySpreadConstraints`, `containerName`,
  `lifecycle`, and `tpl` on image repository/tag/pullPolicy
- Kubernetes Job: import common-library-v2 fields — `containerName` and `tpl` on image fields
- Kubernetes StatefulSet: optional `serviceName` / `containerName`, and `tpl` on image fields
- Kubernetes HorizontalPodAutoscaler: support optional `behavior` (scaleUp/scaleDown)
- Kind compare script: use `Kind.group/name` refs so ACK Role/Secret do not collide with RBAC/core
- IngressClass/GatewayClass stub installer is idempotent when stubs already exist

## [1.4.0] - 2026-07-09

### Added
- Kubernetes CronJob template (parity with Job pod/job fields: schedule, concurrency, suspend, history limits)
- Kind CI fixtures for CronJob, Gateway, GatewayClass, and HTTPRoute
- Kind CI CRDs + fixtures for Argo CD, External Secrets, and KEDA

### Fixed
- ExternalSecrets: bump API versions for ESO v2.x (`v1` for SecretStore/ExternalSecret/Cluster*; `v1alpha1` for PushSecret)
- ExternalSecrets SecretStore/ClusterSecretStore: omit empty `controller` (null fails OpenAPI)
- ExternalSecrets PushSecret: render `secretStoreRefs` / `selector` / `remoteRef` (schema-compatible with ESO v2.x)
- Keda ScaledJob: omit empty optional fields (`envSourceContainerName`, history limits, etc.)

## [1.3.2] - 2026-07-09

### Changed
- Kind CI validates API-server acceptance only: CRDs + IngressClass/GatewayClass stubs (no Traefik/cert-manager controllers)
- `make test_kind` no longer waits for controllers (`WAIT_FLAGS` empty by default)
- Removed unused helmfile operator bootstrap from `.github/prereq`

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
