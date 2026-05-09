# Setting Permissions Step By Step

Use this page after the ARM templates create the Function App and Logic Apps.

This page answers the practical question: where do I click, and what role do I assign?

## Before You Start

You need these names:

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

The person setting Azure RBAC permissions needs one of these roles at the target scopes:

```text
Owner
User Access Administrator
```

The target scopes are usually:

```text
Evidence storage account
Function host storage account
Sentinel / Log Analytics workspace
```

## Fast Method: Run The Permission Script

From the repo root, run:

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

To preview without changing anything:

```powershell
.\scripts\Grant-CyberTriagePermissions.ps1 <same parameters> -WhatIf
```

That script sets these Azure RBAC permissions:

| Identity | Scope | Roles |
|---|---|---|
| SAS broker Function managed identity | Evidence storage account | Storage Blob Delegator; Storage Blob Data Contributor |
| SAS broker Function managed identity | Function host storage account | Storage Blob Data Contributor; Storage Queue Data Contributor; Storage Table Data Contributor |
| Set-CyberTriage managed identity | Sentinel workspace | Microsoft Sentinel Contributor |
| Check-CyberTriageQueue managed identity | Sentinel workspace | Log Analytics Reader; Microsoft Sentinel Contributor |
| CyberTriage-LiveResponse-Collection managed identity | Sentinel workspace | Microsoft Sentinel Contributor |

## Manual Method: Azure Portal

Use this if the customer does not want to run a script.

### Step 1: Find The SAS Broker Managed Identity

1. Open the Azure portal.
2. Go to the SAS broker Function App.
3. Open `Identity`.
4. Make sure `System assigned` is `On`.
5. Copy the `Object (principal) ID`.

That identity is the identity that needs storage permissions.

### Step 2: Set Evidence Storage Permissions

1. Go to the evidence storage account.
2. Open `Access control (IAM)`.
3. Select `Add`.
4. Select `Add role assignment`.
5. Search for `Storage Blob Delegator`.
6. Select the role.
7. For `Assign access to`, choose `Managed identity`.
8. Select the SAS broker Function App managed identity.
9. Review and assign.
10. Repeat the same steps for `Storage Blob Data Contributor`.

When this is done, the SAS broker can request a user delegation key and create the short-lived SAS URL.

### Step 3: Set Function Host Storage Permissions

1. Go to the Function host storage account.
2. Open `Access control (IAM)`.
3. Add these role assignments to the SAS broker Function App managed identity:

```text
Storage Blob Data Contributor
Storage Queue Data Contributor
Storage Table Data Contributor
```

If the Function host still cannot start with managed identity storage, an admin can temporarily add the broader troubleshooting roles listed below:

```text
Storage Blob Data Owner
Storage Account Contributor
```

Use the broader roles only if the minimum host storage roles are not enough for the selected Function hosting model.

### Step 4: Find The Logic App Managed Identities

For each Logic App:

1. Open the Logic App in the Azure portal.
2. Open `Identity`.
3. Make sure `System assigned` is `On`.
4. Copy the `Object (principal) ID`.

Do this for:

```text
Set-CyberTriage
Check-CyberTriageQueue
CyberTriage-LiveResponse-Collection
```

### Step 5: Set Sentinel Workspace Permissions

Go to the Sentinel workspace's Log Analytics workspace resource.

Open:

```text
Access control (IAM)
```

Add these role assignments:

| Logic App Identity | Role |
|---|---|
| Set-CyberTriage | Microsoft Sentinel Contributor |
| Check-CyberTriageQueue | Log Analytics Reader |
| Check-CyberTriageQueue | Microsoft Sentinel Contributor |
| CyberTriage-LiveResponse-Collection | Microsoft Sentinel Contributor |

Why these are needed:

```text
Set-CyberTriage writes queue rows to the watchlist.
Check-CyberTriageQueue queries Watchlist and DeviceInfo, then removes duplicate rows.
CyberTriage-LiveResponse-Collection updates or deletes queue rows after handoff.
```

### Step 6: Authorize Logic App API Connections

Azure RBAC is not the same thing as connector authorization.

Open each Logic App and check its API connections.

Connections that may need authorization:

```text
azuresentinel
wdatp
office365
azuremonitorlogs
azureblob
```

For each connection:

1. Open the API connection resource.
2. Select `Edit API connection`.
3. Select `Authorize` or sign in if the portal shows an authorization button.
4. Save the connection.
5. Return to the Logic App and confirm the action no longer says unauthorized.

The `wdatp` connection is the Microsoft Defender for Endpoint connection. If it is not authorized, MDE tagging or Live Response actions can fail even when Azure RBAC roles are correct.

### Step 7: Set Optional Defender App Roles

Do this only if the deployment uses raw HTTP actions with managed identity to call MDE.

The current commercial templates use WDATP connector actions for MDE operations, so most customers authorize the connector instead.

If raw HTTP managed identity is used, an Entra admin can run:

```powershell
.\scripts\Grant-CyberTriagePermissions.ps1 <same parameters> -GrantDefenderAppRoles
```

That grants Defender app roles to:

