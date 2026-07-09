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
# Requires Kind prereqs (see .github/prereq/install-all.sh): Traefik, cert-manager, Gateway API CRDs.
# Usage:
#   make test_kind file=ci/Kubernetes_Deployment.yaml
#   make test_kind_all
RELEASE ?= common-library-ci
NAMESPACE ?= common-library-ci
RESOURCES ?= auto
WAIT_FLAGS ?= --wait --timeout 2m

test_kind:
	set -e; \
	helm lint . -f $(file) --quiet; \
	helm uninstall $(RELEASE) --namespace $(NAMESPACE) --ignore-not-found >/dev/null; \
	kubectl delete namespace $(NAMESPACE) --ignore-not-found --wait=true --timeout=90s >/dev/null; \
	kubectl create namespace $(NAMESPACE); \
	helm upgrade --install $(RELEASE) . \
		--namespace $(NAMESPACE) \
		-f $(file) \
		$(WAIT_FLAGS); \
	../../scripts/compare-helm-vs-cluster.py \
		--chart . \
		--values $(file) \
		--release $(RELEASE) \
		--namespace $(NAMESPACE) \
		--resources $(RESOURCES)

# Run every ci/*.yaml fixture (prereqs must already be installed).
test_kind_all:
	set -e; \
	for file in ci/*.yaml; do \
		echo "==> $$file"; \
		$(MAKE) test_kind file=$$file; \
	done
