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
          echo "Deleting resource of type: $resource_type with identifier: $identifier"
          aws cloudcontrol delete-resource --type-name "$resource_type" --identifier "$identifier"
        fi
      done
    done
  done
done
