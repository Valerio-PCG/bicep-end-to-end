applicationRegistrationName="bicep-end-to-end-test"
ResourceGroupResourceId=$(az group create --name rg-bicep-end-to-end-test --location westeurope --query id --output tsv)

applicationRegistrationDetails=$(az ad app list --query "[].{displayName:displayName, id:id, appId:appId} | [? contains(displayName, '$applicationRegistrationName')]" --output json | jq -r '.[0]')
applicationRegistrationObjectId=$(echo $applicationRegistrationDetails | jq -r '.id')
applicationRegistrationAppId=$(echo $applicationRegistrationDetails | jq -r '.appId')

az ad sp create --id $applicationRegistrationObjectId
az role assignment create \
   --assignee $applicationRegistrationAppId \
   --role Contributor \
   --scope $resourceGroupResourceId