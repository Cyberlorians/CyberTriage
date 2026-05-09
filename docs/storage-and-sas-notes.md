# Storage And SAS Notes

This page explains the storage design in plain language. It also records the May 8 lab failure so we do not repeat it.

## Short Version

The endpoint does not get a storage account key. The endpoint gets a short-lived SAS URL.

The SAS URL is created by a small Azure Function called the SAS broker. The broker uses its managed identity to ask Azure Storage for a user delegation key, then it builds a SAS URL for the target container.

The endpoint uses that SAS URL to upload the encrypted Cyber Triage artifact.

## Why SAS Is Used

SAS lets us give the endpoint temporary, limited access to one storage container.

This is better than giving the endpoint a storage account key because:

- The SAS expires.
- The SAS can be scoped to one container.
- Shared key access can stay disabled.
- The endpoint never learns the storage account key.
- Access can be audited through storage logs.

## Required Storage Posture For The Pilot

For the validated pilot model, use this posture on the evidence storage account:

```text
publicNetworkAccess = Enabled
defaultAction = Allow
IP rules = none
VNet rules = none
allowSharedKeyAccess = false
```

This means:

- The public endpoint exists.
- The storage account is reachable over normal Azure public networking.
- Storage account keys still cannot be used.
- SAS and Entra-based access are the intended paths.

## Why Public Endpoint Still Needs To Be Reachable

A SAS URL does not magically bypass storage networking.

Before the SAS exists, the broker Function must call the storage account to get a user delegation key.

If the storage account public endpoint is disabled, or if firewall rules block the broker, SAS generation fails.

The order is:

```text
Logic App asks broker for SAS
Broker asks Storage for user delegation key
Storage returns key material
Broker builds SAS URL
Logic App passes SAS URL to MDE Live Response
Endpoint uploads artifact using SAS URL
```

If the broker cannot reach Storage at step 2, nothing after that works.

## The May 8 Failure

What worked on May 7:

- Shared key access was disabled.
- The broker generated a user-delegation SAS.
- MDE Live Response passed the SAS to the endpoint.
- The endpoint uploaded a Cyber Triage artifact.

What broke on May 8:

- Policy or automation changed storage networking.
- The evidence storage account became unreachable to the broker path.
- The Function host storage account also had `publicNetworkAccess=Disabled`.
- The broker Function returned `503 Site Unavailable`.
- The Logic App action `Generate_CyberTriage_Sas` failed.
- `Run_LR_Collection` was skipped.
- No MDE machine action was created for that failed run.

The actor seen in Activity Log was:

```text
Display name: MCAPSGov-AutomationApp
App ID: eadea216-1d5c-4a4b-beaf-4f145e6b1cb4
Policy assignment: Azure_Security_Baseline
Approx time: 2026-05-08 00:39Z
```

The fix used in the lab:

```text
<evidence-storage-account>:
  publicNetworkAccess = Enabled
  defaultAction = Allow
  IP rules = none
  VNet rules = none
  allowSharedKeyAccess = false

<function-host-storage-account>:
  publicNetworkAccess = Enabled
  defaultAction = Allow
  IP rules = none
  VNet rules = none
  allowSharedKeyAccess = false
```

Then the broker Function was restarted.

After the fix:

```text
/api/health = 200 OK
Generate SAS test = success
authMode = user_delegation_sas
shared keys = disabled
```

## Evidence Storage Roles

The SAS broker managed identity needs these roles on the evidence storage account:

```text
Storage Blob Delegator
Storage Blob Data Contributor
```

`Storage Blob Delegator` allows the identity to request a user delegation key.

`Storage Blob Data Contributor` allows the identity to work with blob/container permissions needed by the broker flow.

## Function Host Storage Roles

The Function app also has its own host storage account. This is separate from the evidence storage account.

For a Flex Consumption Function using managed identity host storage, the Function managed identity needs access to its host storage. The lab used:

```text
Storage Blob Data Contributor
Storage Blob Data Owner
Storage Queue Data Contributor
Storage Table Data Contributor
Storage Account Contributor
```

The exact minimum set should be tightened after repeatable deployment testing.

## What Not To Do

Do not print SAS URLs in logs.

Do not store SAS URLs in Git.

Do not pass storage account keys to MDE Live Response.

Do not set `allowSharedKeyAccess=true` unless the customer explicitly accepts that model.

Do not assume a VM is collectable just because Azure says it is running. MDE Live Response needs the endpoint to be active in MDE.

## How To Test The Broker Safely

Test health first:

```powershell
Invoke-WebRequest -Uri 'https://<function-app>.azurewebsites.net/api/health'
```

Then test SAS generation, but only print metadata:

```powershell
# Do not print the sasUrl value.
# Print only success, expiry, storage account, container, permissions, and authMode.
```

A healthy broker response includes:

```text
success = true
expiresOnUtc = <future time>
storageAccountName = <account>
containerName = cybertriage-results
permissions = racwdl
authMode = user_delegation_sas
```
