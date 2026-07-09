---
name: common-library-helm-testing
description: >-
  Test and update HobOps common-library Helm templates using examples/, ci/
  Kind fixtures, make test/test_all/test_kind, commitlint, branch/semver
  preflight, .github/prereq Kind operators, and
  common-library.yml. Use when changing charts/common-library, adding
  Kubernetes_ templates, Gateway API/Ingress resources, or verifying Kind CI
  for helm-charts.
---

# common-library Helm testing

Repo: `helm-charts`. Chart root: `charts/common-library`.

## When to use

- Adding or changing templates under `charts/common-library/templates/`
- Adding `examples/` or `ci/` fixtures
- Debugging `make test`, `make test_kind`, or `.github/workflows/common-library.yml`
- Preparing a `feat/` / `fix/` / `revert-*` PR that touches common-library

## Layout

| Path | Role |
|------|------|
| `templates/_*.yaml` | Helm `define` (library helpers) |
| `templates/*.yaml` (no `_`) | Wrappers that `range` over `.Values.<Kind>` |
| `examples/` | Full-feature values for `helm lint` + `helm template` |
| `ci/` | Kind-schedulable fixtures for install + template-vs-cluster compare |
| `.github/prereq/` | Kind bootstrap: Gateway API + cert-manager CRDs + class stubs |
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
- [ ] ./.github/prereq/install-all.sh (once per Kind cluster)
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

# Kind prereqs (once per cluster)
../../.github/prereq/install-all.sh

# Kind: apply ci fixture and compare (API-server acceptance, not reconciliation)
# Needs K8s >=1.31 for Gateway API v1.5.x CRDs (CI uses kind-action v1.14.0)
kind create cluster --name common-library-ci --image kindest/node:v1.32.2
kubectl config use-context kind-common-library-ci
make test_kind file=ci/Kubernetes_Deployment.yaml
make test_kind_all
```

`make test_kind` defaults:

- `RELEASE=common-library-ci`
- `NAMESPACE=common-library-ci`
- `RESOURCES=auto` (discovers kind/name from `helm template`)
- `WAIT_FLAGS=` empty (no `--wait`; controllers are not installed)

Do **not** run Kind tests against production kube contexts. Prefer `kind-common-library-ci`.

### Extending Kind coverage

1. Add `ci/<Prefix>_<Kind>.yaml` (minimal; include companion objects in the same file).
2. Prefer `RESOURCES=auto`; override only if you need a subset.
3. `make test_kind_all` / workflow already picks up new `ci/*.yaml` files.
4. For new CRD groups (Argo CD, ESO, KEDA): add a CRDs-only installer under `.github/prereq/` and call it from `install-all.sh`.

## Kind prereqs (CRDs + stubs)

| Piece | Covers | How |
|-------|--------|-----|
| Kind local-path | PVC / StorageClass `standard` | Shipped by Kind (assert only) |
| Gateway API CRDs | Gateway / GatewayClass / HTTPRoute types | `install-gateway-api-crds.sh` |
| cert-manager CRDs | Certificate / Issuer / ClusterIssuer | `install-cert-manager-crds.sh` |
| Class stubs | `IngressClass/traefik`, `GatewayClass/traefik` | `install-stubs.sh` (no Traefik) |

Orchestrator: `.github/prereq/install-all.sh`. Goal is API-server schema validation, not controller Ready.

Still need CRD installers later for Kind coverage of: Argo CD, External Secrets, KEDA.

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

## CI: common-library.yml

| Trigger | Jobs |
|---------|------|
| PR to `main` (`feat/` / `fix/` / `revert-*`) | `preflight` → `lint` → `kind-test` |
| Push to `main` (after merge) | `lint` → `publish` (GCS + GitHub Release) |

`kind-test` is PR-only (branch protection should require it). `publish` runs on main after `lint`.

| Job | What |
|-----|------|
| `preflight` | branch name, `commitlint --last`, chart semver |
| `lint` | `helm lint` + `make test_all` |
| `kind-test` | Kind + CRD/stub prereqs + `make test_kind_all` |
| `publish` | `publish_helm_charts.sh` (GCS) + `create_github_release.sh` |

Repo merge policy: **squash-and-merge only**. Commitlint intentionally checks only the tip commit.

## Known pitfalls

- Gateway API v1.5.x needs Kubernetes **>= 1.31** (`isIP` CEL + VAP). CI pins `helm/kind-action` v1.14.0; older kind (~1.29) fails CRD install with `undeclared reference to 'isIP'` / missing `ValidatingAdmissionPolicy`.
- Empty `nodePort:` on Service breaks Kind apply—omit the field when unset.
- Role / RoleBinding must set `metadata.namespace` to the release namespace.
- `make test_all` iterates non-`_` templates; orphan `examples/` without a matching wrapper are not run and can hide gaps.
- Compare script strips API defaults (uid, status, helm labels, ClusterIP, PVC/cert-manager annotations, etc.); if diffs are noisy, extend normalization in `scripts/compare-helm-vs-cluster.py`, don’t weaken the fixture.
- PVC fixtures may stay Pending without a scheduled consumer; that is fine for apply/compare. `test_kind` deletes the namespace between fixtures to clear PVC finalizers.
- Without controllers, Certificate/Ingress/Gateway will not become Ready; Kind CI only asserts apply + template-vs-cluster compare.
- After Kind tests, restore kubectl context if needed: `kubectl config use-context <prod-context>`.

## Done criteria

- `make test_all` passes
- New/changed Kind fixtures: `make test_kind` OK (with prereqs installed)
- Semver bumped when chart files change
- Tip commit passes `npx commitlint --last`
- PR from allowed branch prefix; CI `preflight` + `lint` + `kind-test` green
- After merge to `main`: GCS publish + GitHub Release tag `common-library-v<Chart.yaml version>`
