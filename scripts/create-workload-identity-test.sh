githubOrganizationName='Valerio-PCG'
githubRepositoryName='bicep-end-to-end'

applicationRegistrationDetails=$(az ad app create --display-name 'bicep-end-to-end-test')
applicationRegistrationObjectId=$(echo $applicationRegistrationDetails | jq -r '.id')
applicationRegistrationAppId=$(echo $applicationRegistrationDetails | jq -r '.appId')

az ad app federated-credential create \
   --id $applicationRegistrationObjectId \
   --parameters "{\"name\":\"bicep-end-to-end-test\",\"issuer\":\"https://token.actions.githubusercontent.com\",\"subject\":\"repo:${githubOrganizationName}/${githubRepositoryName}:environment:Test\",\"audiences\":[\"api://AzureADTokenExchange\"]}"

az ad app federated-credential create \
   --id $applicationRegistrationObjectId \
   --parameters "{\"name\":\"bicep-end-to-end-test-branch\",\"issuer\":\"https://token.actions.githubusercontent.com\",\"subject\":\"repo:${githubOrganizationName}/${githubRepositoryName}:ref:refs/heads/main\",\"audiences\":[\"api://AzureADTokenExchange\"]}"