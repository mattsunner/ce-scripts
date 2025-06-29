# Authenticate to Azure
Connect-AzAccount

$query = @"
Resources
| project subscriptionId
| summarize by subscriptionId
"@

$subscriptions = Search-AzGraph -Query $query

$startDate = "2025-01-01"
$endDate = "2025-01-31"

$outputCsv = "AzureCostAnalysis.csv"

# Check if the CSV file exists. If not, create a new one with the headers.
if (-not (Test-Path $outputCsv)) {
    # Define API request body (as before)
    $body = @{
        type = "ActualCost"
        timeframe = "Custom"
        timePeriod = @{ 
            from = $startDate
            to = $endDate 
        }
        dataset = @{ 
            granularity = "Daily"
            aggregation = @{
                totalCost = @{ name = "PreTaxCost"; function = "Sum" }
            }
            grouping = @( 
                @{ type = "Dimension"; name = "ResourceId" },
                @{ type = "Dimension"; name = "ResourceType" },
                @{ type = "Dimension"; name = "ResourceLocation" },
                @{ type = "Dimension"; name = "ResourceGroupName" },
                @{ type = "Dimension"; name = "ServiceName" },
                @{ type = "Dimension"; name = "Meter" }
            )
        }
    } | ConvertTo-Json -Depth 10
}

# Iterate through each subscription ID
foreach ($subscriptionId in $subscriptionIds) {
    # Get access token
    $accessToken = (Get-AzAccessToken -ResourceUrl "https://management.azure.com").Token

    # Define API request
    $uri = "https://management.azure.com/subscriptions/$subscriptionId/providers/Microsoft.CostManagement/query?api-version=2024-01-01"
    $headers = @{ Authorization = "Bearer $accessToken"; "Content-Type" = "application/json" }

    # Call API and retrieve cost data
    $response = Invoke-RestMethod -Uri $uri -Method Post -Headers $headers -Body $body

    # Extract column names
    $columns = $response.properties.columns.name

    # Process and map data dynamically
    $costData = $response.properties.rows | ForEach-Object {
        $obj = [ordered]@{}
        for ($i = 0; $i -lt $columns.Count; $i++) {
            $obj[$columns[$i]] = $_[$i]
        }
        [PSCustomObject]$obj
    }

    # Export to CSV and append data
    $costData | Export-Csv -Path $outputCsv -NoTypeInformation -Append
}

Write-Host "Cost analysis data exported to $outputCsv"

