test_all:
	set -e; \
	for example in $(shell cd templates; ls *.yaml | grep -v '^_' ); do \
		echo "==> $$example"; \
		helm lint . -f examples/$$example --quiet; \
		helm template test-release . -f examples/$$example; \
	done

test:
	set -e; \
	helm lint . -f $(file) --quiet; \
	helm template test-release . -f $(file);

# Kind integration: install CI fixture and compare live objects to helm template.
# Requires a reachable cluster (e.g. kind) and kubectl/helm.
# Usage: make test_kind file=ci/Kubernetes_Deployment.yaml
RELEASE ?= common-library-ci
NAMESPACE ?= common-library-ci
RESOURCES ?= deployment/ci-deployment,service/ci-deployment

test_kind:
	set -e; \
	helm lint . -f $(file) --quiet; \
	helm upgrade --install $(RELEASE) . \
		--namespace $(NAMESPACE) --create-namespace \
		-f $(file) \
		--wait --timeout 2m; \
	../../scripts/compare-helm-vs-cluster.py \
		--chart . \
		--values $(file) \
		--release $(RELEASE) \
		--namespace $(NAMESPACE) \
		--resources $(RESOURCES)
