#Requires -Version 5.1
<#
.SYNOPSIS
    Grants CyberTriage managed identity permissions after the ARM templates deploy.

.DESCRIPTION
    This script is for the administrator who is allowed to assign permissions.
    In many customers, the person who clicks Deploy to Azure can create the
    Logic Apps and Function App, but cannot assign RBAC roles or Entra app roles.

    Run this after the resources exist.

    The script grants Azure RBAC roles to the system-assigned managed identities
    used by the SAS broker Function and the three Logic Apps.

    Optional: with -GrantDefenderAppRoles, the script also grants Microsoft
    Defender for Endpoint application roles to the Logic App managed identities
    through Microsoft Graph. Use that option only for a raw-HTTP managed identity
    MDE design, or when your template version requires direct MDE API calls by
    the workflow identity. The current connector-based templates may still need
    API connection authorization in the Azure portal.

.PERMISSIONS REQUIRED TO RUN
    Azure RBAC role assignment section:
      - Owner OR User Access Administrator at each target scope.

    Defender app role section (-GrantDefenderAppRoles):
      - A tenant role that can assign app roles to service principals, commonly
        Global Administrator, Privileged Role Administrator, Cloud Application
        Administrator, or Application Administrator depending on tenant policy.
      - Azure CLI must be signed in to the same tenant.

.NOTES
    This script does not print secrets, SAS URLs, storage keys, or function keys.
#>
[CmdletBinding(SupportsShouldProcess = $true)]
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
    [string]$EvidenceStorageResourceGroup,

    [Parameter(Mandatory = $true)]
    [string]$EvidenceStorageAccountName,

    [Parameter(Mandatory = $true)]
    [string]$FunctionHostStorageResourceGroup,

    [Parameter(Mandatory = $true)]
    [string]$FunctionHostStorageAccountName,

    [Parameter(Mandatory = $true)]
    [string]$SasBrokerFunctionAppName,

    [string]$SetWorkflowName = 'Set-CyberTriage',

    [string]$QueueWorkflowName = 'Check-CyberTriageQueue',

    [string]$CollectionWorkflowName = 'CyberTriage-LiveResponse-Collection',

    [switch]$IncludeHostStorageOwnerRoles,

    [switch]$GrantDefenderAppRoles,

    [string[]]$DefenderAppRoles = @('Machine.Read.All', 'Machine.ReadWrite.All')
)

$ErrorActionPreference = 'Stop'

function Write-Section {
    param([string]$Name)
    Write-Host ''
    Write-Host "== $Name =="
}

function Invoke-AzCliJson {
    param([Parameter(Mandatory = $true)][string[]]$Arguments)

    $output = & az @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    $outputText = $output -join [Environment]::NewLine

    if ($exitCode -ne 0) {
        throw "Azure CLI command failed ($exitCode): az $($Arguments -join ' ')$([Environment]::NewLine)$outputText"
    }
    if ([string]::IsNullOrWhiteSpace($outputText)) {
        return $null
    }
    return $outputText | ConvertFrom-Json
}

function Get-RequiredPrincipalId {
    param(
        [Parameter(Mandatory = $true)][string]$Kind,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$ResourceGroup
    )

    if ($Kind -eq 'FunctionApp') {
        $principalId = az functionapp identity show --resource-group $ResourceGroup --name $Name --query principalId -o tsv
    } elseif ($Kind -eq 'LogicApp') {
        $principalId = az logic workflow show --resource-group $ResourceGroup --name $Name --query identity.principalId -o tsv
    } else {
        throw "Unknown principal kind: $Kind"
    }

    if ([string]::IsNullOrWhiteSpace($principalId)) {
        throw "$Kind '$Name' in resource group '$ResourceGroup' does not have a system-assigned managed identity."
    }

    return $principalId.Trim()
}

