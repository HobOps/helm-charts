# common-library

Helm template library for HobOps charts.

## Contributing

### Workflow

1. Create a branch: `feat/<name>`, `fix/<name>`, or use GitHub’s `revert-<pr>-…` when reverting.
2. Make your changes under `charts/common-library/`.
3. If you change the chart, bump `version` / `appVersion` in [`Chart.yaml`](Chart.yaml) and add an entry in [`CHANGELOG.md`](CHANGELOG.md).
4. Commit with [Conventional Commits](https://www.conventionalcommits.org/) (enforced by [commitlint](https://commitlint.js.org/)), for example:
   - `feat: add Kubernetes HTTPRoute template`
   - `fix: omit empty nodePort on Service`
   - `chore: update common-library README`
5. Run tests locally (see [Testing](#testing)).
6. Open a PR to `main` (squash-and-merge only; commitlint checks the latest commit).

### Adding a template

1. Add the define in `templates/_Kubernetes_<Kind>.yaml` (or the matching prefix for the API family).
2. Add the wrapper `templates/Kubernetes_<Kind>.yaml` that ranges over `.Values.<Kind>`.
3. Add a matching `examples/Kubernetes_<Kind>.yaml` (required for `make test_all`).
4. For Kind-schedulable coverage, add a minimal fixture under `ci/` and wire it into CI when ready.
5. Default empty maps in [`values.yaml`](values.yaml) when introducing a new values key.
6. Bump the chart version and update the changelog.

### Branch, commit, and version rules

| Rule | Expectation |
|------|-------------|
| Branch | `feat/<name>`, `fix/<name>`, `revert-<pr>-<name>`, or `main` |
| Commit | Conventional Commits via commitlint on the **latest commit** (`feat:`, `fix:`, `chore:`, …) |
| Merge | Squash-and-merge only |
| Version | If `charts/common-library/**` changes, `Chart.yaml` `version` must increase |

Install local hooks from the **repo root**:

```bash
pip install pre-commit
pre-commit install --install-hooks
pre-commit install --hook-type commit-msg
pre-commit install --hook-type pre-push
```

## Testing

When adding a new template, create a matching example file in `examples/` (same basename as the non-`_` wrapper under `templates/`). Otherwise `make test_all` will fail.

| Directory | Purpose |
|-----------|---------|
| `examples/` | Full-feature values for `helm lint` / `helm template` unit checks |
| `ci/` | Kind-schedulable fixtures for install + template-vs-cluster comparison |

### Unit tests (examples)

```bash
# All templates
make test_all

# Single example
make test file=examples/Kubernetes_Deployment.yaml
```

### Kind integration (ci)

Requires a reachable Kubernetes cluster (`kubectl` context), Helm, and Kind prereqs
([`.github/prereq`](../../.github/prereq)): Gateway API CRDs, cert-manager CRDs, and
IngressClass/GatewayClass stubs (no controllers).

```bash
# Create a local Kind cluster (once; needs K8s >= 1.31 for Gateway API v1.5.x)
kind create cluster --name common-library-ci --image kindest/node:v1.32.2
kubectl config use-context kind-common-library-ci

# Install CRDs + class stubs (once per cluster)
../../.github/prereq/install-all.sh

# Apply a CI fixture (or all) and assert live objects match helm template
make test_kind file=ci/Kubernetes_Deployment.yaml
make test_kind_all
```

`make test_kind` runs `helm upgrade --install` (no `--wait`), then
[`scripts/compare-helm-vs-cluster.py`](../../scripts/compare-helm-vs-cluster.py) to
normalize and diff rendered objects.

## CI / release

GitHub Actions workflow: [`.github/workflows/common-library.yml`](../../.github/workflows/common-library.yml).

- **Pull request**: branch name, commitlint, semver, `make test_all`, Kind tests.
- **Push to `main`**: `lint` then publish to GCS and create GitHub Release tag `common-library-v<version>`.

## Changelog

See [CHANGELOG.md](CHANGELOG.md).

## Notes (v1.8+)

### ExternalSecret `target.template`

`target.template` is rendered with `toYaml` (no Helm `tpl`) so External Secrets
Operator placeholders like `{{ .RABBITMQ_USER }}` are preserved. Other fields
(`secretStoreRef`, `data`, `dataFrom`, `target.name`) still support Helm `tpl`.

### RabbitMQ operators

Values keys (`rabbitmq.com`):

- Cluster: `RabbitmqCluster` (`v1beta1`)
- Topology: `Vhost`, `Exchange`, `Queue`, `Binding`, `User`, `Permission`,
  `TopicPermission`, `Policy`, `OperatorPolicy`, `Federation`, `Shovel`,
  `SchemaReplication` (`v1beta1`), `SuperStream` (`v1alpha1`)

Spec fields are passed through (same pattern as PrometheusRule). Controllers
are not part of this chart — install Cluster + Messaging Topology operators
separately.

### CloudNativePG and barman-cloud

Values keys:

| Values key | Kind | apiVersion (default) |
|------------|------|----------------------|
| `CNPGCluster` | `Cluster` | `postgresql.cnpg.io/v1` |
| `CNPGDatabase` | `Database` | `postgresql.cnpg.io/v1` |
| `CNPGScheduledBackup` | `ScheduledBackup` | `postgresql.cnpg.io/v1` |
| `CNPGPooler` | `Pooler` | `postgresql.cnpg.io/v1` |
| `BarmanCloudObjectStore` | `ObjectStore` | `barmancloud.cnpg.io/v1` |

The values keys are prefixed instead of using the bare kind (as most other
templates do) because `Cluster`, `Database` or `ObjectStore` are too generic to
own a top-level values key.

All of them are namespaced (`.Release.Namespace`) and follow the generic
pattern: every key other than `annotations` / `labels` / `apiVersion` is
rendered as the spec, through Helm `tpl` (like the RabbitMQ templates, unlike
ExternalSecret `target.template`). CloudNativePG specs have no operator
placeholders; if a field must contain a literal `{{` (e.g. in
`bootstrap.initdb.postInitSQL`), escape it as `{{ "{{" }}`.

Backups use the barman-cloud plugin (CNPG-I), not the deprecated in-tree
`barmanObjectStore`: an `ObjectStore`, a `plugins` entry in the Cluster with
`name: barman-cloud.cloudnative-pg.io`, `isWALArchiver: true` and
`parameters.barmanObjectName: <ObjectStore name>`, and ScheduledBackups with
`method: plugin`. The CloudNativePG operator and the plugin are not part of
this chart — install them separately.
