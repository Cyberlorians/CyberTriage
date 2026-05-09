# Commercial Deployment Templates

These templates are the commercial Azure starter templates copied from the validated lab deployment.

## Files

| File | Purpose |
|---|---|
| `set-cybertriage.json` | Incident-triggered playbook that tags MDE devices and enqueues them into the Sentinel watchlist. |
| `check-cybertriage-queue.json` | Scheduled queue checker that selects active/recent MDE devices and triggers collection. |
| `cybertriage-live-response-collection.json` | Collection playbook that generates SAS and submits MDE Live Response. |

## Deploy Order

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
```

Do not store the real `SasBrokerUrl` in Git if it contains a secret or function key.
