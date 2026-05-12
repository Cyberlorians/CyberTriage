# Commercial Azure Deployment Guide

This guide walks through the CyberTriage commercial Azure deployment one step at a time.

Use this guide when deploying from the commercial Azure portal:

```text
https://portal.azure.com
```

Do not use the Azure Government portal for commercial deployments.

## What This Deploys

The full deployment button creates these Azure resources:

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

The deployment does not finish the whole product by itself. After ARM finishes,
you still need to grant Defender for Endpoint app roles, check API connections,
create or verify the Sentinel watchlist, upload Live Response files, test the
broker, and then test one device.

## Before You Start

You need these things ready before clicking the button:

```text
1. Azure subscription access.
2. A Microsoft Sentinel workspace.
3. Microsoft Defender for Endpoint in the same tenant.
4. Permission to create resources in the playbook resource group.
5. Permission to assign Azure RBAC roles, or an admin who can run the permission script later.
6. Permission to grant MDE app roles, or an Entra admin who can do it later.
7. The Cyber Triage collector executable for the Live Response Library.
```

Your customer tenant may have different names. Copy the customer values from
their portal.

## Step 1. Open The Deployment Button

Open this button in a browser where you are signed in to commercial Azure:

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FCyberlorians%2FCyberTriage%2Fmain%2Fdeploy%2Fcommercial%2Fcybertriage-full-deployment.json)

The URL should start with:

```text
https://portal.azure.com
```

If it opens `https://portal.azure.us`, stop and switch to the commercial Azure
portal.

## Step 2. Choose Subscription, Resource Group, And Region

At the top of the ARM deployment form, fill in these Azure basics.

| Portal Field | What To Put | Example |
|---|---|---|
| Subscription | The subscription where you want the CyberTriage playbooks, Function App, and storage accounts deployed. | `Subscription 1` / `<subscription-guid>` |
| Resource group | The resource group where CyberTriage resources will be created. Create a new one if this is a test. | `rg-cybertriage-commercial` |
| Region | Azure region for the CyberTriage resources. | `East US` |
| Location | Keep the generated value matching the region. | `eastus` |

The CyberTriage resource group does not have to be the Sentinel workspace
resource group. Keeping them separate is normal.

## Step 3. Generate The Broker Shared Secret

The ARM form has a field named `Broker Shared Secret`.

This is a random secret used by the collection Logic App when it calls the SAS
broker Function. It is not a storage key, not an MDE secret, and not your user
password.

What to put in the ARM field:

```text
Broker Shared Secret = paste the full one-line output from the PowerShell command below
```

Do not leave this blank. Do not type the words `Broker Shared Secret`. Do not
use a storage account key. Do not use your password. The Azure portal may hide
the value because this is a secure string field; that is normal.

Generate one before filling in the form.

In PowerShell, run:

```powershell
[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes([guid]::NewGuid().ToString('N') + [guid]::NewGuid().ToString('N')))
```

Copy the output and paste it into:

```text
Broker Shared Secret
```

If PowerShell is not available, use a password generator and create a random
secret at least 64 characters long. Paste that random value into `Broker Shared
Secret`.

Save the value in a secure password vault. You will need it only if you later
need to rebuild or troubleshoot the broker URL.

## Step 4. Fill In Function And Storage Names

The form shows default expressions for some names. You can keep them, or replace
them with customer-friendly names.

Rules for storage account names:

```text
Lowercase letters and numbers only
3 to 24 characters
Must be globally unique
No dashes
No underscores
```

| Portal Field | What To Put | Example |
|---|---|---|
| Sas Broker Function App Name | Globally unique Function App name for the SAS broker. | `func-ct-sas-contoso` |
| Function Host Storage Account Name | Storage account used internally by Azure Functions. This is not evidence storage. | `stcthostcontoso01` |
| Sas Broker Package Uri | Keep the default unless you host the package yourself. | `https://raw.githubusercontent.com/Cyberlorians/CyberTriage/main/packages/SasBrokerNode.zip` |
| Destination Storage Account Name | Evidence storage account for encrypted Cyber Triage output. | `stctresultscontoso01` |
| Target Device Tag | MDE device tag used to mark devices for collection. | `ForensicCollect` |

