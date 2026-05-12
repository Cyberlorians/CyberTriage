#Requires -Version 5.1
<#
.SYNOPSIS
    Grants Microsoft Defender for Endpoint app roles to the CyberTriage
    Logic App managed identities. Run this as a Microsoft Entra admin
    after the ARM template has deployed.

.DESCRIPTION
    The ARM template can assign Azure RBAC. It cannot grant Defender app
    roles, because those live in Microsoft Entra ID on the
    WindowsDefenderATP enterprise application.

    The script finds the Logic App managed identities by their fixed
    template names and assigns the required MDE app roles via Microsoft
    Graph. It uses the active Azure CLI session and cloud profile, so it
    works in Azure Commercial and Azure Government.

.PERMISSIONS
    A Microsoft Entra role that can assign app roles to service principals,
    commonly Global Administrator, Privileged Role Administrator,
    Cloud Application Administrator, or Application Administrator.

.EXAMPLE
    az login
    .\Grant-CyberTriageDefenderRoles.ps1
#>

$ErrorActionPreference = 'Stop'

# WindowsDefenderATP enterprise app
$defenderAppId = 'fc780465-2017-40d4-a0c5-307022471b92'

# Logic App name -> MDE app roles required
$grants = @{
    'Set-CyberTriage'                     = @('Machine.ReadWrite.All')
    'CyberTriage-LiveResponse-Collection' = @('Machine.Read.All', 'Machine.ReadWrite.All', 'Machine.LiveResponse')
}

# Cloud-aware Microsoft Graph endpoint
$graph = (az cloud show --query endpoints.microsoftGraphResourceId -o tsv).TrimEnd('/')
if (-not $graph) { $graph = 'https://graph.microsoft.com' }

# Resolve Defender service principal once
$defenderSp = az ad sp show --id $defenderAppId -o json | ConvertFrom-Json
if (-not $defenderSp) { throw "WindowsDefenderATP service principal not found in this tenant." }

foreach ($workflowName in $grants.Keys) {
    Write-Host ""
    Write-Host "== $workflowName =="

    $miId = az resource list --resource-type Microsoft.Logic/workflows `
        --query "[?name=='$workflowName'].identity.principalId | [0]" -o tsv
    if (-not $miId) {
        Write-Warning "Logic App '$workflowName' not found or has no managed identity. Skipping."
        continue
    }
    Write-Host "Managed identity: $miId"

    $listUrl  = "$graph/v1.0/servicePrincipals/$miId/appRoleAssignments"
    $existing = az rest --method get --url $listUrl -o json | ConvertFrom-Json

    foreach ($roleValue in $grants[$workflowName]) {
        $role = $defenderSp.appRoles |
            Where-Object { $_.value -eq $roleValue -and $_.allowedMemberTypes -contains 'Application' -and $_.isEnabled } |
            Select-Object -First 1
        if (-not $role) {
            Write-Warning "Role '$roleValue' not found on WindowsDefenderATP. Skipping."
            continue
        }

        if ($existing.value | Where-Object { $_.resourceId -eq $defenderSp.id -and $_.appRoleId -eq $role.id }) {
            Write-Host "  [skip] $roleValue already assigned"
            continue
        }

        $body = @{ principalId = $miId; resourceId = $defenderSp.id; appRoleId = $role.id } | ConvertTo-Json -Compress
        $bodyFile = New-TemporaryFile
        try {
            [System.IO.File]::WriteAllText($bodyFile.FullName, $body)
            az rest --method post --url $listUrl --headers 'Content-Type=application/json' --body "@$($bodyFile.FullName)" --only-show-errors | Out-Null
            if ($LASTEXITCODE -ne 0) {
                Write-Warning "  [fail] $roleValue not granted (az rest exit $LASTEXITCODE)"
            } else {
                Write-Host "  [ok]   $roleValue granted"
            }
        }
        finally {
            Remove-Item $bodyFile.FullName -ErrorAction SilentlyContinue
        }
    }
}

Write-Host ""
Write-Host "Done."
