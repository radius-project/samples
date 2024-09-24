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

#!/bin/bash

set -ex

# Current time in seconds since epoch
current_time=$(date +%s)

# Age limit in seconds (6 hours * 3600 seconds/hour)
age_limit=$((6 * 3600))

echo "Starting cluster purge script."

# List clusters
clusters=$(aws eks list-clusters --query "clusters[]" --output text)

# Loop through each cluster
for cluster in $clusters; do
    # Get the creation time and name of the cluster
    cluster_info=$(aws eks describe-cluster --name "$cluster" --query "cluster.{name: name, createdAt: createdAt}" --output text)
    created_at=$(echo "$cluster_info" | awk '{print $1}')
    name=$(echo "$cluster_info" | awk '{print $2}')

    # Ensure created_at is in the correct format
    created_at=$(echo "$created_at" | sed 's/\.[0-9]*Z//')

    # Convert creation time to seconds since the epoch using date
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        if ! command -v gdate &> /dev/null; then
            echo "gdate could not be found. Please install coreutils: brew install coreutils"
            exit 1
        fi
        created_at_seconds=$(gdate -d "$created_at" +%s)
    else
        # Linux
        created_at_seconds=$(date -d "$created_at" +%s)
    fi

    # Calculate age in seconds
    age=$((current_time - created_at_seconds))

    # Check if age is greater than age limit and name starts with 'eks-samplestest-'
    if [ "$age" -gt "$age_limit" ] && [[ "$name" == eks-samplestest-* ]]; then
        echo "Deleting cluster $name older than 6 hours."
        eksctl delete cluster --name "$name" --wait --force
    else
        echo "Cluster $name is not older than 6 hours or does not meet naming criteria."
    fi
done
