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
([`.github/prereq`](../../.github/prereq)): Kind local-path (built-in) + helmfile releases (Traefik, cert-manager) + Gateway API CRDs.

```bash
# Create a local Kind cluster (once)
kind create cluster --name common-library-ci
kubectl config use-context kind-common-library-ci

# Install minimum operators (once per cluster; downloads helmfile if missing)
../../.github/prereq/install-all.sh

# Install a CI fixture (or all) and assert live objects match helm template
make test_kind file=ci/Kubernetes_Deployment.yaml
make test_kind_all
```

`make test_kind` runs `helm upgrade --install`, then [`scripts/compare-helm-vs-cluster.py`](../../scripts/compare-helm-vs-cluster.py) to normalize and diff rendered objects.

## CI / release

GitHub Actions workflow: [`.github/workflows/common-library.yml`](../../.github/workflows/common-library.yml).

- **Pull request** (`feat/` / `fix/` / `revert-*`): branch name, commitlint, semver, `make test_all`, Kind tests.
- **Push to `main`**: re-run lint + Kind tests; if they pass, publish to GCS and create GitHub Release tag `common-library-v<version>`.

## Changelog

See [CHANGELOG.md](CHANGELOG.md).
