# Commercial Deployment Templates

These templates are the shared CyberTriage deployment templates with commercial Azure defaults. Azure Government / GCCH wrappers pass sovereign cloud values into these same templates.

## Files

| File | Purpose |
|---|---|
| `cybertriage-full-deployment.json` | Recommended one-click deployment. Deploys the SAS broker Function App and all three Logic Apps. |
| `sas-broker-function.json` | Deploys only the SAS broker Function App and Function host storage account. |
| `full.sample.parameters.json` | Example parameter file for the full deployment. Do not commit real secrets. |
| `set-cybertriage.json` | Incident-triggered playbook that tags MDE devices and enqueues them into the Sentinel watchlist. |
| `check-cybertriage-queue.json` | Scheduled queue checker that selects active/recent MDE devices and triggers collection. |
| `cybertriage-live-response-collection.json` | Collection playbook that generates SAS and submits MDE Live Response. |

## Recommended One-Click Deployment

Use this button for the normal customer install. Run it with an account that is `Owner` on the subscription. That lets the template create resources and assign managed identity Azure RBAC roles automatically.

It deploys the evidence storage account, SAS broker Function App, and these exact Logic App names:

```text
CyberTriage-LiveResponse-Collection
Set-CyberTriage
Check-CyberTriageQueue
```

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FCyberlorians%2FCyberTriage%2Fmain%2Fdeploy%2Fcommercial%2Fcybertriage-full-deployment.json)

The SAS broker Function uses an Azure Functions Consumption plan. If Azure reports `Dynamic VMs: 0`, choose a region with quota or request quota from the subscription owner.

After deployment, ARM has already assigned the Azure RBAC roles if the deployment account was `Owner`. You still grant Defender for Endpoint app roles, authorize any non-MDE API connections that need sign-in, and create the watchlist. The plain-language steps are in:

```text
docs/setting-permissions-step-by-step.md
```

Create the Sentinel watchlist with this exact alias:

```text
ForensicCollectQueue
```

MDE calls use raw HTTP with Logic App managed identity, not the WDATP connector. The required WindowsDefenderATP app roles are:

```text
Set-CyberTriage:
  Machine.ReadWrite.All

CyberTriage-LiveResponse-Collection:
  Machine.Read.All
  Machine.ReadWrite.All
  Machine.LiveResponse
```

Use this CSV template:

```text
assets/watchlists/ForensicCollectQueue.csv
```

## Separate Deploy Order

Use this only if you do not want the full deployment template.

1. `cybertriage-live-response-collection.json`
2. `set-cybertriage.json`
3. `check-cybertriage-queue.json`

Deploy the queue checker disabled first. Enable it only after one manual test works.

## One-Click Deploy Buttons

Deploy the collection playbook first:

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FCyberlorians%2FCyberTriage%2Fmain%2Fdeploy%2Fcommercial%2Fcybertriage-live-response-collection.json)

Then deploy the incident tagging playbook:

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FCyberlorians%2FCyberTriage%2Fmain%2Fdeploy%2Fcommercial%2Fset-cybertriage.json)

Then deploy the queue checker:

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FCyberlorians%2FCyberTriage%2Fmain%2Fdeploy%2Fcommercial%2Fcheck-cybertriage-queue.json)

## Parameters To Review

```text
SasBrokerFunctionAppName
FunctionHostStorageAccountName
BrokerSharedSecret
SasBrokerPackageUri
TargetDeviceTag
DestinationStorageAccountName
SasBrokerUrl
SasExpiryMinutes
SasPermissions
NotificationEmail
SentinelWorkspaceResourceGroup
SentinelWorkspaceName
SentinelWorkspaceCustomerId
SentinelWorkspaceSubscriptionId
WatchlistAlias
PollFrequencyMinutes
OnlineWindowMinutes
DefenderApiBaseUri
DefenderApiAudience
ArmBaseUri
ArmAudience
StorageBlobDnsSuffix
StorageTokenResource
```

Do not store the real `SasBrokerUrl` in Git if it contains a secret or function key.
