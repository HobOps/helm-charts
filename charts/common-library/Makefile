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