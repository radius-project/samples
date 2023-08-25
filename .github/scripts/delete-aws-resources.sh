          for RESOURCE_TYPE in ${{ env.RESOURCE_TYPES }}; do
            aws cloudcontrol list-resources --region ${{ env.AWS_REGION }} --type-name $RESOURCE_TYPE --query 'ResourceDescriptions[].Identifier' --output text > resources.txt
            while read -r line; do
              aws cloudcontrol delete-resource --region ${{ env.AWS_REGION }} --type $RESOURCE_TYPE --identifier $line
            done < resources.txt
          done
          aws cloudcontrol list-resources --region ${{ env.AWS_REGION }} --type-name ${{ env.RESOURCE_TYPES }} --query 'ResourceDescriptions[].Identifier' --output text > resources.txt
          # delete resource
          while read -r line; do
            aws cloudcontrol delete-resource --region ${{ env.AWS_REGION }} --type ${{ env.RESOURCE_TYPES }} --identifier $line
          done < resources.txt