# CyberTriage Deployment Guide

This is the single deployment guide for both clouds. Pick your cloud in the top
table, then follow the steps. Any field that is different between Commercial
Azure and Azure Government / GCC High is shown side by side.

## Step 0. Pick Your Cloud And Click Deploy

| Commercial Azure | Azure Government / GCC High |
|---|---|
| Portal: `https://portal.azure.com` | Portal: `https://portal.azure.us` |
| [![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FCyberlorians%2FCyberTriage%2Fmain%2Fdeploy%2Fcommercial%2Fcybertriage-full-deployment.json) | [![Deploy to Azure Government](https://aka.ms/deploytoazuregovbutton)](https://portal.azure.us/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FCyberlorians%2FCyberTriage%2Fmain%2Fdeploy%2Fgcch%2Fcybertriage-full-deployment.json) |
| Use if the tenant is in commercial Azure. | Use if the tenant is in GCC High. |

If you click the wrong one, the portal URL will say so. Stop and switch.

## What This Deploys

The full deployment button creates these Azure resources in one resource group:

```text
Evidence storage account
Evidence blob container: cybertriage-results
SAS broker Function App
Function host storage account
CyberTriage-LiveResponse-Collection Logic App
Set-CyberTriage Logic App
Check-CyberTriageQueue Logic App
Azure RBAC assignments that ARM is allowed to create
```

The deployment does not finish the whole product by itself. After ARM finishes
you still grant Defender for Endpoint app roles, check API connections, create
or verify the Sentinel watchlist, upload Live Response files, test the broker,
and then test one device.

## Before You Start

You need these things ready before clicking the button:

```text
1. Azure subscription access (commercial or Azure Government).
2. A Microsoft Sentinel workspace.
3. Microsoft Defender for Endpoint in the same tenant.
4. Permission to create resources in the playbook resource group.
5. Permission to assign Azure RBAC roles, or an admin who can run the permission script later.
6. Permission to grant MDE app roles, or an Entra admin who can do it later.
7. The Cyber Triage collector executable for the Live Response Library.
```

## Step 1. Open The Deployment Button

| Commercial | GCCH |
|---|---|
| Open the Commercial button in Step 0 from `https://portal.azure.com`. | Open the GCCH button in Step 0 from `https://portal.azure.us`. |

## Step 2. Subscription, Resource Group, And Region

Same fields in both clouds. Only the example region differs.

| Portal Field | What To Put | Commercial Example | GCCH Example |
|---|---|---|---|
| Subscription | The subscription where CyberTriage resources will be created. | `<playbook-subscription-guid>` | `99c69aca-874f-48fe-ab6c-3e0f88f205f1` |
| Resource group | New or existing resource group for CyberTriage. | `rg-cybertriage` | `rg-cybertriage-gcch` |
| Region | Region for the CyberTriage resources. | `East US` | `(US) USGov Virginia` |
| Location | Generated value matching the region. | `eastus` | `usgovvirginia` |

The CyberTriage resource group does not have to be the Sentinel workspace
resource group. Keeping them separate is normal.

## Step 3. Broker Shared Secret (Leave It Alone)

```text
Broker Shared Secret = leave blank
```

The template auto-generates this with ARM `newGuid()`. The same value is wired
into the Function app setting and the Logic App URL in the same deployment, so
they always match.

If you redeploy later and leave the field blank, ARM regenerates a new GUID.
Both sides get refreshed in the same deployment so they stay in sync. If you
want the same secret across redeploys, paste the existing value into the field.

## Step 4. Function And Storage Names

Same fields in both clouds. The template generates defaults you can keep.

Storage account name rules:

```text
Lowercase letters and numbers only
3 to 24 characters
Globally unique
No dashes
No underscores
```

| Portal Field | What To Put | Example |
|---|---|---|
| Sas Broker Function App Name | Globally unique Function App name for the SAS broker. | `func-ct-sas-contoso` |
| Function Host Storage Account Name | Storage account used internally by Azure Functions. Not evidence storage. | `stcthostcontoso01` |
| Sas Broker Package Uri | Keep the default unless you host the package yourself. | `https://raw.githubusercontent.com/Cyberlorians/CyberTriage/main/packages/SasBrokerNode.zip` |
| Destination Storage Account Name | Evidence storage account for encrypted Cyber Triage output. | `stctresultscontoso01` |
| Target Device Tag | MDE device tag used to mark devices for collection. | `ForensicCollect` |

The deployment creates this blob container inside the destination storage
account:

```text
cybertriage-results
```

## Step 5. Notification Email (Optional)

Optional. Leave blank to skip email.

| If You Want Email | If You Do Not Want Email |
|---|---|
| Enter a security mailbox. | Leave the field blank. |
| Commercial example: `security-team@contoso.com` | The workflow skips the email action. |
| GCCH example: `security-team@contoso.us` | |

If used, the Office 365 connection still needs manual user authorization after
deployment.

## Step 6. Sentinel Workspace Values

The form takes **four separate fields**. It does not take a single workspace
resource ID and it does not take only the workspace GUID.

| Portal Field | Where To Find It |
|---|---|
| Sentinel Workspace Subscription Id | The subscription that contains the Sentinel workspace. May be different from the playbook subscription. |
| Sentinel Workspace Resource Group | The resource group of the Log Analytics workspace that has Sentinel enabled. |
| Sentinel Workspace Name | The Log Analytics workspace name (not the Sentinel display label). |
| Sentinel Workspace Customer Id | Workspace ID / customer ID GUID from the Log Analytics workspace Overview page. |

How to look them up:

| Commercial | GCCH |
|---|---|
| `https://portal.azure.com` -> Log Analytics workspaces -> open the Sentinel workspace. | `https://portal.azure.us` -> Log Analytics workspaces -> open the Sentinel workspace. |

Example values for the validation tenant used while writing this guide:

| Portal Field | Commercial Example | GCCH Example |
|---|---|---|
| Sentinel Workspace Subscription Id | `<sentinel-subscription-guid>` | `99c69aca-874f-48fe-ab6c-3e0f88f205f1` |
| Sentinel Workspace Resource Group | `rg-sentinel-prod` | `Sentinel` |
| Sentinel Workspace Name | `law-sentinel-prod` | `dibsecus` |
| Sentinel Workspace Customer Id | `<workspace-guid>` | `5714fa24-7a6b-4304-9d42-a0173a2eaede` |

### If Sentinel Is In A Different Subscription

Same tenant only. Cross-tenant is not supported by this template path.

If Sentinel is outside the subscription you selected at the top of the form,
change `Sentinel Workspace Subscription Id` to the Sentinel subscription. The
deployer needs:

```text
CyberTriage playbook subscription:
  Create resources, assign RBAC on Function host and evidence storage.

Sentinel workspace subscription:
  Assign RBAC on the Sentinel Log Analytics workspace.
```

## Step 7. Cloud-Specific Endpoint Defaults

These are pre-filled per cloud. Do not change them unless you know why.

| Portal Field | Commercial Default | GCCH Default |
|---|---|---|
| Defender Api Base Uri | `https://api.securitycenter.microsoft.com` | `https://api-gov.securitycenter.microsoft.us` |
| Defender Api Audience | `https://securitycenter.onmicrosoft.com/windowsatpservice` | `https://api-gov.securitycenter.microsoft.us` |
| Arm Base Uri | `https://management.azure.com` | `https://management.usgovcloudapi.net` |
| Arm Audience | `https://management.azure.com/` | `https://management.usgovcloudapi.net/` |
| Storage Blob Dns Suffix | `blob.core.windows.net` | `blob.core.usgovcloudapi.net` |
| Storage Token Resource | `https://storage.azure.com/` | `https://storage.azure.com/` |
| Template Base Uri | Keep default. | Keep default. |

For regular GCC, not GCC High, the Defender API endpoint is normally
`https://api-gcc.securitycenter.microsoft.us`.

## Step 8. Other Defaults

Same in both clouds.

| Portal Field | Default |
|---|---|
| Watchlist Alias | `ForensicCollectQueue` |
| Sas Expiry Minutes | `1440` |
| Sas Permissions | `racwdl` |
| Poll Frequency Minutes | `60` |
| Online Window Minutes | `60` |

## Step 9. Review And Create

```text
1. Select Review + create.
2. Wait for validation.
3. If validation passes, select Create.
4. Wait for deployment to finish.
```

Expected:

```text
Deployment status: Succeeded
```

If deployment fails, expand the failed nested deployment in Deployment details
to find the real error.

## Step 10. Confirm Resources Exist

In the CyberTriage resource group, confirm:

```text
Function App:
  Your SAS broker Function App

Storage accounts:
  Function host storage account
  Destination/evidence storage account

Logic Apps:
  CyberTriage-LiveResponse-Collection
  Set-CyberTriage
  Check-CyberTriageQueue

Blob container in evidence storage:
  cybertriage-results
```

Do not enable `Check-CyberTriageQueue` yet.

## Step 11. Save Deployment Output Values

Save these from the deployment Outputs blade:

```text
sasBrokerFunctionAppName
functionHostStorageAccountName
sasBrokerHealthUrl
collectionLogicAppName
setLogicAppName
queueLogicAppName
```

## Step 12. Grant Azure RBAC And MDE App Roles

ARM can create Azure RBAC only when the deployer has rights to do so. ARM
cannot grant Microsoft Defender for Endpoint application roles by itself.

| Commercial | GCCH |
|---|---|
| Run the script in a normal PowerShell session signed in to commercial Azure. | Run the script in a PowerShell session signed in to Azure Government. |

```powershell
.\scripts\Grant-CyberTriagePermissions.ps1 `
  -SubscriptionId '<playbook-subscription-guid>' `
  -PlaybookResourceGroup '<cybertriage-resource-group>' `
  -SentinelResourceGroup '<sentinel-workspace-resource-group>' `
  -SentinelWorkspaceName '<sentinel-workspace-name>' `
  -EvidenceStorageResourceGroup '<cybertriage-resource-group>' `
  -EvidenceStorageAccountName '<destination-storage-account-name>' `
  -FunctionHostStorageResourceGroup '<cybertriage-resource-group>' `
  -FunctionHostStorageAccountName '<function-host-storage-account-name>' `
  -SasBrokerFunctionAppName '<sas-broker-function-app-name>'
```

The script grants these Azure RBAC permissions:

```text
SAS broker Function App managed identity, evidence storage:
  Storage Blob Delegator
  Storage Blob Data Contributor

SAS broker Function App managed identity, Function host storage:
  Storage Blob Data Contributor
  Storage Queue Data Contributor
  Storage Table Data Contributor

Set-CyberTriage managed identity, Sentinel workspace:
  Microsoft Sentinel Contributor

Check-CyberTriageQueue managed identity, Sentinel workspace:
  Log Analytics Reader
  Microsoft Sentinel Contributor

CyberTriage-LiveResponse-Collection managed identity, Sentinel workspace:
  Microsoft Sentinel Contributor
```

The script also grants these MDE app roles unless `-SkipDefenderAppRoles` is
used:

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

If a different admin owns Entra app roles, run the script with
`-SkipDefenderAppRoles` and have the Entra admin grant MDE app roles manually
on the WindowsDefenderATP enterprise app.

## Step 13. Check API Connections

Open each Logic App in the same portal you deployed from.

Check API connections for these connectors:

```text
azuresentinel-*
azuremonitorlogs-*
office365-*
```

| Connection | Expected Auth | Notes |
|---|---|---|
| `azuresentinel-*` | Managed identity | Used for incident trigger/entity and watchlist actions. |
| `azuremonitorlogs-*` | Managed identity | Used by the queue checker to query Watchlist and DeviceInfo. |
| `office365-*` | User authorization, optional | Needed only if `NotificationEmail` was filled in. |

MDE is not authorized through a WDATP connector. MDE calls use raw HTTP
actions with the Logic App managed identity.

## Step 14. Create Or Verify The Sentinel Watchlist

In Microsoft Sentinel, create or verify this watchlist alias:

```text
ForensicCollectQueue
```

Starter CSV:

[../assets/watchlists/ForensicCollectQueue.csv](../assets/watchlists/ForensicCollectQueue.csv)

Important columns:

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

## Step 15. Upload MDE Live Response Library Files

In Microsoft Defender for Endpoint, upload these exact file names to the Live
Response Library:

```text
CyberTriageCollector.exe
Run-CyberTriage.ps1
```

The wrapper script is here:

[../src/LiveResponse/Run-CyberTriage.ps1](../src/LiveResponse/Run-CyberTriage.ps1)

The names must match exactly.

## Step 16. Test The Broker Health Endpoint

Open the `sasBrokerHealthUrl` deployment output in a browser.

| Commercial | GCCH |
|---|---|
| `https://<function-app-name>.azurewebsites.net/api/health` | `https://<function-app-name>.azurewebsites.us/api/health` |

Expected response:

```json
{ "status": "ok" }
```

If `404`, wait a minute and refresh. If still failing, check the Function App
package and app settings.

## Step 17. Test SAS Generation

Use a secure admin shell. Do not paste the returned SAS URL into tickets, chat,
or screenshots.

POST to the broker URL with the broker secret. The returned `sasUrl` should
start like this:

| Commercial | GCCH |
|---|---|
| `https://<destination-storage-account>.blob.core.windows.net/cybertriage-results?` | `https://<destination-storage-account>.blob.core.usgovcloudapi.net/cybertriage-results?` |

## Step 18. Run One Controlled Device Test

Pick one device that is active in MDE. The device must be:

```text
Onboarded to MDE
Recently seen by MDE
Able to run Live Response
Allowed to receive CyberTriageCollector.exe and Run-CyberTriage.ps1
```

Test flow:

```text
1. Add or enqueue the device for collection.
2. Run Check-CyberTriageQueue manually, or enable it temporarily.
3. Confirm CyberTriage-LiveResponse-Collection starts.
4. Confirm MDE creates a Live Response action.
5. Confirm a blob appears in cybertriage-results.
6. Confirm the MDE tag is removed.
7. Confirm the watchlist item is deleted or updated.
```

Expected blob name pattern:

```text
cttout_<device>_<timestamp>.json.gz.enc.01
```

## Step 19. Enable The Queue Checker

Only enable after one controlled test works.

```text
1. Open Logic Apps.
2. Open Check-CyberTriageQueue.
3. Select Overview.
4. Select Enable.
```

## Troubleshooting Quick Checks

### Deployment Fails At Sentinel RBAC

Check whether the deployer has permission on the Sentinel workspace
subscription and resource group. If not, deploy resources first and run the
permission script after with an admin who does.

### Broker Health Returns 404

```text
Function App exists
WEBSITE_RUN_FROM_PACKAGE points to packages/SasBrokerNode.zip
Function runtime is Node 20
Function host storage role assignments are in place
```

### MDE Calls Return 403

Check the MDE app roles on the Logic App managed identities:

```text
Set-CyberTriage:
  Machine.ReadWrite.All

CyberTriage-LiveResponse-Collection:
  Machine.Read.All
  Machine.ReadWrite.All
  Machine.LiveResponse
```

### Queue Checker Finds No Devices

The device must be active in MDE with recent `DeviceInfo` telemetry in the
Sentinel workspace. A running VM is not enough.

## Cleanup After A Test

If this was only a test, delete only the CyberTriage test resource group you
created.

Do not delete:

```text
The customer Sentinel workspace
Existing customer watchlists
Existing Defender configuration
Production evidence storage
```

If the deployment assigned Sentinel workspace RBAC to test managed identities,
remove those role assignments before deleting the test resource group when
possible. After managed identities are deleted, orphaned role assignments are
harder to identify.

## Individual Deployment Buttons

Use these only when deploying pieces separately.

| Component | Commercial | GCCH |
|---|---|---|
| SAS broker only | [![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FCyberlorians%2FCyberTriage%2Fmain%2Fdeploy%2Fcommercial%2Fsas-broker-function.json) | [![Deploy to Azure Government](https://aka.ms/deploytoazuregovbutton)](https://portal.azure.us/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FCyberlorians%2FCyberTriage%2Fmain%2Fdeploy%2Fgcch%2Fsas-broker-function.json) |
| Collection playbook only | [![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FCyberlorians%2FCyberTriage%2Fmain%2Fdeploy%2Fcommercial%2Fcybertriage-live-response-collection.json) | [![Deploy to Azure Government](https://aka.ms/deploytoazuregovbutton)](https://portal.azure.us/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FCyberlorians%2FCyberTriage%2Fmain%2Fdeploy%2Fgcch%2Fcybertriage-live-response-collection.json) |
| Incident tagging playbook only | [![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FCyberlorians%2FCyberTriage%2Fmain%2Fdeploy%2Fcommercial%2Fset-cybertriage.json) | [![Deploy to Azure Government](https://aka.ms/deploytoazuregovbutton)](https://portal.azure.us/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FCyberlorians%2FCyberTriage%2Fmain%2Fdeploy%2Fgcch%2Fset-cybertriage.json) |
| Queue checker only | [![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FCyberlorians%2FCyberTriage%2Fmain%2Fdeploy%2Fcommercial%2Fcheck-cybertriage-queue.json) | [![Deploy to Azure Government](https://aka.ms/deploytoazuregovbutton)](https://portal.azure.us/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FCyberlorians%2FCyberTriage%2Fmain%2Fdeploy%2Fgcch%2Fcheck-cybertriage-queue.json) |
