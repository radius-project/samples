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

BEGIN {
    if (CHANNEL == "") {
        print "Error: CHANNEL is not set." > "/dev/stderr"
        exit 1
    }
}

{
    gsub(/"br:ghcr\.io\/radius-project\/bicep-types-radius:edge"/,
        "\"br:ghcr.io/radius-project/bicep-types-radius:" CHANNEL "\"")
    gsub(/"br:ghcr\.io\/radius-project\/bicep-types-aws:edge"/,
        "\"br:ghcr.io/radius-project/bicep-types-aws:" CHANNEL "\"")
    print
}
