Setup Azure login
az cloud set -n AzureChinaCloud 
az cloud set -n AzureCloud

Setup ENV variables
$env:ARM_TENANT_ID = "a703322f-bd88-408f-b89c-7d4160275b60"
$env:ARM_SUBSCRIPTION_ID = "d4ae5da9-a858-4d69-8c55-ac05adb19757"