The deployment creates this blob container inside the destination storage
account:

```text
cybertriage-results
```

## Step 5. Decide Whether To Use Email Notifications

The form has a field named `Notification Email`.

This is optional.

| If You Want Email | If You Do Not Want Email |
|---|---|
| Enter a security mailbox. | Leave the field blank. |
| Example: `security-team@contoso.com` | The workflow skips the email action. |

Email is not required for collection to work.

If you use email, the Office 365 connection may still need manual authorization
after deployment.

## Step 6. Find The Sentinel Workspace Values

You must enter the real Sentinel workspace values. Do not guess these values.

In the commercial Azure portal:

```text
1. Go to https://portal.azure.com
2. Search for Log Analytics workspaces.
3. Open the workspace that has Microsoft Sentinel enabled.
4. On Overview, copy the workspace Name.
5. On Overview, copy the Resource group.
6. On Overview or Properties, copy the Workspace ID / Customer ID.
7. Copy the Subscription ID that contains this workspace.
```

Example customer values:

| Portal Field | Example Value |
|---|---|
| Sentinel Workspace Resource Group | `rg-sentinel-prod` |
| Sentinel Workspace Name | `law-sentinel-prod` |
| Sentinel Workspace Customer Id | `<workspace-guid>` |
| Sentinel Workspace Subscription Id | `<sentinel-subscription-guid>` |

For a customer tenant, replace all four values with the customer workspace
values.

### If Sentinel Is In A Different Subscription

This is supported only when the Sentinel subscription and playbook subscription
are in the same tenant.

If Sentinel is outside the subscription selected at the top of the ARM form,
change:

```text
Sentinel Workspace Subscription Id
```

to the subscription ID that contains the Sentinel workspace.

The person deploying must have enough permission in both subscriptions:

```text
CyberTriage playbook subscription:
  Create resource group resources.
  Assign RBAC on the Function host storage and evidence storage.

Sentinel workspace subscription:
  Assign RBAC on the Sentinel Log Analytics workspace.
```

If the deployer does not have permission in the Sentinel subscription, the ARM
deployment may create resources but fail during the Sentinel RBAC step. In that
case, use the permission script after deployment or have the Sentinel admin
assign the roles manually.

Cross-tenant Sentinel deployment is not supported by this template path.

## Step 7. Fill In Remaining Defaults

Most remaining fields should stay at their defaults for commercial Azure.

| Portal Field | What To Put |
|---|---|
| Watchlist Alias | `ForensicCollectQueue` |
| Sas Expiry Minutes | `1440` |
| Sas Permissions | `racwdl` |
| Poll Frequency Minutes | `60` |
| Online Window Minutes | `60` |
| Defender Api Base Uri | `https://api.securitycenter.microsoft.com` |
| Defender Api Audience | `https://securitycenter.onmicrosoft.com/windowsatpservice` |
| Arm Base Uri | `https://management.azure.com` |
| Arm Audience | `https://management.azure.com/` |
| Storage Blob Dns Suffix | `blob.core.windows.net` |
| Storage Token Resource | `https://storage.azure.com/` |
| Template Base Uri | Keep the default GitHub URL. |

For commercial Azure, use:

```text
https://api.securitycenter.microsoft.com
```

For Azure Government / GCCH, use the GCCH guide instead.

## Step 7A. Example Values For The ARM Form

If you are testing in a commercial tenant, the ARM form should look like this.
Replace the subscription, resource group, workspace, and globally unique names
with values from the customer environment.