function Grant-AzureRoleIfMissing {
    param(
        [Parameter(Mandatory = $true)][string]$PrincipalId,
        [Parameter(Mandatory = $true)][string]$RoleName,
        [Parameter(Mandatory = $true)][string]$Scope,
        [Parameter(Mandatory = $true)][string]$Reason
    )

    $existing = az role assignment list --assignee $PrincipalId --scope $Scope --role $RoleName --query '[].id' -o tsv
    if ($existing) {
        Write-Host "Already assigned: $RoleName -> $PrincipalId"
        return
    }

    Write-Host "Granting: $RoleName -> $PrincipalId"
    Write-Host "Reason: $Reason"

    if ($PSCmdlet.ShouldProcess($PrincipalId, "Grant $RoleName on $Scope")) {
        az role assignment create `
            --assignee-object-id $PrincipalId `
            --assignee-principal-type ServicePrincipal `
            --role $RoleName `
            --scope $Scope `
            --only-show-errors | Out-Null
    }
}

function Grant-DefenderAppRoleIfMissing {
    param(
        [Parameter(Mandatory = $true)][string]$PrincipalId,
        [Parameter(Mandatory = $true)][string]$RoleValue
    )

    $defenderAppId = 'fc780465-2017-40d4-a0c5-307022471b92'
    $defenderSp = Invoke-AzCliJson @('ad', 'sp', 'show', '--id', $defenderAppId, '-o', 'json')
    $role = $defenderSp.appRoles | Where-Object { $_.value -eq $RoleValue -and $_.allowedMemberTypes -contains 'Application' -and $_.isEnabled }

    if (-not $role) {
        Write-Warning "Defender app role '$RoleValue' was not found on the WindowsDefenderATP service principal in this tenant. Skipping."
        return
    }

    $existingUrl = "https://graph.microsoft.com/v1.0/servicePrincipals/$PrincipalId/appRoleAssignments"
    $existing = Invoke-AzCliJson @('rest', '--method', 'get', '--url', $existingUrl, '-o', 'json')
    $alreadyAssigned = $existing.value | Where-Object { $_.resourceId -eq $defenderSp.id -and $_.appRoleId -eq $role.id }
    if ($alreadyAssigned) {
        Write-Host "Already assigned Defender app role: $RoleValue -> $PrincipalId"
        return
    }

    $body = @{
        principalId = $PrincipalId
        resourceId  = $defenderSp.id
        appRoleId   = $role.id
    } | ConvertTo-Json -Compress

    Write-Host "Granting Defender app role: $RoleValue -> $PrincipalId"
    if ($PSCmdlet.ShouldProcess($PrincipalId, "Grant Defender app role $RoleValue")) {
        az rest --method post --url $existingUrl --headers 'Content-Type=application/json' --body $body --only-show-errors | Out-Null
    }
}

Write-Section 'Set subscription'
az account set --subscription $SubscriptionId | Out-Null

Write-Section 'Resolve resource scopes'
$evidenceStorage = Invoke-AzCliJson @('storage', 'account', 'show', '--resource-group', $EvidenceStorageResourceGroup, '--name', $EvidenceStorageAccountName, '-o', 'json')
$hostStorage = Invoke-AzCliJson @('storage', 'account', 'show', '--resource-group', $FunctionHostStorageResourceGroup, '--name', $FunctionHostStorageAccountName, '-o', 'json')
$workspace = Invoke-AzCliJson @('monitor', 'log-analytics', 'workspace', 'show', '--resource-group', $SentinelResourceGroup, '--workspace-name', $SentinelWorkspaceName, '-o', 'json')

$evidenceStorageScope = $evidenceStorage.id
$hostStorageScope = $hostStorage.id
$workspaceScope = $workspace.id

Write-Host "Evidence storage scope: $evidenceStorageScope"
Write-Host "Function host storage scope: $hostStorageScope"
Write-Host "Sentinel workspace scope: $workspaceScope"

Write-Section 'Resolve managed identities'
$brokerPrincipalId = Get-RequiredPrincipalId -Kind FunctionApp -Name $SasBrokerFunctionAppName -ResourceGroup $PlaybookResourceGroup
$setPrincipalId = Get-RequiredPrincipalId -Kind LogicApp -Name $SetWorkflowName -ResourceGroup $PlaybookResourceGroup
$queuePrincipalId = Get-RequiredPrincipalId -Kind LogicApp -Name $QueueWorkflowName -ResourceGroup $PlaybookResourceGroup
$collectionPrincipalId = Get-RequiredPrincipalId -Kind LogicApp -Name $CollectionWorkflowName -ResourceGroup $PlaybookResourceGroup

[pscustomobject]@{
    SasBrokerFunctionApp = $brokerPrincipalId
    SetCyberTriage       = $setPrincipalId
    CheckQueue           = $queuePrincipalId
    Collection           = $collectionPrincipalId
} | Format-List

Write-Section 'Grant SAS broker storage roles'
Grant-AzureRoleIfMissing -PrincipalId $brokerPrincipalId -RoleName 'Storage Blob Delegator' -Scope $evidenceStorageScope -Reason 'Broker must request user delegation keys for user-delegation SAS.'
Grant-AzureRoleIfMissing -PrincipalId $brokerPrincipalId -RoleName 'Storage Blob Data Contributor' -Scope $evidenceStorageScope -Reason 'Broker must create scoped container SAS for collector upload.'

Write-Section 'Grant Function host storage roles'
Grant-AzureRoleIfMissing -PrincipalId $brokerPrincipalId -RoleName 'Storage Blob Data Contributor' -Scope $hostStorageScope -Reason 'Function host storage blob access for managed-identity host storage.'
Grant-AzureRoleIfMissing -PrincipalId $brokerPrincipalId -RoleName 'Storage Queue Data Contributor' -Scope $hostStorageScope -Reason 'Function host storage queue access for managed-identity host storage.'
Grant-AzureRoleIfMissing -PrincipalId $brokerPrincipalId -RoleName 'Storage Table Data Contributor' -Scope $hostStorageScope -Reason 'Function host storage table access for managed-identity host storage.'

if ($IncludeHostStorageOwnerRoles) {
    Grant-AzureRoleIfMissing -PrincipalId $brokerPrincipalId -RoleName 'Storage Blob Data Owner' -Scope $hostStorageScope -Reason 'Lab-proven broader host storage role; use only if minimum host roles fail.'
    Grant-AzureRoleIfMissing -PrincipalId $brokerPrincipalId -RoleName 'Storage Account Contributor' -Scope $hostStorageScope -Reason 'Lab-proven broader host storage role; use only if minimum host roles fail.'
}

Write-Section 'Grant Sentinel and Log Analytics roles'
Grant-AzureRoleIfMissing -PrincipalId $setPrincipalId -RoleName 'Microsoft Sentinel Contributor' -Scope $workspaceScope -Reason 'Set-CyberTriage writes watchlist queue rows and reads incident entity context.'
Grant-AzureRoleIfMissing -PrincipalId $queuePrincipalId -RoleName 'Log Analytics Reader' -Scope $workspaceScope -Reason 'Queue checker queries Watchlist and DeviceInfo telemetry.'
Grant-AzureRoleIfMissing -PrincipalId $queuePrincipalId -RoleName 'Microsoft Sentinel Contributor' -Scope $workspaceScope -Reason 'Queue checker deletes duplicate watchlist items and dispatches current queue rows.'
Grant-AzureRoleIfMissing -PrincipalId $collectionPrincipalId -RoleName 'Microsoft Sentinel Contributor' -Scope $workspaceScope -Reason 'Collection playbook updates blocked queue rows and deletes queue rows after LR handoff.'

if ($GrantDefenderAppRoles) {
    Write-Section 'Grant optional Defender for Endpoint application roles'
    foreach ($principalId in @($setPrincipalId, $collectionPrincipalId)) {
        foreach ($roleValue in $DefenderAppRoles) {
            Grant-DefenderAppRoleIfMissing -PrincipalId $principalId -RoleValue $roleValue
        }
    }
} else {
    Write-Section 'Defender app roles skipped'
    Write-Host 'Skipped Defender app role grants because -GrantDefenderAppRoles was not supplied.'
    Write-Host 'The connector-based templates may still require API connection authorization in the Azure portal.'
}

Write-Section 'Done'
Write-Host 'Permission assignment pass completed.'
Write-Host 'If any API connections still show unauthorized in Azure Portal, authorize those connector connections separately.'