```text
Set-CyberTriage
CyberTriage-LiveResponse-Collection
```

The queue checker does not call MDE directly.

## Manual Method: Azure CLI Commands

Use these commands if you want to set the same permissions without using the helper script.

Set variables first:

```powershell
$SubscriptionId = '<subscription-guid>'
$PlaybookResourceGroup = '<playbook-resource-group>'
$SentinelResourceGroup = '<sentinel-resource-group>'
$SentinelWorkspaceName = '<sentinel-workspace-name>'
$EvidenceStorageResourceGroup = '<storage-resource-group>'
$EvidenceStorageAccountName = '<evidence-storage-account>'
$FunctionHostStorageResourceGroup = '<function-host-storage-resource-group>'
$FunctionHostStorageAccountName = '<function-host-storage-account>'
$SasBrokerFunctionAppName = '<sas-broker-function-app>'
$SetWorkflowName = 'Set-CyberTriage'
$QueueWorkflowName = 'Check-CyberTriageQueue'
$CollectionWorkflowName = 'CyberTriage-LiveResponse-Collection'

az account set --subscription $SubscriptionId
```

Resolve identities and scopes:

```powershell
$BrokerPrincipalId = az functionapp identity show --resource-group $PlaybookResourceGroup --name $SasBrokerFunctionAppName --query principalId -o tsv
$SetPrincipalId = az logic workflow show --resource-group $PlaybookResourceGroup --name $SetWorkflowName --query identity.principalId -o tsv
$QueuePrincipalId = az logic workflow show --resource-group $PlaybookResourceGroup --name $QueueWorkflowName --query identity.principalId -o tsv
$CollectionPrincipalId = az logic workflow show --resource-group $PlaybookResourceGroup --name $CollectionWorkflowName --query identity.principalId -o tsv

$EvidenceStorageScope = az storage account show --resource-group $EvidenceStorageResourceGroup --name $EvidenceStorageAccountName --query id -o tsv
$HostStorageScope = az storage account show --resource-group $FunctionHostStorageResourceGroup --name $FunctionHostStorageAccountName --query id -o tsv
$WorkspaceScope = az monitor log-analytics workspace show --resource-group $SentinelResourceGroup --workspace-name $SentinelWorkspaceName --query id -o tsv
```

Grant SAS broker roles on evidence storage:

```powershell
az role assignment create --assignee-object-id $BrokerPrincipalId --assignee-principal-type ServicePrincipal --role 'Storage Blob Delegator' --scope $EvidenceStorageScope
az role assignment create --assignee-object-id $BrokerPrincipalId --assignee-principal-type ServicePrincipal --role 'Storage Blob Data Contributor' --scope $EvidenceStorageScope
```

Grant Function host storage roles:

```powershell
az role assignment create --assignee-object-id $BrokerPrincipalId --assignee-principal-type ServicePrincipal --role 'Storage Blob Data Contributor' --scope $HostStorageScope
az role assignment create --assignee-object-id $BrokerPrincipalId --assignee-principal-type ServicePrincipal --role 'Storage Queue Data Contributor' --scope $HostStorageScope
az role assignment create --assignee-object-id $BrokerPrincipalId --assignee-principal-type ServicePrincipal --role 'Storage Table Data Contributor' --scope $HostStorageScope
```

Grant Sentinel workspace roles:

```powershell
az role assignment create --assignee-object-id $SetPrincipalId --assignee-principal-type ServicePrincipal --role 'Microsoft Sentinel Contributor' --scope $WorkspaceScope

az role assignment create --assignee-object-id $QueuePrincipalId --assignee-principal-type ServicePrincipal --role 'Log Analytics Reader' --scope $WorkspaceScope
az role assignment create --assignee-object-id $QueuePrincipalId --assignee-principal-type ServicePrincipal --role 'Microsoft Sentinel Contributor' --scope $WorkspaceScope

az role assignment create --assignee-object-id $CollectionPrincipalId --assignee-principal-type ServicePrincipal --role 'Microsoft Sentinel Contributor' --scope $WorkspaceScope
```

## How To Check The Permissions

For a managed identity and scope, run:

```powershell
az role assignment list --assignee '<managed-identity-object-id>' --scope '<resource-id>' --output table
```

At minimum, confirm:

```text
SAS broker has Storage Blob Delegator on evidence storage.
SAS broker has Storage Blob Data Contributor on evidence storage.
SAS broker has host storage data roles on Function host storage.
Set-CyberTriage has Microsoft Sentinel Contributor on the workspace.
Check-CyberTriageQueue has Log Analytics Reader and Microsoft Sentinel Contributor on the workspace.
CyberTriage-LiveResponse-Collection has Microsoft Sentinel Contributor on the workspace.
API connections show authorized in the Azure portal.
```

## Common Permission Mistakes

```text
Contributor cannot assign roles by itself. Use Owner or User Access Administrator for role assignments.
A managed identity object ID is not the same as the Azure resource ID.
Connector authorization is separate from Azure RBAC.
The MDE API token audience is not the same as the MDE API URL for raw HTTP managed identity designs.
A VM running in Azure is not enough. The endpoint must be Active in MDE for Live Response.
```
