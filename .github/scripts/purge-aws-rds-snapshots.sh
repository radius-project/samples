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

set -xe

# Get the list of snapshots IDs and their states
aws rds describe-db-snapshots --query 'DBSnapshots[*].[DBSnapshotIdentifier,Status]' --output text > snapshots.txt

# Delete snapshots that are in 'available' or 'failed' state
while read -r rds_snapshot_identifier rds_snapshot_status; do
    if [[ "$rds_snapshot_status" == "available" || "$rds_snapshot_status" == "failed" ]]; then
        echo "Deleting snapshot: $rds_snapshot_identifier"
        aws rds delete-db-snapshot --db-snapshot-identifier "$rds_snapshot_identifier"
    else
        echo "Skipping snapshot $rds_snapshot_identifier (status: $rds_snapshot_status)"
    fi
done < snapshots.txt

# Delete the temporary snapshots file
rm snapshots.txt
