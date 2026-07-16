#!/usr/bin/env python3
"""Compare helm template output against live cluster objects.

Requires: helm, kubectl (stdlib only; no third-party Python packages).

Usage:
  compare-helm-vs-cluster.py \\
    --chart charts/common-library \\
    --values charts/common-library/ci/Kubernetes_Deployment.yaml \\
    --release common-library-ci \\
    --namespace common-library-ci \\
    --resources deployment/ci-deployment,service/ci-deployment

  Pass --resources auto to discover kind/name pairs from helm template output.
"""

from __future__ import annotations

import argparse
import copy
import json
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path
from typing import Any

DROP_META = {
    "uid",
    "resourceVersion",
    "generation",
    "creationTimestamp",
    "managedFields",
    "selfLink",
    "ownerReferences",
}
DROP_ANNOT_PREFIXES = (
    "kubectl.kubernetes.io/",
    "deployment.kubernetes.io/",
    "pv.kubernetes.io/",
    "volume.kubernetes.io/",
    "volume.beta.kubernetes.io/",
    "cert-manager.io/",
)
DROP_ANNOT_EXACT = {
    "meta.helm.sh/release-name",
    "meta.helm.sh/release-namespace",
}
DROP_LABEL_EXACT = {
    "app.kubernetes.io/managed-by",
    "helm.sh/chart",
    "app.kubernetes.io/instance",
    "app.kubernetes.io/name",
    "app.kubernetes.io/version",
}
POD_DEFAULTS = {
    "dnsPolicy": "ClusterFirst",
    "restartPolicy": "Always",
    "schedulerName": "default-scheduler",
    "terminationGracePeriodSeconds": 30,
}


def require_bins(*names: str) -> None:
    missing = [name for name in names if shutil.which(name) is None]
    if missing:
        raise SystemExit(f"Missing required binary: {', '.join(missing)}")