| Portal Field | Example Value |
|---|---|
| Subscription | `<playbook-subscription-guid>` |
| Resource group | `rg-cybertriage-commercial-test` |
| Region | `East US` |
| Sas Broker Function App Name | `func-ct-sas-<unique-suffix>` |
| Function Host Storage Account Name | `stcthost<uniquesuffix>` |
| Broker Shared Secret | Paste the full one-line random value generated in Step 3. The field may hide the value. |
| Sas Broker Package Uri | Keep the default. |
| Destination Storage Account Name | `stctresults<uniquesuffix>` |
| Target Device Tag | `ForensicCollect` |
| Notification Email | Leave blank unless testing email. |
| Sentinel Workspace Resource Group | `rg-sentinel-prod` |
| Sentinel Workspace Name | `law-sentinel-prod` |
| Sentinel Workspace Customer Id | `<workspace-guid>` |
| Sentinel Workspace Subscription Id | `<sentinel-subscription-guid>` |
| Watchlist Alias | `ForensicCollectQueue` |
| Defender Api Base Uri | `https://api.securitycenter.microsoft.com` |
| Defender Api Audience | `https://securitycenter.onmicrosoft.com/windowsatpservice` |
| Arm Base Uri | `https://management.azure.com` |
| Arm Audience | `https://management.azure.com/` |
| Storage Blob Dns Suffix | `blob.core.windows.net` |
| Storage Token Resource | `https://storage.azure.com/` |
| Template Base Uri | Keep the default. |

Do not copy the example Sentinel resource group, workspace name, or workspace
customer ID into a customer tenant unless those are truly the customer's
workspace values.

## Step 8. Review And Create

In the ARM form:

```text
1. Select Review + create.
2. Wait for validation.
3. If validation passes, select Create.
4. Wait for deployment to finish.
```

Expected result:

```text
Deployment status: Succeeded
```

If deployment fails, open the failed deployment and copy the first real error
message from Deployment details. The top-level message often says only that one
nested deployment failed; expand the nested deployment to find the useful error.

## Step 9. Confirm The Deployed Resources Exist

After the deployment succeeds, open the CyberTriage resource group and confirm
these resources exist:

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
```

Also confirm the evidence storage account has this container:

```text
cybertriage-results
```

Do not enable `Check-CyberTriageQueue` yet.

## Step 10. Save Deployment Output Values

Open the completed deployment output and save these values:

```text
sasBrokerFunctionAppName
functionHostStorageAccountName
sasBrokerHealthUrl
collectionLogicAppName
setLogicAppName
queueLogicAppName
```

You will use those values in later validation and permission steps.

## Step 11. Grant Azure RBAC And MDE App Roles

The ARM template can create Azure RBAC assignments only when the deployer has
the required role assignment permissions. It cannot grant Microsoft Defender for
Endpoint application roles by itself.

Run this script from the repo root in a commercial Azure PowerShell session:

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

Example Sentinel arguments:

```powershell
  -SentinelResourceGroup 'rg-sentinel-prod' `
  -SentinelWorkspaceName 'law-sentinel-prod' `
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

The script also grants these MDE app roles unless you use
`-SkipDefenderAppRoles`:

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

If Azure RBAC and Entra app-role administration are handled by different people,
run the script with `-SkipDefenderAppRoles`, then have the Entra admin grant the
MDE roles manually on the WindowsDefenderATP enterprise app.

## Step 12. Check API Connections

Open each Logic App in the commercial Azure portal.

Check the API connections for these connectors:

```text
azuresentinel-*
azuremonitorlogs-*
office365-*
```

MDE is not authorized with a WDATP connector. MDE calls use raw HTTP actions
with the Logic App managed identity.

Expected connection behavior:

| Connection | Expected Auth | Notes |
|---|---|---|
| `azuresentinel-*` | Managed identity | Used for incident trigger/entity and watchlist actions. |
| `azuremonitorlogs-*` | Managed identity | Used by the queue checker to query Watchlist and DeviceInfo. |
| `office365-*` | User authorization, optional | Needed only if `NotificationEmail` was filled in. |

If `NotificationEmail` was blank, email can stay unused.

