<#
.SYNOPSIS
  Safely add/merge a single tag to multiple resource groups across subscriptions.

.PARAMETER inputCsv
  Path to CSV with SubscriptionId,ResourceGroupName.

.PARAMETER tagKey
  Tag name.

.PARAMETER tagValue
  Tag value.

.EXAMPLE
  .\updateTags.ps1 -inputCsv .\rg-list.csv -tagKey Environment -tagValue Prod -WhatIf

#>
[CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact='Medium')]
Param (
  [Parameter(Mandatory)][ValidateNotNullOrEmpty()][ValidateScript({ Test-Path $_ })][string]$inputCsv,
  [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$tagKey,
  [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$tagValue
)

Import-Module Az.Resources -ErrorAction Stop

# Ensure auth
try {
  if (-not (Get-AzContext)) {
    Connect-AzAccount | Out-Null
  }
} catch {
  Write-Error "Cannot authenticate to Azure: $_"
  exit 1
}

# Load CSV
$csv = Import-Csv $inputCsv
$results = @()

foreach ($batch in $csv | Group-Object SubscriptionId) {
  $sub = $batch.Name
  try {
    Set-AzContext -SubscriptionId $sub -ErrorAction Stop
  } catch {
    Write-Warning "Cannot set context to subscription $($sub): $($_)"
    continue
  }

  foreach ($row in $batch.Group) {
    $rg = $row.ResourceGroupName
    $resId = "/subscriptions/$sub/resourceGroups/$rg"
    $record = [PSCustomObject]@{
      Subscription = $sub
      ResourceGroup = $rg
      Status    = $null
      Message   = $null
    }

    if ($PSCmdlet.ShouldProcess($resId, "Merge tag $tagKey=$tagValue")) {
      try {
        # Fetch existing tags from RG
        $rgObj = Get-AzResourceGroup -Name $rg -ErrorAction Stop
        $tags  = $null
        if ($rgObj.Tags) {
          $tags = $rgObj.Tags.Clone()
        } else {
          $tags = @{}
        }
        $tags[$tagKey] = $tagValue

        # Retry wrapper
        $maxRetries = 3
        $success = $false
        for ($attempt = 1; $attempt -le $maxRetries; $attempt++) {
          try {
            Update-AzTag -ResourceId $resId -Tag $tags -Operation Merge -ErrorAction Stop
            $success = $true
            break
          } catch {
            if ($attempt -eq $maxRetries) {
              throw
            }
            Start-Sleep -Seconds ([math]::Pow(2, $attempt))
          }
        }

        if ($success) {
          $record.Status  = 'Success'
        } else {
          $record.Status  = 'Failed'
          $record.Message = "Unknown error during tag update."
        }
      } catch {
        $record.Status  = 'Failed'
        $record.Message = $_.Exception.Message
      }
    }

    $results += $record
  }
}

# Summary
$results | Format-Table -AutoSize
# Optionally:
# $results | Export-Csv updated-tags-report.csv -NoType

if ($results | Where-Object { $_.Status -eq 'Failed' }) { exit 1}
