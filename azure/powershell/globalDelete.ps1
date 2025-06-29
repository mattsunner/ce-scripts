########################################
# Need to Review and Audit this Script #
########################################

$SubscriptionId = "<SUBSCRIPTION_ID>"
az account set --subscription $SubscriptionId

$ResourceGroups = az group list --query "[].name" -o tsv

foreach ($RG in $ResourceGroups) {
    az group delete --name $RG --yes --no-wait
}