## Step 13. Create Or Verify The Sentinel Watchlist

In Microsoft Sentinel, create or verify this watchlist alias:

```text
ForensicCollectQueue
```

Use this CSV as the starter file:

[../../assets/watchlists/ForensicCollectQueue.csv](../../assets/watchlists/ForensicCollectQueue.csv)

The important columns are:

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

## Step 14. Upload MDE Live Response Library Files

In Microsoft Defender for Endpoint, upload these exact file names to the Live
Response Library:

```text
CyberTriageCollector.exe
Run-CyberTriage.ps1
```

The wrapper script is here:

[../../src/LiveResponse/Run-CyberTriage.ps1](../../src/LiveResponse/Run-CyberTriage.ps1)

The names must match exactly. If the file name is different in the MDE Library,
Live Response will fail.

## Step 15. Test The Broker Health Endpoint

Open the `sasBrokerHealthUrl` deployment output in a browser.

It should look like this:

```text
https://<function-app-name>.azurewebsites.net/api/health
```

Expected response:

```json
{ "status": "ok" }
```

If the browser shows `404`, the Function package did not load correctly or the
Function host is not ready yet. Wait a minute and refresh. If it still fails,
check the Function App deployment and application settings.

## Step 16. Test SAS Generation

Use a secure admin shell. Do not paste the returned SAS URL into tickets, chat,
or screenshots.

Send a POST request to the broker URL using the broker secret. The response
should include a `sasUrl` that starts like this in commercial Azure:

```text
https://<destination-storage-account>.blob.core.windows.net/cybertriage-results?
```

That proves the broker can create a user-delegation SAS in commercial Azure.

## Step 17. Run One Controlled Device Test

Pick one device that is active in Microsoft Defender for Endpoint.

The device must be:

```text
Onboarded to MDE
Recently seen by MDE
Able to run Live Response
Allowed to receive the CyberTriageCollector.exe and Run-CyberTriage.ps1 files
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

If there are no onboarded active MDE devices, stop after broker, connection,
and watchlist validation. Live Response cannot be tested without an active
device.

## Step 18. Enable The Queue Checker

Only enable the queue checker after one controlled test works.

In the commercial Azure portal:

```text
1. Open Logic Apps.
2. Open Check-CyberTriageQueue.
3. Select Overview.
4. Select Enable.
```

The queue checker deploys disabled on purpose so it does not start collecting
before the environment is ready.

## Troubleshooting Quick Checks

### The ARM Form Shows Placeholder Sentinel Values

Refresh the deployment page. The current template does not prefill the Sentinel
resource group, workspace name, or customer ID. You must type the real values.

### The Deployment Fails At Sentinel RBAC

Check whether the deployer has permission on the Sentinel workspace subscription
and resource group. If not, deploy resources first and have an admin run the
permission script or assign the roles manually.

### Broker Health Returns 404

Check:

```text
Function App exists
Application setting WEBSITE_RUN_FROM_PACKAGE points to packages/SasBrokerNode.zip
Function runtime is Node 20
Function host storage permissions are assigned
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

Confirm the device is active in MDE and has recent `DeviceInfo` telemetry in the
Sentinel workspace. A running VM is not enough. MDE must have seen it recently.

## Cleanup After A Test Deployment

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

SAS broker only:

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FCyberlorians%2FCyberTriage%2Fmain%2Fdeploy%2Fcommercial%2Fsas-broker-function.json)

Collection playbook only:

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FCyberlorians%2FCyberTriage%2Fmain%2Fdeploy%2Fcommercial%2Fcybertriage-live-response-collection.json)

Incident tagging playbook only:

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FCyberlorians%2FCyberTriage%2Fmain%2Fdeploy%2Fcommercial%2Fset-cybertriage.json)

Queue checker only:

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FCyberlorians%2FCyberTriage%2Fmain%2Fdeploy%2Fcommercial%2Fcheck-cybertriage-queue.json)
