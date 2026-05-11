# Azure Government / GCCH Deployment

This folder contains Azure Government deployment wrappers for CyberTriage.

Use these when the customer is in GCC High / Azure Government and deploys from
`https://portal.azure.us`.

The GCCH templates do not keep separate copies of every workflow. They pass
Azure Government defaults into the shared cloud-aware templates in
`deploy/commercial`. That keeps commercial and GCCH behavior aligned.

## What Was Verified In GCCH

Verified on May 9, 2026 in AzureUSGovernment / `usgovvirginia`:

```text
Azure Resource Manager: https://management.usgovcloudapi.net/
Microsoft Entra authority: https://login.microsoftonline.us
Azure portal: https://portal.azure.us
Storage suffix from cloud profile: core.usgovcloudapi.net
Blob DNS suffix used by templates: blob.core.usgovcloudapi.net
Microsoft Graph resource: https://graph.microsoft.us/
Logic App managed APIs present: azuresentinel, azuremonitorlogs, office365, wdatp
WindowsDefenderATP enterprise app ID present: fc780465-2017-40d4-a0c5-307022471b92
Required MDE app roles present: Machine.Read.All, Machine.ReadWrite.All, Machine.LiveResponse
GCCH MDE API endpoint from Microsoft Learn: https://api-gov.securitycenter.microsoft.us
```

The tenant used for validation did not have an onboarded MDE device available,
so end-to-end Live Response execution could not be proven there. The templates
deploy the path. Runtime collection still requires an active Defender for
Endpoint device.

## Deploy Button

Use this button for the normal one-button GCCH deployment.

