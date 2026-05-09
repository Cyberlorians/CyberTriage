# Setting Permissions Step By Step

Use this page after the ARM templates create the Function App and Logic Apps.

This page answers the practical question: where do I click, and what role do I assign?

Recommended simple path: run the full commercial deployment with an account that is `Owner` on the subscription. Then the ARM template assigns the Azure RBAC permissions automatically. You use this page to understand what was assigned, to verify it, or to set permissions manually if the customer did not allow `Owner`.

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

The full commercial deployment creates these resources:

```text
Evidence storage account and cybertriage-results container
SAS broker Function App: the name entered during deployment
Collection Logic App: CyberTriage-LiveResponse-Collection
Incident tagging Logic App: Set-CyberTriage
Queue checker Logic App: Check-CyberTriageQueue
Watchlist alias to create: ForensicCollectQueue
```

The person running the full deployment should be:

```text
Owner on the subscription
```

That is the simplest path because the template can create resources and create role assignments in one run.

If permissions are set after deployment, the person setting Azure RBAC permissions needs one of these roles at the target scopes:

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

## Fast Method If Owner Was Not Used: Run The Permission Script

If the full deployment was not run by an `Owner`, or if role assignment failed, run this from the repo root:

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

## Manual Method: Azure Portal Step By Step

Use this if the customer does not want to run a script or if the full Owner deployment was not used.

### Set Permissions After Deployment Of The SAS Broker Function App

The SAS broker Function App creates the short-lived SAS URL. The Function App name is the name entered during deployment.

1. Open the Azure portal.
2. Go to the SAS broker Function App.
3. In the left menu, open `Settings` > `Identity`.
4. Make sure `System assigned` is `On`.
5. Copy the `Object (principal) ID`.
6. Go to the evidence storage account.
7. Open `Access control (IAM)`.
8. Select `Add` > `Add role assignment`.
9. Search for `Storage Blob Delegator`.
10. Select the role.
11. For `Assign access to`, choose `Managed identity`.
12. Select the SAS broker Function App managed identity.
13. Select `Review + assign`.
14. Repeat the same steps for `Storage Blob Data Contributor`.

When this is done, the SAS broker can request a user delegation key and create the short-lived SAS URL.

Now set the Function host storage permissions:

1. Go to the Function host storage account from the deployment.
2. Open `Access control (IAM)`.
3. Select `Add` > `Add role assignment`.
4. Add these roles to the same SAS broker Function App managed identity:

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

### Set Permissions After Deployment Of `CyberTriage-LiveResponse-Collection`

This Logic App starts MDE Live Response, removes the MDE tag, and deletes the watchlist row after handoff.

1. Open the Logic App in the Azure portal.
2. Open `CyberTriage-LiveResponse-Collection`.
3. In the left menu, open `Settings` > `Identity`.
4. Make sure `System assigned` is `On`.
5. Copy the `Object (principal) ID`.
6. Go to the Sentinel workspace's Log Analytics workspace resource.
7. Open `Access control (IAM)`.
8. Select `Add` > `Add role assignment`.
9. Add `Microsoft Sentinel Contributor` to the `CyberTriage-LiveResponse-Collection` managed identity.

### Set Permissions After Deployment Of `Set-CyberTriage`

This Logic App tags the MDE device and writes the queue row to the Sentinel watchlist.

1. Open the Logic App in the Azure portal.
2. Open `Set-CyberTriage`.
3. In the left menu, open `Settings` > `Identity`.
4. Make sure `System assigned` is `On`.
5. Copy the `Object (principal) ID`.
6. Go to the Sentinel workspace's Log Analytics workspace resource.
7. Open `Access control (IAM)`.
8. Select `Add` > `Add role assignment`.
9. Add `Microsoft Sentinel Contributor` to the `Set-CyberTriage` managed identity.

### Set Permissions After Deployment Of `Check-CyberTriageQueue`

This Logic App reads the queue, checks MDE activity telemetry, and calls the collection Logic App only for active devices.

1. Open the Logic App in the Azure portal.
2. Open `Check-CyberTriageQueue`.
3. In the left menu, open `Settings` > `Identity`.
4. Make sure `System assigned` is `On`.
5. Copy the `Object (principal) ID`.
6. Go to the Sentinel workspace's Log Analytics workspace resource.
7. Open `Access control (IAM)`.
8. Select `Add` > `Add role assignment`.
9. Add `Log Analytics Reader` to the `Check-CyberTriageQueue` managed identity.
10. Add `Microsoft Sentinel Contributor` to the `Check-CyberTriageQueue` managed identity.

### Authorize Logic App API Connections

Azure RBAC is not the same thing as connector authorization.

Open each Logic App and check its API connections.

Connections that may need authorization:

```text
wdatp-Set-CyberTriage
wdatp-CyberTriage-LiveResponse-Collection-cards
azuresentinel-Set-CyberTriage
azuresentinel-CyberTriage-LiveResponse-Collection
azuresentinel-Check-CyberTriageQueue
azuremonitorlogs-Check-CyberTriageQueue
office365-CyberTriage-LiveResponse-Collection
```

For each connection:

1. Open the API connection resource.
2. Select `Edit API connection`.
3. Select `Authorize` or sign in if the portal shows an authorization button.
4. Save the connection.
5. Return to the Logic App and confirm the action no longer says unauthorized.

The `wdatp` connection is the Microsoft Defender for Endpoint connection. If it is not authorized, MDE tagging or Live Response actions can fail even when Azure RBAC roles are correct.

The `office365-CyberTriage-LiveResponse-Collection` connection is only for email notification. Connect it if you want email notifications. If not, leave it unused or remove the email action.

### Create The Watchlist

Create a Microsoft Sentinel watchlist with this exact alias:

```text
ForensicCollectQueue
```

Use this CSV file as the upload template:

```text
assets/watchlists/ForensicCollectQueue.csv
```

When Sentinel asks for the search key, choose:

```text
MdatpDeviceId
```

The queue checker expects that exact alias and those exact column names.

### Set Optional Defender App Roles

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
