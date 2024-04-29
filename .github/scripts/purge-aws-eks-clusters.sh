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

# Current time in seconds since epoch
current_time=$(date +%s)

# Age limit in seconds (6 hours * 3600 seconds/hour)
age_limit=$((6 * 3600))

echo "Starting cluster purge script."

# List clusters and their creation times, filter and delete those older than 6 hours and starting with 'eks-samplestest-'
aws eks list-clusters --query "clusters[]" --output text | xargs -I {} aws eks describe-cluster --name {} --query "cluster.{name: name, createdAt: createdAt}" --output text | while read -r created_at name; do
    # Convert creation time to seconds since the epoch
    # Remove milliseconds and adjust timezone format from "-07:00" to "-0700"
    formatted_created_at="${created_at%.*}${created_at##*.}"
    formatted_created_at="${formatted_created_at%:*}${formatted_created_at##*:}"

    # Convert creation time to seconds
    created_at_seconds=$(date -d "$formatted_created_at" +%s)

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
