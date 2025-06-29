<#
updateTags.ps1 - Azure Tag Update Script (Safe Merge, Tag Contributor Compatible)

This script reads a CSV file with Azure Subscription IDs and Resource Group names,
then updates or adds a single tag without overwriting existing ones.

Usage:
.\updateTags.ps1 -inputCsv "path/to/file.csv" -tagKey "TagName" -tagValue "NewValue"

CSV Format:
SubscriptionId,ResourceGroupName
xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx,ResourceGroup1
yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy,ResourceGroup2

Author: Matthew Sunner, 2025
#>

Param (
    [string]$inputCsv,
    [string]$tagKey,
    [string]$tagValue
)

Import-Module Az.Resources -ErrorAction Stop

if (-not (Get-AzContext)) {
    Connect-AzAccount
}

if (-not (Test-Path $inputCsv)) {
    Write-Error "Input CSV file not found: $inputCsv"
    exit 1
}

$csvData = Import-Csv -Path $inputCsv
$totalGroups = $csvData.Count
$currentGroup = 0

Write-Host "Loaded input file. Processing $totalGroups resource groups..."

foreach ($row in $csvData) {
    $currentGroup++
    $subscriptionId = $row.SubscriptionId
    $resourceGroupName = $row.ResourceGroupName

    Write-Host "`nProcessing group $currentGroup of $totalGroups"
    Write-Host "Setting context to subscription $subscriptionId"
    
    try {
        Set-AzContext -SubscriptionId $subscriptionId -ErrorAction Stop
    } catch {
        Write-Host "Failed to set context for Subscription ID $subscriptionId"
        Write-Host $_.Exception.Message
        continue
    }

    $resourceGroupId = "/subscriptions/$subscriptionId/resourceGroups/$resourceGroupName"

    try {
        # Get existing tags
        $existingTagData = Get-AzTag -ResourceId $resourceGroupId -ErrorAction SilentlyContinue
        $tags = $existingTagData?.Properties?.Tags

        if (-not $tags) {
            $tags = @{}
        }

        $tags[$tagKey] = $tagValue

        Update-AzTag -ResourceId $resourceGroupId -Tag $tags -Operation Merge

        Write-Host "Successfully updated tag '$tagKey' to '$tagValue' on resource group '$resourceGroupName' in subscription '$subscriptionId'"
    } catch {
        if ($_.Exception.Message -like "*AuthorizationFailed*") {
            Write-Host "Permission denied: You need Tag Contributor role to update tags on resource group $resourceGroupName"
        } else {
            Write-Host "Failed to update tags for resource group $resourceGroupName in subscription $subscriptionId"
            Write-Host $_.Exception.Message
        }
    }
}

Write-Host "`nTag update operation completed. Processed $currentGroup of $totalGroups resource groups."
