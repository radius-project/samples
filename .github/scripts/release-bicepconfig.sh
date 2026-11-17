#!/bin/bash

# ------------------------------------------------------------
# Copyright 2026 The Radius Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ------------------------------------------------------------

set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <version> <bicepconfig.json>" >&2
  exit 1
fi

VERSION_NUMBER=$1
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

python3 "${SCRIPT_DIR}/validate_semver.py" "${VERSION_NUMBER}" >&2

CHANNEL="$(printf '%s\n' "${VERSION_NUMBER}" | cut -d '.' -f 1,2)"
if [[ "${VERSION_NUMBER}" =~ ^[0-9]+\.[0-9]+\.[0-9]+- ]]; then
  if [[ "${VERSION_NUMBER}" == *+* ]]; then
    echo "Error: Prerelease build metadata cannot be used in an OCI tag." >&2
    exit 1
  fi
  CHANNEL="${VERSION_NUMBER}"
fi

awk -v CHANNEL="${CHANNEL}" -f "${SCRIPT_DIR}/release-bicepconfig.awk" "$2"
