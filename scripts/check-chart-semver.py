#!/usr/bin/env python3
"""Ensure common-library Chart.yaml version bumps when the chart changes.

Usage:
  check-chart-semver.py <base-ref> [head-ref]
  check-chart-semver.py --local [base-ref]
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

CHART_PATH = "charts/common-library"
CHART_YAML = f"{CHART_PATH}/Chart.yaml"
SEMVER_RE = re.compile(r"^[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$")


def run(cmd: list[str], check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(cmd, check=check, text=True, capture_output=True)


def version_from_text(text: str) -> str | None:
    for line in text.splitlines():
        line = line.strip()
        if line.startswith("version:"):
            return line.split(":", 1)[1].strip().strip("\"'")
    return None


def version_from_file(path: Path) -> str:
    version = version_from_text(path.read_text())
    if not version:
        raise SystemExit(f"version: not found in {path}")
    return version


def version_from_git(ref: str) -> str | None:
    result = run(["git", "show", f"{ref}:{CHART_YAML}"], check=False)
    if result.returncode != 0:
        return None
    return version_from_text(result.stdout)


def parse_semver(version: str) -> tuple[int, int, int]:
    core = version.split("-", 1)[0].split("+", 1)[0]
    parts = core.split(".")
    if len(parts) != 3 or not all(p.isdigit() for p in parts):
        raise ValueError(version)
    return int(parts[0]), int(parts[1]), int(parts[2])


def is_semver(version: str) -> bool:
    return bool(SEMVER_RE.match(version))


def semver_gt(newer: str, older: str) -> bool:
    return parse_semver(newer) > parse_semver(older)


def chart_changed(base: str, head: str | None = None) -> bool:
    if head:
        result = run(["git", "diff", "--name-only", f"{base}...{head}", "--", f"{CHART_PATH}/"])
        return bool(result.stdout.strip())

    unstaged = run(["git", "diff", "--name-only", base, "--", f"{CHART_PATH}/"])
    staged = run(["git", "diff", "--cached", "--name-only", "--", f"{CHART_PATH}/"])
    return bool(unstaged.stdout.strip() or staged.stdout.strip())


def resolve_local_base(preferred: str) -> str:
    probe = run(["git", "rev-parse", "--verify", preferred], check=False)
    if probe.returncode == 0:
        return preferred
    return "main"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--local", action="store_true", help="Compare working tree to a base ref")
    parser.add_argument("refs", nargs="*", help="base [head], or base when using --local")
    args = parser.parse_args()

    if args.local:
        base = resolve_local_base(args.refs[0] if args.refs else "origin/main")
        if not chart_changed(base):
            print(f"No {CHART_PATH} changes vs {base}; skipping semver check")
            return 0
        new_version = version_from_file(Path(CHART_YAML))
        old_version = version_from_git(base) or "0.0.0"
    else:
        if not args.refs:
            parser.error("Usage: check-chart-semver.py <base-ref> [head-ref] | --local [base-ref]")
        base = args.refs[0]
        head = args.refs[1] if len(args.refs) > 1 else "HEAD"
        if not chart_changed(base, head):
            print(f"No {CHART_PATH} changes in {base}...{head}; skipping semver check")
            return 0
        new_version = version_from_git(head)
        if not new_version:
            raise SystemExit(f"Unable to read {CHART_YAML} from {head}")
        old_version = version_from_git(base) or "0.0.0"

    if not is_semver(new_version):
        print(f"Invalid chart version '{new_version}' in {CHART_YAML}", file=sys.stderr)
        return 1
    if not is_semver(old_version):
        print(f"Invalid base chart version '{old_version}'", file=sys.stderr)
        return 1
    if not semver_gt(new_version, old_version):
        print(f"Chart version must increase when {CHART_PATH} changes", file=sys.stderr)
        print(f"  base ({base}): {old_version}", file=sys.stderr)
        print(f"  head: {new_version}", file=sys.stderr)
        return 1

    print(f"Semver OK: {old_version} -> {new_version}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
