"""Fail if a committed package-lock.json points at a registry other than npmjs.

Lockfiles are written with omit-lockfile-registry-resolved=true (see the
.npmrc next to each package.json), so registry packages should have no
resolved URL at all. Any resolved URL that is left must use
registry.npmjs.org, and no lockfile may reference an Azure Artifacts feed.
"""

import json
import re
import subprocess
import sys
from urllib.parse import urlparse

ALLOWED_HOST = "registry.npmjs.org"
BLOCKED_HOSTS = re.compile(r"pkgs\.visualstudio\.com|pkgs\.dev\.azure\.com", re.IGNORECASE)

lockfiles = subprocess.run(
    ["git", "ls-files", "*package-lock.json"],
    check=True,
    capture_output=True,
    text=True,
).stdout.split()

failures = []

for path in lockfiles:
    with open(path, encoding="utf-8") as f:
        text = f.read()

    for match in BLOCKED_HOSTS.finditer(text):
        failures.append(f"{path}: references private feed host '{match.group(0)}'")

    for name, package in json.loads(text).get("packages", {}).items():
        resolved = package.get("resolved", "")
        if not resolved.startswith(("http://", "https://")):
            continue
        host = urlparse(resolved).hostname
        if host != ALLOWED_HOST:
            failures.append(f"{path}: {name or '(root)'} resolves from '{host}'")

for failure in failures:
    print(failure, flush=True)

if failures:
    print(
        f"\nFound {len(failures)} problem(s). Regenerate the lockfile with "
        "'npm install --package-lock-only' from the project folder.",
        flush=True,
    )
    sys.exit(1)

print(f"Checked {len(lockfiles)} lockfile(s), no registry URLs outside {ALLOWED_HOST}.")
