# pullResAllTags
#
# A query to pull all resources in an Azure tenant and display all of the tag values that are
# present in the environment. This is meant to be an audit-style reporting query.
#
#
# Author: Matthew Sunner, 2025


if (-not (Get-Module -ListAvailable -Name Az.Resources)) {
    Install-Module -Name Az.Resources -Scope CurrentUser -Force
}
Import-Module Az.Resources

# Authenticate to Azure (If not already authenticated)
Connect-AzAccount

# Get all subscriptions
$subscriptions = Get-AzSubscription

# Initialize an empty hash table to store unique tag keys
$TagKeys = @{}

# Loop through each subscription to collect tag keys
foreach ($sub in $subscriptions) {
    Set-AzContext -SubscriptionId $sub.Id

    # Get all resources with tags
    $resources = Get-AzResource | Where-Object { $_.Tags -ne $null }

    foreach ($resource in $resources) {
        foreach ($key in $resource.Tags.Keys) {
            $TagKeys[$key] = $true  # Store unique tag keys
        }
    }
}

# Convert hash table to an array of unique tag keys
$TagKeyList = $TagKeys.Keys

# Initialize an array to store results
$results = @()

# Loop through each subscription again to collect resource group data
foreach ($sub in $subscriptions) {
    Set-AzContext -SubscriptionId $sub.Id

    # Get all resource groups
    $resourceGroups = Get-AzResourceGroup

    foreach ($rg in $resourceGroups) {
        # Convert tags to lowercase for consistency
        $tagsLowerCase = @{}
        foreach ($key in $rg.Tags.Keys) {
            $tagsLowerCase[$key.ToLower()] = $rg.Tags[$key]
        }

        # Create a new object with the resource group name and extracted tags
        $rgData = @# Install and import Azure module if needed
        if (-not (Get-Module -ListAvailable -Name Az.Resources)) {
            Install-Module -Name Az.Resources -Scope CurrentUser -Force
        }
        Import-Module Az.Resources
        
        # Authenticate to Azure (If not already authenticated)
        Connect-AzAccount
        
        # Get all subscriptions
        $subscriptions = Get-AzSubscription
        
        # Initialize an empty hash table to store unique tag keys
        $TagKeys = @{}
        
        # Loop through each subscription to collect tag keys
        foreach ($sub in $subscriptions) {
            Set-AzContext -SubscriptionId $sub.Id
        
            # Get all resources with tags
            $resources = Get-AzResource | Where-Object { $_.Tags -ne $null }
        
            foreach ($resource in $resources) {
                foreach ($key in $resource.Tags.Keys) {
                    $TagKeys[$key] = $true  # Store unique tag keys
                }
            }
        }
        
        # Convert hash table to an array of unique tag keys
        $TagKeyList = $TagKeys.Keys
        
        # Initialize an array to store results
        $results = @()
        
        # Loop through each subscription again to collect resource group data
        foreach ($sub in $subscriptions) {
            Set-AzContext -SubscriptionId $sub.Id
        
            # Get all resource groups
            $resourceGroups = Get-AzResourceGroup
        
            foreach ($rg in $resourceGroups) {
                # Convert tags to lowercase for consistency
                $tagsLowerCase = @{}
                foreach ($key in $rg.Tags.Keys) {
                    $tagsLowerCase[$key.ToLower()] = $rg.Tags[$key]
                }
        
                # Create a new object with the resource group name and extracted tags
                $rgData = @{
                    Name = $rg.ResourceGroupName
                }
        
                # Add extracted tag keys as columns
                foreach ($tagKey in $TagKeyList) {
                    $rgData[$tagKey] = if ($tagsLowerCase.ContainsKey($tagKey.ToLower())) { 
                        $tagsLowerCase[$tagKey.ToLower()]
                    } else { 
                        $null 
                    }
                }
        
                # Add object to results
                $results += New-Object PSObject -Property $rgData
            }
        }
        
        # Output the results as a table
        $results | Format-Table -AutoSize
        
        # Optionally, export results to a CSV file
        $results | Export-Csv -Path "Azure_ResourceGroup_Tags.csv" -NoTypeInformation
        {
            Name = $rg.ResourceGroupName
        }

        # Add extracted tag keys as columns
        foreach ($tagKey in $TagKeyList) {
            $rgData[$tagKey] = if ($tagsLowerCase.ContainsKey($tagKey.ToLower())) { 
                $tagsLowerCase[$tagKey.ToLower()]
            } else { 
                $null 
            }
        }

        # Add object to results
        $results += New-Object PSObject -Property $rgData
    }
}

# Output the results as a table
$results | Format-Table -AutoSize

# Optionally, export results to a CSV file
$results | Export-Csv -Path "Azure_ResourceGroup_Tags.csv" -NoTypeInformation
