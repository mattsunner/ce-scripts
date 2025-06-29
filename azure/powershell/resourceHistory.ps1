$query = @"
Resources
| project subscriptionId
| summarize by subscriptionId
"@

$subscriptions = Search-AzGraph -Query $query

if ($subscriptions -and $subscriptions.Count -gt 0) {
    $subscriptionIds = $subscriptions | Select-Object -ExpandProperty subscriptionId

    Write-Output "Subscription IDs retrieved from Azure Resource Graph:"
    $subscriptionIds

    $startTime = Get-Date "2025-01-01T00:00:00Z"

    $finalResults = @()

    foreach ($subscriptionId in $subscriptionIds) {
        Set-AzContext -SubscriptionId $subscriptionId

        $resourcesCreated = Search-AzGraph -Query @"
Resources
| where isnotempty(properties.createdTime)
| where todatetime(properties.createdTime) >= datetime($($startTime))
| project name, type, resourceGroup, subscriptionId, createdTime=properties.createdTime
"@

        $resourcesDeleted = Get-AzLog -StartTime $startTime `
            | Where-Object { $_.OperationName -like "Microsoft.Resources/deployments/delete" } `
            | Select-Object TimeGenerated, ResourceId, Caller

        foreach ($created in $resourcesCreated) {
            $finalResults += [PSCustomObject]@{
                SubscriptionId = $subscriptionId
                ResourceName   = $created.name
                ResourceType   = $created.type
                ResourceGroup  = $created.resourceGroup
                Action         = "Created"
                ActionTime     = $created.createdTime
                Caller         = ""  
            }
        }

        foreach ($deleted in $resourcesDeleted) {
            $finalResults += [PSCustomObject]@{
                SubscriptionId = $subscriptionId
                ResourceName   = $deleted.ResourceId
                ResourceType   = ""  
                ResourceGroup  = $deleted.ResourceGroup
                Action         = "Deleted"
                ActionTime     = $deleted.TimeGenerated
                Caller         = $deleted.Caller
            }
        }
    }

    $csvFilePath = "AzureResourcesReport.csv"
    $finalResults | Export-Csv -Path $csvFilePath -NoTypeInformation

    Write-Output "Results have been exported to $csvFilePath"
} else {
    Write-Output "No subscription IDs were retrieved. Ensure you have resources in your subscriptions."
}
