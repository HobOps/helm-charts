---
name: common-library-helm-testing
description: >-
  Test and update HobOps common-library Helm templates using examples/, ci/
  Kind fixtures, make test/test_all/test_kind, commitlint, branch/semver
  preflight, and helm-chart-testing.yml. Use when changing
  charts/common-library, adding Kubernetes_ templates, Gateway API/Ingress
  resources, or verifying Kind CI for helm-charts.
---

# common-library Helm testing

Repo: `helm-charts`. Chart root: `charts/common-library`.

## When to use

- Adding or changing templates under `charts/common-library/templates/`
- Adding `examples/` or `ci/` fixtures
- Debugging `make test`, `make test_kind`, or `.github/workflows/helm-chart-testing.yml`
- Preparing a `feat/` / `fix/` / `revert-*` PR that touches common-library

## Layout

| Path | Role |
|------|------|
| `templates/_*.yaml` | Helm `define` (library helpers) |
| `templates/*.yaml` (no `_`) | Wrappers that `range` over `.Values.<Kind>` |
| `examples/` | Full-feature values for `helm lint` + `helm template` |
| `ci/` | Kind-schedulable fixtures for install + template-vs-cluster compare |
| `scripts/compare-helm-vs-cluster.py` | Normalize and diff live objects vs `helm template` |
| `scripts/check-branch-name.sh` | `feat/` \| `fix/` \| `revert-<pr>-*` \| `main` |
| `scripts/check-chart-semver.py` | Require Chart.yaml bump when chart changes |
| `commitlint.config.js` | Conventional Commits; CI uses `--last` only |

`examples/` may include nodeSelectors, missing secrets, etc. `ci/` must schedule on Kind (no blocking affinity/pullSecrets; include companion ConfigMap/Secret in the same values file if referenced).

## Update a template (checklist)

```
- [ ] Branch: feat/<name> or fix/<name>
- [ ] Edit _define + wrapper (same basename)
- [ ] Matching examples/<SameName>.yaml
- [ ] Optional ci/<SameName>.yaml if Kind coverage needed
- [ ] values.yaml empty key for new Values.<Kind>
- [ ] Chart.yaml version + appVersion bump
- [ ] CHANGELOG.md entry
- [ ] make test / make test_all
- [ ] make test_kind (if ci/ fixture exists)
- [ ] Preflight scripts locally
- [ ] Conventional commit; squash-merge PR
```

### Naming

- Native K8s / Gateway API: `Kubernetes_<Kind>.yaml` → `library.Kubernetes.<Kind>`
- Values key matches kind map name: `Deployment:`, `HTTPRoute:`, `Gateway:`, …
- Wrapper pattern:

```yaml
{{ range $name, $data := .Values.<Kind> }}
  {{ include "library.Kubernetes.<Kind>" (dict "name" $name "data" $data "Release" $.Release "Values" $.Values "Template" $.Template ) }}
{{ end }}
```

Prefer native spec passthrough (`with` + `toYaml` + `tpl`) unless a fan-out helper is clearly needed (Ingress-style host duplication). HTTPRoute does **not** need Ingress `render_*` helpers—`hostnames` apply to all rules.

## Local tests

Run from `charts/common-library`:

```bash
# Single example (unit)
make test file=examples/Kubernetes_Deployment.yaml

# All wrappers must have matching examples/
make test_all

# Kind: install ci fixture and compare Deployment+Service
kind create cluster --name common-library-ci   # once
kubectl config use-context kind-common-library-ci
make test_kind file=ci/Kubernetes_Deployment.yaml
```

`make test_kind` defaults:

- `RELEASE=common-library-ci`
- `NAMESPACE=common-library-ci`
- `RESOURCES=deployment/ci-deployment,service/ci-deployment`

Override `RESOURCES` when adding new Kind fixtures.

Do **not** run Kind tests against production kube contexts. Prefer `kind-common-library-ci`.

### Extending Kind coverage

1. Add `ci/Kubernetes_<Kind>.yaml` (minimal, schedulable).
2. Extend Makefile `RESOURCES` or pass `RESOURCES=...` for that fixture.
3. Wire additional `make test_kind` invocations in `.github/workflows/helm-chart-testing.yml` `kind-test` job (today: Deployment only).

## Preflight (repo root)

```bash
./scripts/check-branch-name.sh feat/your-branch
./scripts/check-chart-semver.py --local origin/main
npm ci && npx commitlint --last --verbose
```

Pre-commit (optional):

```bash
pre-commit install --install-hooks
pre-commit install --hook-type commit-msg
pre-commit install --hook-type pre-push
```

## CI: helm-chart-testing.yml

Triggers on paths under `charts/common-library/**` and related scripts/config; PRs to `main` when head is `feat/`, `fix/`, or `revert-`; also `push` to `main` and `workflow_dispatch`.

| Job | What |
|-----|------|
| `preflight` | branch name (PRs), `commitlint --last`, chart semver |
| `kind-test` | Kind cluster + `make test_kind file=ci/Kubernetes_Deployment.yaml` |

Repo merge policy: **squash-and-merge only**. Commitlint intentionally checks only the tip commit.

## Known pitfalls

- Empty `nodePort:` on Service breaks Kind apply—omit the field when unset.
- `make test_all` iterates non-`_` templates; orphan `examples/` (e.g. disabled CronJob) are not run and can hide gaps.
- Compare script strips API defaults (uid, status, helm labels, ClusterIP, default probes paths, etc.); if diffs are noisy, extend normalization in `scripts/compare-helm-vs-cluster.py`, don’t weaken the fixture.
- After Kind tests, restore kubectl context if needed: `kubectl config use-context <prod-context>`.

## Done criteria

- `make test_all` passes
- New/changed Kind fixtures: `make test_kind` OK
- Semver bumped when chart files change
- Tip commit passes `npx commitlint --last`
- PR from allowed branch prefix; CI `preflight` + `kind-test` green
