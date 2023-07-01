# Testing
When adding a new template, you need to create an example file in the 'examples' folder.
Otherwise, the test will fail.

## Test all charts
```
make test_all
```

## Test single chart
```
make test file=examples/Kubernetes_Deployment.yaml
```