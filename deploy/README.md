# CyberTriage Deployment Guide

One guide for both clouds. Any field that differs between Commercial Azure and
Azure Government / GCC High is shown side by side.

---

## Deployment

### Step 1. Click Deploy

Pick your cloud and click the matching button. Both buttons load the same form
in the matching portal.

| Commercial Azure | Azure Government / GCC High |
|---|---|
| Portal: `https://portal.azure.com` | Portal: `https://portal.azure.us` |
| [![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FCyberlorians%2FCyberTriage%2Fmain%2Fdeploy%2Fcommercial%2Fcybertriage-full-deployment.json) | [![Deploy to Azure Government](https://aka.ms/deploytoazuregovbutton)](https://portal.azure.us/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FCyberlorians%2FCyberTriage%2Fmain%2Fdeploy%2Fgcch%2Fcybertriage-full-deployment.json) |

The full deployment creates these resources in the resource group you select:

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

#### Subscription, Resource Group, And Region

| Portal Field | What To Put | Commercial Example | GCCH Example |
|---|---|---|---|
| Subscription | Subscription where CyberTriage resources will be created. | `<playbook-subscription-guid>` | `99c69aca-874f-48fe-ab6c-3e0f88f205f1` |
| Resource group | New or existing resource group for CyberTriage. | `rg-cybertriage` | `rg-cybertriage-gcch` |
| Region | Region for the CyberTriage resources. | `East US` | `(US) USGov Virginia` |
| Location | Generated value matching the region. | `eastus` | `usgovvirginia` |

#### Broker Shared Secret

Leave blank. The template auto-generates the secret with `newGuid()` and wires
it into both the Function app setting and the Logic App URL in the same
deployment, so they always match. To keep the same secret across redeploys,
paste the existing value into this field.

#### Function And Storage Names

| Portal Field | What To Put | Example |
|---|---|---|
| Sas Broker Function App Name | Globally unique Function App name for the SAS broker. | `func-ct-sas-contoso` |
| Function Host Storage Account Name | Storage account used internally by Azure Functions. | `stcthostcontoso01` |
| Sas Broker Package Uri | Keep the default unless hosting the package yourself. | `https://raw.githubusercontent.com/Cyberlorians/CyberTriage/main/packages/SasBrokerNode.zip` |
| Destination Storage Account Name | Evidence storage account for encrypted Cyber Triage output. | `stctresultscontoso01` |
| Target Device Tag | MDE device tag used to mark devices for collection. | `ForensicCollect` |

Storage account name rules: lowercase letters and numbers only, 3-24
characters, globally unique, no dashes, no underscores.

#### Notification Email (Optional)

| If You Want Email | If You Do Not Want Email |
|---|---|
| Enter a security mailbox. | Leave blank. |
| Commercial example: `security-team@contoso.com` | The workflow skips the email action. |
| GCCH example: `security-team@contoso.us` | |

If used, the Office 365 connection still needs manual user authorization after
deployment.

#### Sentinel Workspace Values

The form takes four separate fields. It does not take a single workspace
resource ID and it does not take only the workspace GUID.

| Portal Field | Where To Find It |
|---|---|
| Sentinel Workspace Subscription Id | The subscription that contains the Sentinel workspace. |
| Sentinel Workspace Resource Group | The resource group of the Log Analytics workspace that has Sentinel enabled. |
| Sentinel Workspace Name | The Log Analytics workspace name. |
| Sentinel Workspace Customer Id | Workspace ID / customer ID GUID from the workspace Overview page. |

| Portal Field | Commercial Example | GCCH Example |
|---|---|---|
| Sentinel Workspace Subscription Id | `<sentinel-subscription-guid>` | `99c69aca-874f-48fe-ab6c-3e0f88f205f1` |
| Sentinel Workspace Resource Group | `rg-sentinel-prod` | `Sentinel` |
| Sentinel Workspace Name | `law-sentinel-prod` | `dibsecus` |
| Sentinel Workspace Customer Id | `<workspace-guid>` | `5714fa24-7a6b-4304-9d42-a0173a2eaede` |

#### Cloud-Specific Endpoint Defaults

Pre-filled per cloud. Do not change unless you know why.

| Portal Field | Commercial Default | GCCH Default |
|---|---|---|
| Defender Api Base Uri | `https://api.securitycenter.microsoft.com` | `https://api-gov.securitycenter.microsoft.us` |
| Defender Api Audience | `https://securitycenter.onmicrosoft.com/windowsatpservice` | `https://api-gov.securitycenter.microsoft.us` |
| Arm Base Uri | `https://management.azure.com` | `https://management.usgovcloudapi.net` |
| Arm Audience | `https://management.azure.com/` | `https://management.usgovcloudapi.net/` |
| Storage Blob Dns Suffix | `blob.core.windows.net` | `blob.core.usgovcloudapi.net` |
| Storage Token Resource | `https://storage.azure.com/` | `https://storage.azure.com/` |

For regular GCC (not GCC High), the Defender API endpoint is normally
`https://api-gcc.securitycenter.microsoft.us`.

#### Other Defaults

| Portal Field | Default |
|---|---|
| Watchlist Alias | `ForensicCollectQueue` |
| Sas Expiry Minutes | `1440` |
| Sas Permissions | `racwdl` |
| Poll Frequency Minutes | `60` |
| Online Window Minutes | `60` |

#### Review And Create

Select **Review + create**, wait for validation to pass, then select **Create**.
Wait for `Deployment status: Succeeded`. If it fails, expand the failed nested
deployment in Deployment details to see the real error.

---

### Step 2. Run The Permission Script

> **A Microsoft Entra Global Administrator or Application Administrator must
> run this step.** The script grants Microsoft Defender for Endpoint
> application roles to the Logic App managed identities. ARM cannot do this on
> its own because the roles live in Microsoft Entra ID on the
> WindowsDefenderATP enterprise application.

Download the script:

[scripts/Grant-CyberTriageDefenderRoles.ps1](../scripts/Grant-CyberTriageDefenderRoles.ps1)

Run it from a PowerShell session signed in to the same tenant. No parameters
required:

```powershell
# Commercial
az login
.\Grant-CyberTriageDefenderRoles.ps1
```

```powershell
# GCC High
az cloud set --name AzureUSGovernment
az login
.\Grant-CyberTriageDefenderRoles.ps1
```

The script grants:

| Logic App Managed Identity | MDE App Roles Granted |
|---|---|
| `Set-CyberTriage` | `Machine.ReadWrite.All` |
| `CyberTriage-LiveResponse-Collection` | `Machine.Read.All`, `Machine.ReadWrite.All`, `Machine.LiveResponse` |
| `Check-CyberTriageQueue` | None (does not call MDE) |

The script is idempotent. Running it again only adds missing roles.

---

## Verification

### Step 3. Confirm Resources Exist

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

### Step 4. Save Deployment Output Values

From the deployment Outputs blade, save:

```text
sasBrokerFunctionAppName
functionHostStorageAccountName
sasBrokerHealthUrl
collectionLogicAppName
setLogicAppName
queueLogicAppName
```

### Step 5. Check API Connections

Open each Logic App and check these API connections:

| Connection | Expected Auth | Notes |
|---|---|---|
| `azuresentinel-*` | Managed identity | Used for incident trigger/entity and watchlist actions. |
| `azuremonitorlogs-*` | Managed identity | Used by the queue checker to query Watchlist and DeviceInfo. |
| `office365-*` | User authorization, optional | Needed only if `NotificationEmail` was filled in. |

MDE is not authorized through a WDATP connector. MDE calls use raw HTTP actions
with the Logic App managed identity.

### Step 6. Create Or Verify The Sentinel Watchlist

In Microsoft Sentinel, create or verify this watchlist alias:

```text
ForensicCollectQueue
```

Starter CSV: [../assets/watchlists/ForensicCollectQueue.csv](../assets/watchlists/ForensicCollectQueue.csv)

Important columns: `MdatpDeviceId`, `DeviceName`, `IncidentId`, `TagName`,
`EnqueuedTime`, `Attempts`, `Status`, `RetryAfterUtc`. Blank `Status` is valid
and is treated as pending.

### Step 7. Upload MDE Live Response Library Files

In Microsoft Defender for Endpoint, upload these exact file names to the Live
Response Library:

```text
CyberTriageCollector.exe
Run-CyberTriage.ps1
```

The wrapper script: [../src/LiveResponse/Run-CyberTriage.ps1](../src/LiveResponse/Run-CyberTriage.ps1)

### Step 8. Test The Broker Health Endpoint

Open the `sasBrokerHealthUrl` deployment output in a browser.

| Commercial | GCCH |
|---|---|
| `https://<function-app-name>.azurewebsites.net/api/health` | `https://<function-app-name>.azurewebsites.us/api/health` |

Expected:

```json
{ "status": "ok" }
```

### Step 9. Test SAS Generation

POST to the broker URL with the broker secret. Returned `sasUrl` should start:

| Commercial | GCCH |
|---|---|
| `https://<destination-storage-account>.blob.core.windows.net/cybertriage-results?` | `https://<destination-storage-account>.blob.core.usgovcloudapi.net/cybertriage-results?` |

### Step 10. Run One Controlled Device Test

Pick one onboarded MDE device that has been recently seen and can run Live
Response.

```text
1. Add or enqueue the device for collection.
2. Run Check-CyberTriageQueue manually, or enable it temporarily.
3. Confirm CyberTriage-LiveResponse-Collection starts.
4. Confirm MDE creates a Live Response action.
5. Confirm a blob appears in cybertriage-results.
6. Confirm the MDE tag is removed.
7. Confirm the watchlist item is deleted or updated.
```

Expected blob name pattern: `cttout_<device>_<timestamp>.json.gz.enc.01`

### Step 11. Enable The Queue Checker

Only after one controlled test works:

```text
1. Open Logic Apps.
2. Open Check-CyberTriageQueue.
3. Select Overview.
4. Select Enable.
```

---

## Troubleshooting Quick Checks

### Deployment Fails At Sentinel RBAC

Check whether the deployer has permission on the Sentinel workspace
subscription and resource group.

### Broker Health Returns 404

```text
Function App exists
WEBSITE_RUN_FROM_PACKAGE points to packages/SasBrokerNode.zip
Function runtime is Node 20
Function host storage role assignments are in place
```

### MDE Calls Return 403

Re-run `Grant-CyberTriageDefenderRoles.ps1` and confirm:

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

---

## Individual Deployment Buttons

Use only when deploying pieces separately.

| Component | Commercial | GCCH |
|---|---|---|
| SAS broker only | [![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FCyberlorians%2FCyberTriage%2Fmain%2Fdeploy%2Fcommercial%2Fsas-broker-function.json) | [![Deploy to Azure Government](https://aka.ms/deploytoazuregovbutton)](https://portal.azure.us/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FCyberlorians%2FCyberTriage%2Fmain%2Fdeploy%2Fgcch%2Fsas-broker-function.json) |
| Collection playbook only | [![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FCyberlorians%2FCyberTriage%2Fmain%2Fdeploy%2Fcommercial%2Fcybertriage-live-response-collection.json) | [![Deploy to Azure Government](https://aka.ms/deploytoazuregovbutton)](https://portal.azure.us/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FCyberlorians%2FCyberTriage%2Fmain%2Fdeploy%2Fgcch%2Fcybertriage-live-response-collection.json) |
| Incident tagging playbook only | [![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FCyberlorians%2FCyberTriage%2Fmain%2Fdeploy%2Fcommercial%2Fset-cybertriage.json) | [![Deploy to Azure Government](https://aka.ms/deploytoazuregovbutton)](https://portal.azure.us/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FCyberlorians%2FCyberTriage%2Fmain%2Fdeploy%2Fgcch%2Fset-cybertriage.json) |
| Queue checker only | [![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FCyberlorians%2FCyberTriage%2Fmain%2Fdeploy%2Fcommercial%2Fcheck-cybertriage-queue.json) | [![Deploy to Azure Government](https://aka.ms/deploytoazuregovbutton)](https://portal.azure.us/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FCyberlorians%2FCyberTriage%2Fmain%2Fdeploy%2Fgcch%2Fcheck-cybertriage-queue.json) |
