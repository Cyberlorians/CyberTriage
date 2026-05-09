# Admin Permission Handoff

Use this page when the person deploying the ARM templates cannot assign managed identity permissions.

For the full click-by-click and command-by-command permission setup, see [setting-permissions-step-by-step.md](setting-permissions-step-by-step.md).

Simplest option: have an account with `Owner` on the subscription run the full commercial deployment. In that case, the ARM template assigns the Azure RBAC roles automatically.

Use this handoff only when the customer will not let the deployment operator use `Owner`, or when role assignment is handled by a separate admin team.

The deployment can be done in two passes:

1. Deployment operator clicks the ARM deployment buttons.
2. Permission admin runs the permission script after the resources exist.

## What The Deployment Operator Sends To The Admin

Send these values to the Azure RBAC admin:

```text
Subscription ID
Playbook resource group
Sentinel workspace resource group
Sentinel workspace name
Evidence storage account resource group
Evidence storage account name
Function host storage account resource group
Function host storage account name
SAS broker Function App name
Set-CyberTriage Logic App name
Check-CyberTriageQueue Logic App name
CyberTriage-LiveResponse-Collection Logic App name
```

Default Logic App names:

```text
Set-CyberTriage
Check-CyberTriageQueue
CyberTriage-LiveResponse-Collection
```

## What The Azure RBAC Admin Needs

The Azure RBAC admin needs one of these at the target scopes:

```text
Owner
User Access Administrator
```

Target scopes are usually:

```text
Evidence storage account
Function host storage account
Sentinel / Log Analytics workspace
```

## Azure RBAC Admin Command

From the repo root:

```powershell
.\scripts\Grant-CyberTriagePermissions.ps1 `
  -SubscriptionId '<subscription-guid>' `
  -PlaybookResourceGroup '<playbook-resource-group>' `
  -SentinelResourceGroup '<sentinel-resource-group>' `
  -SentinelWorkspaceName '<sentinel-workspace-name>' `
  -EvidenceStorageResourceGroup '<storage-resource-group>' `
  -EvidenceStorageAccountName '<evidence-storage-account>' `
  -FunctionHostStorageResourceGroup '<function-host-storage-resource-group>' `
  -FunctionHostStorageAccountName '<function-host-storage-account>' `
  -SasBrokerFunctionAppName '<sas-broker-function-app>'
```

Preview mode:

```powershell
.\scripts\Grant-CyberTriagePermissions.ps1 <same parameters> -WhatIf
```

If Function host storage still fails after minimum roles, rerun with:

```powershell
-IncludeHostStorageOwnerRoles
```

Use that only if needed, because it grants broader host storage permissions.

## What The Script Grants

The script grants the SAS broker Function identity these evidence-storage roles:

```text
Storage Blob Delegator on evidence storage
Storage Blob Data Contributor on evidence storage
```

The script also grants the SAS broker Function identity these Function host-storage roles. These are for the Azure Functions runtime storage account, not for the `ForensicCollectQueue` Sentinel watchlist.

```text
Storage Blob Data Contributor on Function host storage
Storage Queue Data Contributor on Function host storage
Storage Table Data Contributor on Function host storage
```

The script grants the Logic App identities:

```text
Set-CyberTriage:
  Microsoft Sentinel Contributor on the Sentinel workspace

Check-CyberTriageQueue:
  Log Analytics Reader on the Sentinel workspace
  Microsoft Sentinel Contributor on the Sentinel workspace

CyberTriage-LiveResponse-Collection:
  Microsoft Sentinel Contributor on the Sentinel workspace
```

## What The Entra Admin May Need To Do

This is required for the current commercial templates because MDE calls use raw HTTP with Logic App managed identity.

The MDE app roles live on the WindowsDefenderATP Enterprise App in Entra ID. They are not Azure RBAC roles.

If the same admin has both Azure RBAC assignment rights and Entra app-role assignment rights, they can run the main script once:

```powershell
.\scripts\Grant-CyberTriagePermissions.ps1 <same parameters>
```

If the Azure RBAC admin does not have Entra app-role assignment rights, they should run the script with `-SkipDefenderAppRoles`, then the Entra admin grants these app roles manually:

```text
Set-CyberTriage managed identity:
  Machine.ReadWrite.All

CyberTriage-LiveResponse-Collection managed identity:
  Machine.Read.All
  Machine.ReadWrite.All
  Machine.LiveResponse

Check-CyberTriageQueue managed identity:
  No MDE app roles
```

The queue checker does not call MDE directly, so it does not receive MDE app roles.

The Entra admin may need one of these roles, depending on tenant policy:

```text
Global Administrator
Privileged Role Administrator
Cloud Application Administrator
Application Administrator
```

The script dynamically looks up the Defender app role IDs on the WindowsDefenderATP service principal.

## What The MDE Admin Still Needs To Do

The MDE admin must make sure:

```text
Live Response is enabled
The account or connector can run Live Response
The account or connector can add/remove machine tags
CyberTriageCollector.exe is uploaded to the Live Response Library
Run-CyberTriage.ps1 is uploaded to the Live Response Library
The target endpoint is Active in MDE before testing
```

## What The Deployer Checks After Admin Work

After the admin finishes, run:

```powershell
.\scripts\Test-CyberTriageDeployment.ps1 `
  -SubscriptionId '<subscription-guid>' `
  -PlaybookResourceGroup '<playbook-resource-group>' `
  -SentinelResourceGroup '<sentinel-resource-group>' `
  -SentinelWorkspaceName '<sentinel-workspace-name>' `
  -StorageAccountName '<evidence-storage-account>' `
  -BrokerHealthUrl 'https://<function-app>.azurewebsites.net/api/health'
```

Then run one manual test against an MDE Active device.
