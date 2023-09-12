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


APP_NAME=$1
APP_LABEL='RadiusApplication'
RESOURCE_TYPES='AWS::RDS::DBInstance,AWS::RDS::DBSubnetGroup,AWS::MemoryDB::Cluster,AWS::MemoryDB::SubnetGroup'

# Number of retries
MAX_RETRIES=5

# Retry delay in seconds
RETRY_DELAY=300 # 5 minutes

function delete_aws_resources() {
  # Variable to track if any resource needs to be deleted
  resource_to_be_deleted=0

  for resource_type in ${RESOURCE_TYPES//,/ }
  do
    aws cloudcontrol list-resources --type-name "$resource_type" --query "ResourceDescriptions[].Identifier" --output text | tr '\t' '\n' | while read identifier
    do
      aws cloudcontrol get-resource --type-name "$resource_type" --identifier "$identifier" --query "ResourceDescription.Properties" --output text | while read resource
      do
        resource_tags=$(jq -c -r .Tags <<< "$resource")
        for tag in $(jq -c -r '.[]' <<< "$resource_tags")
        do
          key=$(jq -r '.Key' <<< "$tag")
          value=$(jq -r '.Value' <<< "$tag")
          if [[ "$key" == "$APP_LABEL" && "$value" == "$APP_NAME" ]]
          then
            resource_to_be_deleted=1
            echo "Deleting resource of type: $resource_type with identifier: $identifier"
            aws cloudcontrol delete-resource --type-name "$resource_type" --identifier "$identifier"
          fi
        done
      done
    done
  done

  return $resource_to_be_deleted
}

RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
    # Trigger the function to delete the resources
    delete_aws_resources

    # If the function returned 0, then no resources were deleted
    if [ $? -eq 0 ]; then
        echo "All resources deleted successfully"
        break
    fi

    # Still have resources to delete, increase the retry count
    RETRY_COUNT=$((RETRY_COUNT + 1))

    # Check if there are more retries left
    if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
        # Retry after delay
        echo "Retrying in $RETRY_DELAY seconds..."
        sleep $RETRY_DELAY
    fi
done

# Check if the maximum number of retries exceeded
if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo "Maximum number of retries exceeded"
fi
