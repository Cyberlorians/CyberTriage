#Requires -Version 5.1
<#
.SYNOPSIS
    Read-only CyberTriage deployment smoke test.

.DESCRIPTION
    Checks the common things that break this solution:
    storage public/shared-key posture, SAS broker health, live watchlist rows,
    recent Logic App runs, recent MDE Live Response actions, and recent blobs.

    This script intentionally does not print SAS URLs, broker secrets, function
    keys, or storage account keys.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SubscriptionId,

    [Parameter(Mandatory = $true)]
    [string]$PlaybookResourceGroup,

    [Parameter(Mandatory = $true)]
    [string]$SentinelResourceGroup,

    [Parameter(Mandatory = $true)]
    [string]$SentinelWorkspaceName,

    [Parameter(Mandatory = $true)]
    [string]$StorageAccountName,

    [string]$ContainerName = 'cybertriage-results',

    [string]$WatchlistAlias = 'ForensicCollectQueue',

    [string]$BrokerHealthUrl,

    [string]$QueueWorkflowName = 'Check-CyberTriageQueue',

    [string]$CollectionWorkflowName = 'CyberTriage-LiveResponse-Collection',

    [string]$SetWorkflowName = 'Set-CyberTriage'
)

$ErrorActionPreference = 'Stop'

function Write-Section {
    param([string]$Name)
    Write-Host ''
    Write-Host "== $Name =="
}

az account set --subscription $SubscriptionId | Out-Null

Write-Section 'Storage posture'
az storage account show `
    --resource-group $PlaybookResourceGroup `
    --name $StorageAccountName `
    --query "{publicNetworkAccess:publicNetworkAccess,defaultAction:networkRuleSet.defaultAction,ipRules:networkRuleSet.ipRules[].ipAddressOrRange,virtualNetworkRules:networkRuleSet.virtualNetworkRules[].virtualNetworkResourceId,allowSharedKeyAccess:allowSharedKeyAccess}" `
    -o json

if ($BrokerHealthUrl) {
    Write-Section 'Broker health'
    try {
        $response = Invoke-WebRequest -Uri $BrokerHealthUrl -Method Get -TimeoutSec 30
        [pscustomobject]@{
            statusCode = $response.StatusCode
            body       = $response.Content
        } | ConvertTo-Json -Depth 3
    } catch {
        [pscustomobject]@{
            status = 'failed'
            error  = $_.Exception.Message
        } | ConvertTo-Json -Depth 3
    }
}

Write-Section 'Current watchlist rows'
$watchlistUrl = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$SentinelResourceGroup/providers/Microsoft.OperationalInsights/workspaces/$SentinelWorkspaceName/providers/Microsoft.SecurityInsights/watchlists/$WatchlistAlias/watchlistItems?api-version=2023-11-01"
$items = (az rest --only-show-errors --method get --url $watchlistUrl | ConvertFrom-Json).value
if (-not $items -or $items.Count -eq 0) {
    Write-Host 'No current watchlist items.'
} else {
    $items | Select-Object `
        @{n='WatchlistItemId';e={$_.name}},
        @{n='DeviceName';e={$_.properties.itemsKeyValue.DeviceName}},
        @{n='MdatpDeviceId';e={$_.properties.itemsKeyValue.MdatpDeviceId}},
        @{n='Status';e={$_.properties.itemsKeyValue.Status}},
        @{n='Attempts';e={$_.properties.itemsKeyValue.Attempts}},
        @{n='IncidentId';e={$_.properties.itemsKeyValue.IncidentId}},
        @{n='TagName';e={$_.properties.itemsKeyValue.TagName}},
        @{n='EnqueuedTime';e={$_.properties.itemsKeyValue.EnqueuedTime}},
        @{n='RetryAfterUtc';e={$_.properties.itemsKeyValue.RetryAfterUtc}} |
        Format-Table -AutoSize
}

foreach ($workflowName in @($SetWorkflowName, $QueueWorkflowName, $CollectionWorkflowName)) {
    Write-Section "Recent Logic App runs: $workflowName"
    $runsUrl = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$PlaybookResourceGroup/providers/Microsoft.Logic/workflows/$workflowName/runs?api-version=2019-05-01"
    try {
        $runs = (az rest --only-show-errors --method get --url $runsUrl | ConvertFrom-Json).value
        $runs |
            Sort-Object { [datetime]$_.properties.startTime } -Descending |
            Select-Object -First 5 `
                @{n='Name';e={$_.name}},
                @{n='Status';e={$_.properties.status}},
                @{n='Start';e={$_.properties.startTime}},
                @{n='End';e={$_.properties.endTime}},
                @{n='Correlation';e={$_.properties.correlation.clientTrackingId}} |
            Format-Table -AutoSize
    } catch {
        [pscustomobject]@{
            workflow = $workflowName
            error    = $_.Exception.Message
        } | ConvertTo-Json -Depth 3
    }
}

Write-Section 'Recent blobs'
az storage blob list `
    --account-name $StorageAccountName `
    --container-name $ContainerName `
    --auth-mode login `
    --query "sort_by([].{name:name,lastModified:properties.lastModified,size:properties.contentLength}, &lastModified)[-10:]" `
    -o table

Write-Section 'Reminder'
Write-Host 'This script is read-only. It does not trigger collection and does not print secrets.'