[![Deploy to Azure Government](https://aka.ms/deploytoazuregovbutton)](https://portal.azure.us/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FCyberlorians%2FCyberTriage%2Fmain%2Fdeploy%2Fgcch%2Fcybertriage-full-deployment.json)

The button deploys:

```text
Evidence storage account
Evidence container: cybertriage-results
SAS broker Function App
Function host storage account
CyberTriage-LiveResponse-Collection Logic App
Set-CyberTriage Logic App
Check-CyberTriageQueue Logic App
Azure RBAC role assignments the ARM template is allowed to create
```

The button does not grant Microsoft Defender for Endpoint app roles. Those are
Entra application-role assignments on the WindowsDefenderATP enterprise app and
must be granted after deployment by script or by an Entra admin.

## Fill In The Deployment Form

Use these values unless the customer has a reason to change them.

| Field | What To Enter |
|---|---|
| Subscription | The Azure Government subscription that contains or can reach the Sentinel workspace |
| Resource group | A playbook/resource group for CyberTriage resources |
| Region | `usgovvirginia`, unless the customer uses another supported Azure Government region |
| SasBrokerFunctionAppName | Globally unique Function App name, for example `func-ct-sas-<customer>` |
| FunctionHostStorageAccountName | Globally unique lowercase storage account name, 3-24 characters |
| BrokerSharedSecret | Long random secret. Save it securely. It is not a storage key. |
| DestinationStorageAccountName | Globally unique lowercase evidence storage account name |
| TargetDeviceTag | Usually `ForensicCollect` |
| NotificationEmail | Security mailbox for optional Office 365 notification |
| SentinelWorkspaceResourceGroup | Resource group containing the Sentinel Log Analytics workspace |
| SentinelWorkspaceName | Sentinel Log Analytics workspace name |
| SentinelWorkspaceCustomerId | Workspace customer ID / workspace GUID |
| SentinelWorkspaceSubscriptionId | Subscription ID containing the Sentinel workspace |
| WatchlistAlias | Usually `ForensicCollectQueue` |
| DefenderApiBaseUri | For GCC High, keep `https://api-gov.securitycenter.microsoft.us` |
| DefenderApiAudience | For GCC High, keep `https://api-gov.securitycenter.microsoft.us` |
| ArmBaseUri | Keep `https://management.usgovcloudapi.net` |
| ArmAudience | Keep `https://management.usgovcloudapi.net/` |
| StorageBlobDnsSuffix | Keep `blob.core.usgovcloudapi.net` |
| StorageTokenResource | Keep `https://storage.azure.com/` |

For regular GCC, the Defender API endpoint is usually
`https://api-gcc.securitycenter.microsoft.us`. GCC High uses
`https://api-gov.securitycenter.microsoft.us`.

## After The Button Finishes

Do not enable the queue checker yet. Complete these steps first.

### 1. Grant The MDE App Roles

Run the permission script from the repo root in an Azure Government PowerShell
session. The script discovers the Microsoft Graph endpoint for the active cloud.

```powershell
.\scripts\Grant-CyberTriagePermissions.ps1 `
  -SubscriptionId '<subscription-guid>' `
  -PlaybookResourceGroup '<playbook-resource-group>' `
  -SentinelResourceGroup '<sentinel-resource-group>' `
  -SentinelWorkspaceName '<sentinel-workspace-name>' `
  -EvidenceStorageResourceGroup '<playbook-resource-group>' `
  -EvidenceStorageAccountName '<evidence-storage-account>' `
  -FunctionHostStorageResourceGroup '<playbook-resource-group>' `
  -FunctionHostStorageAccountName '<function-host-storage-account>' `
  -SasBrokerFunctionAppName '<sas-broker-function-app-name>'
```

The script grants these MDE app roles unless `-SkipDefenderAppRoles` is used:

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

If one admin owns Azure RBAC and a different admin owns Entra app roles, run the
script with `-SkipDefenderAppRoles`, then have the Entra admin grant the roles
manually on the WindowsDefenderATP enterprise app.

### 2. Check API Connections

Open each Logic App in the Azure Government portal and check API connections.

MDE does not use a WDATP connector in these templates. MDE calls are raw HTTP
actions authenticated as the Logic App managed identity.

The connections that may still need attention are:

```text
azuresentinel-*      Sentinel connector, managed identity
azuremonitorlogs-*   Azure Monitor Logs connector, managed identity
office365-*          Optional email connector, user authorization if email is wanted
```

If Office 365 email is not required, the collection still works when the email
action fails or is skipped.

### 3. Create Or Verify The Watchlist

Create a Sentinel watchlist with alias:

```text
ForensicCollectQueue
```

Use [../../assets/watchlists/ForensicCollectQueue.csv](../../assets/watchlists/ForensicCollectQueue.csv)
as the starter CSV.

The important fields are:

```text
MdatpDeviceId
DeviceName
IncidentId
TagName
EnqueuedTime
Attempts
Status
RetryAfterUtc
```

Blank `Status` is valid. The queue checker treats blank status as pending.

### 4. Upload Live Response Library Files

In Microsoft Defender for Endpoint, upload these files to the Live Response
Library:

```text
CyberTriageCollector.exe
Run-CyberTriage.ps1
```

The wrapper script is in [../../src/LiveResponse/Run-CyberTriage.ps1](../../src/LiveResponse/Run-CyberTriage.ps1).

The names in the Live Response Library must exactly match the Logic App values:

```text
CyberTriageCollector.exe
Run-CyberTriage.ps1
```

### 5. Test The Broker

Open the broker health URL from the deployment output. It should return:

```json
{ "status": "ok" }
```

Then test SAS generation from a secure admin shell. Do not paste the returned
SAS URL into tickets or chat.

The returned URL should start like this in GCCH:

```text
https://<storage-account>.blob.core.usgovcloudapi.net/cybertriage-results?
```

### 6. Run One Controlled Device Test

Pick one device that is active in MDE. The device must be onboarded and recently
seen by Defender for Endpoint.

Test sequence:

```text
1. Add or enqueue the device for collection.
2. Run Check-CyberTriageQueue manually, or wait for the recurrence after enabling it.
3. Confirm CyberTriage-LiveResponse-Collection starts.
4. Confirm MDE creates a Live Response action.
5. Confirm a blob named cttout_<device>_<timestamp>.json.gz.enc.01 appears in cybertriage-results.
6. Confirm the MDE tag is removed and the watchlist item is deleted or updated.
```

If there are no onboarded devices in the GCCH tenant, stop here. The deployment
can be validated, but Live Response cannot run until at least one device is
onboarded and active.

### 7. Enable The Queue Checker

The queue checker deploys disabled on purpose. Enable it only after the previous
steps are complete.

In the Azure Government portal:

```text
Logic Apps
Check-CyberTriageQueue
Overview
Enable
```

## Individual Buttons

Use these only when deploying pieces separately.

SAS broker only:

[![Deploy to Azure Government](https://aka.ms/deploytoazuregovbutton)](https://portal.azure.us/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FCyberlorians%2FCyberTriage%2Fmain%2Fdeploy%2Fgcch%2Fsas-broker-function.json)

Collection playbook only:

[![Deploy to Azure Government](https://aka.ms/deploytoazuregovbutton)](https://portal.azure.us/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FCyberlorians%2FCyberTriage%2Fmain%2Fdeploy%2Fgcch%2Fcybertriage-live-response-collection.json)

Incident tagging playbook only:

[![Deploy to Azure Government](https://aka.ms/deploytoazuregovbutton)](https://portal.azure.us/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FCyberlorians%2FCyberTriage%2Fmain%2Fdeploy%2Fgcch%2Fset-cybertriage.json)

Queue checker only:

[![Deploy to Azure Government](https://aka.ms/deploytoazuregovbutton)](https://portal.azure.us/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FCyberlorians%2FCyberTriage%2Fmain%2Fdeploy%2Fgcch%2Fcheck-cybertriage-queue.json)

## Cleanup After A Test Deployment

If this was only a test deployment, delete only the test resource group you
created for CyberTriage.

If the full deployment assigned Sentinel workspace RBAC to test managed
identities, delete those test role assignments before deleting the test resource
group. After the managed identities are deleted, the role assignments become
harder to identify.

Do not delete the customer Sentinel workspace, existing watchlists, or existing
Defender configuration unless that was explicitly part of the test plan.