def run(cmd: list[str], check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(cmd, check=check, text=True, capture_output=True)


def as_items(payload: Any) -> list[dict[str, Any]]:
    if isinstance(payload, list):
        return [item for item in payload if isinstance(item, dict)]
    if isinstance(payload, dict):
        if payload.get("kind") == "List":
            return [item for item in payload.get("items", []) if isinstance(item, dict)]
        return [payload]
    return []


def scrub_annotations(annotations: dict[str, Any] | None) -> dict[str, Any] | None:
    if not annotations:
        return None
    cleaned = {
        key: value
        for key, value in annotations.items()
        if key not in DROP_ANNOT_EXACT and not any(key.startswith(prefix) for prefix in DROP_ANNOT_PREFIXES)
    }
    return cleaned or None


def scrub_labels(labels: dict[str, Any] | None) -> dict[str, Any] | None:
    if not labels:
        return None
    cleaned = {key: value for key, value in labels.items() if key not in DROP_LABEL_EXACT}
    return cleaned or None


def scrub_meta(meta: dict[str, Any] | None) -> dict[str, Any] | None:
    if not meta:
        return meta
    meta = {key: value for key, value in meta.items() if key not in DROP_META}
    annotations = scrub_annotations(meta.get("annotations"))
    if annotations:
        meta["annotations"] = annotations
    else:
        meta.pop("annotations", None)
    labels = scrub_labels(meta.get("labels"))
    if labels:
        meta["labels"] = labels
    else:
        meta.pop("labels", None)
    # Cluster-scoped objects may still carry a namespace from helm; drop empty/noise.
    if not meta.get("namespace"):
        meta.pop("namespace", None)
    return meta


def scrub_container(container: dict[str, Any]) -> dict[str, Any]:
    container.pop("terminationMessagePath", None)
    container.pop("terminationMessagePolicy", None)
    if container.get("securityContext") == {}:
        container.pop("securityContext", None)
    if isinstance(container.get("image"), str):
        container["image"] = container["image"].strip().strip('"')
    return container


def scrub_pod_spec(spec: dict[str, Any] | None) -> dict[str, Any] | None:
    if not spec:
        return spec
    for key, default in POD_DEFAULTS.items():
        if spec.get(key) == default:
            spec.pop(key, None)
    if spec.get("securityContext") == {}:
        spec.pop("securityContext", None)
    spec.pop("serviceAccount", None)
    if spec.get("hostNetwork") is False:
        spec.pop("hostNetwork", None)
    if "containers" in spec:
        spec["containers"] = [scrub_container(c) for c in spec["containers"]]
    if "initContainers" in spec:
        spec["initContainers"] = [scrub_container(c) for c in spec["initContainers"]]
    return spec


def scrub_service_spec(spec: dict[str, Any] | None) -> dict[str, Any] | None:
    if not spec:
        return spec
    for key in ("clusterIP", "clusterIPs", "ipFamilies", "ipFamilyPolicy", "internalTrafficPolicy"):
        spec.pop(key, None)
    ports = spec.get("ports")
    if isinstance(ports, list):
        cleaned_ports = []
        for port in ports:
            port = dict(port)
            if port.get("nodePort") in (None, "", 0):
                port.pop("nodePort", None)
            cleaned_ports.append(port)
        spec["ports"] = cleaned_ports
    return spec


def scrub_pod_template(doc: dict[str, Any]) -> dict[str, Any]:
    spec = doc.get("spec") or {}
    template = spec.get("template") or {}
    if "metadata" in template:
        template["metadata"] = scrub_meta(template["metadata"]) or {}
    if "spec" in template:
        template["spec"] = scrub_pod_spec(template["spec"])
    spec["template"] = template
    doc["spec"] = spec
    return doc


def scrub_deployment(doc: dict[str, Any]) -> dict[str, Any]:
    doc = scrub_pod_template(doc)
    spec = doc.get("spec") or {}

    strategy = spec.get("strategy") or {}
    rolling = strategy.get("rollingUpdate") or {}
    if (
        strategy.get("type") == "RollingUpdate"
        and rolling.get("maxUnavailable") == "25%"
        and rolling.get("maxSurge") == "25%"
    ):
        spec.pop("strategy", None)
    if spec.get("revisionHistoryLimit") == 10:
        spec.pop("revisionHistoryLimit", None)
    if spec.get("progressDeadlineSeconds") == 600:
        spec.pop("progressDeadlineSeconds", None)

    doc["spec"] = spec
    return doc


def scrub_daemonset(doc: dict[str, Any]) -> dict[str, Any]:
    doc = scrub_pod_template(doc)
    spec = doc.get("spec") or {}
    strategy = spec.get("updateStrategy") or {}
    rolling = strategy.get("rollingUpdate") or {}
    if strategy.get("type") == "RollingUpdate" and rolling.get("maxUnavailable") == 1 and "maxSurge" not in rolling:
        # Keep explicit updateStrategy from values; only drop pure API defaults when empty-ish.
        pass
    if spec.get("revisionHistoryLimit") == 10:
        spec.pop("revisionHistoryLimit", None)
    doc["spec"] = spec
    return doc


def scrub_statefulset(doc: dict[str, Any]) -> dict[str, Any]:
    doc = scrub_pod_template(doc)
    spec = doc.get("spec") or {}
    if spec.get("podManagementPolicy") == "OrderedReady":
        spec.pop("podManagementPolicy", None)
    if spec.get("revisionHistoryLimit") == 10:
        spec.pop("revisionHistoryLimit", None)
    strategy = spec.get("updateStrategy") or {}
    rolling = strategy.get("rollingUpdate") or {}
    if strategy.get("type") == "RollingUpdate" and rolling.get("partition") == 0 and len(rolling) == 1:
        strategy.pop("rollingUpdate", None)
    doc["spec"] = spec
    return doc


def scrub_job(doc: dict[str, Any]) -> dict[str, Any]:
    doc = scrub_pod_template(doc)
    spec = doc.get("spec") or {}
    # Job pods default restartPolicy is Never when set by the template; keep as rendered.
    template_spec = ((spec.get("template") or {}).get("spec")) or {}
    if template_spec.get("restartPolicy") == "Never":
        pass
    if spec.get("completionMode") == "NonIndexed":
        spec.pop("completionMode", None)
    if spec.get("suspend") is False:
        spec.pop("suspend", None)
    doc["spec"] = spec
    return doc


def scrub_cronjob(doc: dict[str, Any]) -> dict[str, Any]:
    spec = doc.get("spec") or {}
    job_template = spec.get("jobTemplate") or {}
    job_spec = job_template.get("spec") or {}
    # Reuse Job/pod scrubbing on the nested jobTemplate.spec.
    nested = scrub_job({"spec": job_spec}).get("spec") or {}
    if nested.get("completionMode") == "NonIndexed":
        nested.pop("completionMode", None)
    job_template["spec"] = nested
    if "metadata" in job_template:
        job_template["metadata"] = scrub_meta(job_template.get("metadata")) or {}
    spec["jobTemplate"] = job_template
    if spec.get("suspend") is False:
        spec.pop("suspend", None)
    if spec.get("concurrencyPolicy") == "Allow":
        spec.pop("concurrencyPolicy", None)
    if spec.get("successfulJobsHistoryLimit") == 3:
        spec.pop("successfulJobsHistoryLimit", None)
    if spec.get("failedJobsHistoryLimit") == 1:
        spec.pop("failedJobsHistoryLimit", None)
    doc["spec"] = spec
    return doc


def scrub_pvc(doc: dict[str, Any]) -> dict[str, Any]:
    spec = doc.get("spec") or {}
    # volumeName / storageClass defaults appear after binding; drop cluster-assigned volumeName.
    spec.pop("volumeName", None)
    doc["spec"] = spec
    return doc


def scrub_secret(doc: dict[str, Any]) -> dict[str, Any]:
    # Live Secrets never retain stringData; dry-run usually converts to data.
    doc.pop("stringData", None)
    if doc.get("type") == "Opaque":
        # Keep type for comparison consistency.
        pass
    return doc


def scrub_serviceaccount(doc: dict[str, Any]) -> dict[str, Any]:
    if doc.get("secrets") == []:
        doc.pop("secrets", None)
    if doc.get("imagePullSecrets") == []:
        doc.pop("imagePullSecrets", None)
    return doc


def scrub_hpa(doc: dict[str, Any]) -> dict[str, Any]:
    spec = doc.get("spec") or {}
    if spec.get("behavior") == {}:
        spec.pop("behavior", None)
    doc["spec"] = spec
    return doc


def scrub_certificate(doc: dict[str, Any]) -> dict[str, Any]:
    spec = doc.get("spec") or {}
    # cert-manager may inject revisionHistoryLimit / privateKey defaults after apply.
    if spec.get("revisionHistoryLimit") == 1:
        spec.pop("revisionHistoryLimit", None)
    private_key = spec.get("privateKey") or {}
    if private_key.get("rotationPolicy") == "Never" and len(private_key) == 1:
        spec.pop("privateKey", None)
    doc["spec"] = spec
    return doc


def scrub_ingress(doc: dict[str, Any]) -> dict[str, Any]:
    # Controllers may add defaultBackend / class annotations; compare core spec only.
    return doc


def normalize(doc: dict[str, Any]) -> dict[str, Any]:
    doc = copy.deepcopy(doc)
    doc.pop("status", None)
    if "metadata" in doc:
        doc["metadata"] = scrub_meta(doc["metadata"])
    kind = doc.get("kind")
    if kind == "Deployment":
        return scrub_deployment(doc)
    if kind == "DaemonSet":
        return scrub_daemonset(doc)
    if kind == "StatefulSet":
        return scrub_statefulset(doc)
    if kind == "Job":
        return scrub_job(doc)
    if kind == "CronJob":
        return scrub_cronjob(doc)
    if kind == "Service" and "spec" in doc:
        doc["spec"] = scrub_service_spec(doc["spec"])
        return doc
    if kind == "PersistentVolumeClaim":
        return scrub_pvc(doc)
    if kind == "Secret" and api_group(doc.get("apiVersion")) is None:
        return scrub_secret(doc)
    if kind == "ServiceAccount":
        return scrub_serviceaccount(doc)
    if kind == "HorizontalPodAutoscaler":
        return scrub_hpa(doc)
    if kind == "Certificate":
        return scrub_certificate(doc)
    if kind == "Ingress":
        return scrub_ingress(doc)
    return doc


def api_group(api_version: str | None) -> str | None:
    """Return API group for a Group/Version string, or None for core (v1)."""
    if not api_version or "/" not in api_version:
        return None
    group, _version = api_version.split("/", 1)
    return group or None


def resource_ref(item: dict[str, Any]) -> str | None:
    """Build a kubectl-get ref that disambiguates colliding Kind names.

    Core resources stay as ``kind/name``. Grouped APIs use ``Kind.group/name``
    so ACK Role/Secret do not resolve to RBAC Role / core Secret.
    """
    kind = item.get("kind")
    name = (item.get("metadata") or {}).get("name")
    if not kind or not name or kind == "List":
        return None
    group = api_group(item.get("apiVersion"))
    if group:
        return f"{kind}.{group}/{name}"
    return f"{kind.lower()}/{name}"


def parse_resource_ref(resource: str) -> tuple[str, str | None, str]:
    """Parse ``kind/name`` or ``Kind.group/name`` into (kind, group, name)."""
    kind_part, name = resource.split("/", 1)
    if "." in kind_part:
        kind, group = kind_part.split(".", 1)
        return kind, group, name
    return kind_part, None, name


def find_resource(
    items: list[dict[str, Any]],
    kind: str,
    name: str,
    group: str | None = None,
) -> dict[str, Any] | None:
    kind_l = kind.lower()
    for item in items:
        if (item.get("kind") or "").lower() != kind_l:
            continue
        if (item.get("metadata") or {}).get("name") != name:
            continue
        if group is not None and api_group(item.get("apiVersion")) != group:
            continue
        return item
    return None


def discover_resources(items: list[dict[str, Any]]) -> list[str]:
    discovered: list[str] = []
    seen: set[str] = set()
    for item in items:
        key = resource_ref(item)
        if not key or key in seen:
            continue
        seen.add(key)
        discovered.append(key)
    return discovered


def dump_sorted(path: Path, doc: dict[str, Any]) -> None:
    path.write_text(json.dumps(doc, indent=2, sort_keys=True) + "\n")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--chart", required=True)
    parser.add_argument("--values", required=True)
    parser.add_argument("--release", required=True)
    parser.add_argument("--namespace", required=True)
    parser.add_argument(
        "--resources",
        required=True,
        help="kind/name[,kind/name...] or 'auto' to discover from helm template",
    )
    args = parser.parse_args()

    require_bins("helm", "kubectl")

    with tempfile.TemporaryDirectory() as tmp:
        tmpdir = Path(tmp)
        expected_yaml = tmpdir / "expected.yaml"
        expected_json = tmpdir / "expected.raw.json"
        live_json = tmpdir / "live.raw.json"

        rendered = run(
            [
                "helm",
                "template",
                args.release,
                args.chart,
                "-n",
                args.namespace,
                "-f",
                args.values,
            ]
        )
        expected_yaml.write_text(rendered.stdout)

        dry_run = run(
            ["kubectl", "apply", "--dry-run=client", "-o", "json", "-f", str(expected_yaml)]
        )
        expected_json.write_text(dry_run.stdout)
        expected_items = as_items(json.loads(dry_run.stdout))

        if args.resources.strip().lower() == "auto":
            resources = discover_resources(expected_items)
        else:
            resources = [item.strip() for item in args.resources.split(",") if item.strip()]
        if not resources:
            raise SystemExit("--resources must include at least one kind/name (or auto with rendered objects)")

        live = run(["kubectl", "get", *resources, "-n", args.namespace, "-o", "json"])
        live_json.write_text(live.stdout)
        live_items = as_items(json.loads(live.stdout))

        failed = False
        for resource in resources:
            kind, group, name = parse_resource_ref(resource)
            expected = find_resource(expected_items, kind, name, group)
            actual = find_resource(live_items, kind, name, group)

            if expected is None:
                print(f"FAIL: {kind}/{name} not found in helm template output", file=sys.stderr)
                failed = True
                continue
            if actual is None:
                print(f"FAIL: {kind}/{name} not found in cluster", file=sys.stderr)
                failed = True
                continue

            expected_norm = normalize(expected)
            live_norm = normalize(actual)
            expected_path = tmpdir / f"expected.{kind}.{name}.json"
            live_path = tmpdir / f"live.{kind}.{name}.json"
            dump_sorted(expected_path, expected_norm)
            dump_sorted(live_path, live_norm)

            print(f"==> Diff {kind}/{name}")
            diff = run(["diff", "-u", str(expected_path), str(live_path)], check=False)
            if diff.returncode == 0:
                print(f"OK: {kind}/{name}")
            else:
                if diff.stdout:
                    print(diff.stdout, end="")
                print(f"FAIL: mismatch for {kind}/{name}", file=sys.stderr)
                failed = True

        if failed:
            return 1

    print("OK: all resources match after normalization")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
