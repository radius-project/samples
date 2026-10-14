"""Prepare the released template, changing only its image literal."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import secrets
import urllib.request

COMMIT = "a366d18f573797763113ac04c8f14a1230f3643e"
BLOB = "868e2846c8e4854551edce137aac756bb63c4696"
URL = f"https://raw.githubusercontent.com/radius-project/samples/{COMMIT}/samples/demo/app-postgresql.bicep"
IMAGE = b"image: 'ghcr.io/radius-project/samples/demo:latest'"


def prepare(directory, image):
    if not re.fullmatch(r"[a-zA-Z0-9][a-zA-Z0-9._:/@-]+", image):
        raise ValueError("Invalid candidate image reference")
    original = urllib.request.urlopen(URL, timeout=60).read()
    identity = hashlib.sha1(f"blob {len(original)}\0".encode() + original).hexdigest()
    if identity != BLOB or original.count(IMAGE) != 1:
        raise ValueError("Pinned released template identity or image literal changed")
    replacement = f"image: '{image}'".encode()
    candidate = original.replace(IMAGE, replacement, 1)
    if candidate == original or candidate.replace(replacement, IMAGE, 1) != original:
        raise ValueError("Candidate must differ by exactly one image substitution")
    directory.mkdir(parents=True, exist_ok=True)
    (directory / "released-original.bicep").write_bytes(original)
    (directory / "app-postgresql.bicep").write_bytes(candidate)
    with open(directory / "parameters.json", "w", opener=lambda path, flags: os.open(path, flags, 0o600)) as stream:
        json.dump({
            "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
            "contentVersion": "1.0.0.0",
            "parameters": {"password": {"value": secrets.token_hex(24)}},
        }, stream)
    print(json.dumps({"templateCommit": COMMIT, "templateGitBlob": identity,
                      "candidateImage": image, "edits": 1}))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    parser.add_argument("image")
    args = parser.parse_args()
    prepare(args.directory, args.image)
