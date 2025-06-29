# Accept subscription ID as a parameter
param(
    [string]$subscriptionId
)

# Ensure the subscription ID is provided
if (-not $subscriptionId) {
    Write-Host "Subscription ID is required. Usage: .\azCATracking.ps1 -subscriptionId <Your-Subscription-ID>"
    exit
}

# Authenticate to Azure
Connect-AzAccount

# Set variables
$startDate = "2025-01-01"
$endDate = "2025-03-30"

$outputCsv = "data/AzureCostAnalysis_$subscriptionId.csv"
# Define API request body
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

# Export to CSV
$costData | Export-Csv -Path $outputCsv -NoTypeInformation

Write-Host "Cost analysis data exported to $outputCsv"

