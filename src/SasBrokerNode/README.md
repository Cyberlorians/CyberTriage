# CyberTriage SAS Broker - Node Flex Function

This folder contains the no-shared-key SAS broker used by the deployed lab
migration. It runs as an Azure Functions Flex Consumption app with managed
identity-backed host storage and generates user-delegation SAS URLs for the
CyberTriage results container.

The function does not use Azure Storage account keys. It calls Azure Storage
with its managed identity to request a user delegation key, then signs a
short-lived container SAS for the collector.

## Endpoints

- `GET /api/health` returns `{ "status": "ok" }`.
- `POST /api/generate-cybertriagesas?brokerCode=<secret>` returns the SAS
  response used by the collection Logic App.

`brokerCode` is an app-level broker secret stored in the Function App setting
`BROKER_SHARED_SECRET`. It is not a storage account key. The collection Logic
App receives the full broker URL as the secure `SasBrokerUrl` parameter.

## Request

```json
{
  "storageAccountName": "<evidence-storage-account>",
  "containerName": "cybertriage-results",
  "permissions": "racwdl",
  "ttlMinutes": 1440,
  "correlationId": "<logic-app-run-id>",
  "deviceId": "<mde-device-id>",
  "deviceName": "<hostname>"
}
```

## Response

```json
{
  "sasUrl": "https://<account>.<blob-dns-suffix>/<container>?<sas>",
  "expiresOnUtc": "2026-05-07T18:00:00Z",
  "storageAccountName": "<evidence-storage-account>",
  "containerName": "cybertriage-results",
  "permissions": "racwdl",
  "authMode": "user_delegation_sas"
}
```

## Required RBAC

Assign the broker Function App managed identity these roles on the CyberTriage
evidence storage account:

- `Storage Blob Delegator`
- `Storage Blob Data Contributor`

For Azure Functions host storage in a no-shared-key tenant, assign the Function
App managed identity host-storage data roles on the Function host storage
account as well. These are Azure Functions runtime permissions, not
CyberTriage evidence storage permissions and not Sentinel watchlist queue
permissions. The full commercial template grants this baseline set:

- `Storage Blob Data Contributor`
- `Storage Queue Data Contributor`
- `Storage Table Data Contributor`

If the selected Function hosting model still cannot start with managed identity
host storage, use these broader troubleshooting roles only while proving the
runtime path:

- `Storage Blob Data Owner`
- `Storage Account Contributor`

The Function host storage app setting should use managed identity settings such
as `AzureWebJobsStorage__accountName` and `AzureWebJobsStorage__credential`, not
an `AzureWebJobsStorage` connection string containing an account key.

## Sovereign Cloud Settings

The broker defaults to commercial Azure:

```text
STORAGE_BLOB_DNS_SUFFIX=blob.core.windows.net
STORAGE_TOKEN_RESOURCE=https://storage.azure.com/
```

For Azure Government / GCCH, deploy the broker with:

```text
STORAGE_BLOB_DNS_SUFFIX=blob.core.usgovcloudapi.net
STORAGE_TOKEN_RESOURCE=https://storage.azure.com/
```

The generated SAS URL uses the configured blob DNS suffix. The storage token
resource is exposed as an app setting so it can be changed if a sovereign tenant
requires a different Storage OAuth resource later.

## Network Requirement

The broker and endpoints must be able to reach the evidence storage account data
plane. In this lab migration, `<evidence-storage-account>` uses:

```text
allowSharedKeyAccess=false
publicNetworkAccess=Enabled
networkRuleSet.defaultAction=Allow
```

If a customer requires `publicNetworkAccess=Disabled`, add private endpoints and
network paths for both the broker Function and target endpoints before using
direct Blob upload.