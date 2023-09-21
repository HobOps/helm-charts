# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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