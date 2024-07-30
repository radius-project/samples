#!/bin/bash

# ------------------------------------------------------------
# Copyright 2023 The Radius Authors.
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

set -ex

MATRIX=$1
RUN_IDENTIFIER=$2

MATRIX=${{ fromJSON(inputs.matrix) }}
RUN_IDENTIFIER=${{ inputs.RUN_IDENTIFIER }}-

if [[ "${{ matrix.enableDapr }}" == "true" ]]; then
  ENABLE_DAPR=true
else
  ENABLE_DAPR=false
fi

# Set output variables to be used in the other jobs
echo "RUN_IDENTIFIER=${RUN_IDENTIFIER}" >> $GITHUB_OUTPUT
echo "TEST_AZURE_RESOURCE_GROUP=rg-${RUN_IDENTIFIER}" >> $GITHUB_OUTPUT
echo "TEST_EKS_CLUSTER_NAME=eks-${RUN_IDENTIFIER}" >> $GITHUB_OUTPUT
echo "ENABLE_DAPR=${ENABLE_DAPR}" >> $GITHUB_OUTPUT