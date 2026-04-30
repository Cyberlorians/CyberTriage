# CyberTriage Live Response Collection - Solution Flow

## Overview

CyberTriage Live Response Collection is a push-button forensic triage pipeline
integrated with Microsoft Defender XDR and Microsoft Sentinel.

A device can be requested for collection from an incident, from automation, or
from a manually maintained Sentinel watchlist. The request is held in a durable
pending list until the device is online and ready for Defender Live Response.
After collection succeeds, the artifact is uploaded to a tenant-controlled Azure
Storage account and the analyst is notified by email.

No agents to install. No standing credentials. No shared keys.

---

## Simple Flow

The solution uses three Logic Apps and one Sentinel watchlist.

| Component | Role |
|---|---|
| `Set-CyberTriage` | Receives incident-driven requests, tags the Defender device, and adds it to the pending list. |
| `CyberTriage Pending` watchlist | Durable worklist of devices that still need collection. Devices can remain here while offline. |
| `Check-CyberTriageQueue` | Polls the pending list, checks whether each device is online, tags manually added devices if needed, and dispatches only ready devices. |
| `CyberTriage-LiveResponse-Collection` | Runs Defender Live Response, retrieves the output, uploads it to Blob Storage, sends email, and clears the tag after success. |

The Defender tag `ForensicCollect` is removed only after all of these are true:

1. The device is online.
2. Live Response ran successfully.
3. The collection file was uploaded successfully.

If the device is offline, or if Live Response/upload fails, the device remains
pending so it can be retried later.

---

## Request Sources

Devices can enter the workflow in three ways.

| Source | What Happens |
|---|---|
| Sentinel/XDR incident playbook | `Set-CyberTriage` tags the Defender device and writes a row to `CyberTriage Pending`. |
| Manual watchlist upload | An analyst adds one or more devices directly to `CyberTriage Pending`; `Check-CyberTriageQueue` will tag the device before dispatch. |
| Retry / failure handling | If a device is offline or a collection attempt fails, the watchlist row stays pending or is updated with the latest status/reason. |

This means the watchlist acts as the durable collection registry. It can hold
devices that are offline for hours or days without losing the request.

---

## End-to-End Architecture

```text
Sentinel/XDR Incident, Automation, or Manual Watchlist Upload
   |
   v
Set-CyberTriage
   - Used for incident-driven requests
   - Finds the Defender device
   - Adds Defender tag: ForensicCollect
   - Adds/updates row in CyberTriage Pending
   |
   v
CyberTriage Pending Watchlist
   - Durable list of devices awaiting collection
   - Holds offline devices until they come back online
   - Tracks status, timestamps, attempts, and last failure reason
   |
   v
Check-CyberTriageQueue
   - Runs every 15 minutes, or manually on demand
   - Reads pending watchlist rows
   - Resolves/validates Defender device ID
   - Adds ForensicCollect tag if the row was manually uploaded
   - Checks Defender/Sentinel telemetry for online activity
   - Dispatches only online devices
   - Leaves offline devices pending
   |
   v
CyberTriage-LiveResponse-Collection
   - Opens Defender Live Response session
   - Runs the CyberTriage collection package
   - Retrieves the output file
   - Uploads the artifact to Azure Blob Storage
   - Sends notification email
   - Removes ForensicCollect tag only after success
   - Marks collection complete or leaves the device pending for retry
```

---

## Pending Watchlist State

The `CyberTriage Pending` watchlist is the operational state store.

Recommended columns:

| Column | Purpose |
|---|---|
| `MdatpDeviceId` | Defender device ID, used as the primary lookup key when available. |
| `DeviceName` | Host name/FQDN for analyst readability and manual uploads. |
| `IncidentId` | Related Sentinel/XDR incident, if applicable. |
| `TagName` | Usually `ForensicCollect`. |
| `Status` | `Pending`, `Offline`, `Dispatched`, `Collected`, `FailedRetryable`, or `FailedFinal`. |
| `EnqueuedTime` | When the collection request was created. |
| `LastCheckedTime` | Last time the poller evaluated the device. |
| `LastSeenTime` | Most recent Defender/Sentinel telemetry timestamp used for online check. |
| `DispatchAttempts` | Number of times Live Response was actually attempted. |
| `LastFailureReason` | Most recent reason the device stayed pending or collection failed. |

Example behavior:

| Condition | Result |
|---|---|
| Device is offline | Row remains in `CyberTriage Pending`; status/reason is updated. |
| Device is online | Poller tags if needed, then dispatches to the collection Logic App. |
| Live Response succeeds and upload succeeds | Tag is removed; row is marked `Collected` or removed from the pending list. |
| Live Response fails or upload fails | Tag stays; row remains pending or `FailedRetryable` for another attempt. |

---

## Security Model

All Logic App calls to external services use System-Assigned Managed Identity.
No client secrets, no storage keys, and no SAS tokens are stored anywhere in the
solution.

| Hop | Auth | Permission |
|---|---|---|
| Logic Apps -> Defender Devices API | Managed Identity | `Machine.Read.All` |
| Logic Apps -> Defender Live Response | Managed Identity | `Machine.LiveResponse` |
| Logic Apps -> Defender tag management | Managed Identity | `Machine.ReadWrite.All` |
| Logic Apps -> Sentinel watchlist | Managed Identity | Microsoft Sentinel Contributor / required watchlist permissions |
| Logic Apps -> Azure Blob Storage | Managed Identity | `Storage Blob Data Contributor` |
| Analyst -> Blob Storage | Entra ID + RBAC | `Storage Blob Data Reader/Contributor` |

---

## Data Protection

| Layer | Mechanism |
|---|---|
| In transit | TLS 1.2 on every hop. |
| At rest | Azure Storage AES-256 encryption; customer-managed key option available. |
| Access control | Entra ID + RBAC; no shared-key workflow access. |
| Network access | Storage firewall restricted to approved networks/service endpoints/private access model. |
| Audit | Storage diagnostic logs capture read/write activity. |

---

## Customer Access to Results

Three tenant-compliant access options are supported. All use Entra ID; no shared
keys are required.

1. Azure Portal -> Storage account -> Storage browser -> container view.
2. Azure Storage Explorer with Entra sign-in.
3. AzCopy for bulk sync to a local folder.

```powershell
azcopy login --tenant-id <your-tenant-id>
azcopy sync "https://<storageaccount>.blob.core.windows.net/<container>" `
            "C:\CyberTriage" --recursive
```

---

## Key Operational Rules

- The watchlist is the durable pending registry; devices can remain there while
  offline.
- The Defender tag is an analyst-visible marker and collection signal, but the
  watchlist is the source of truth for workflow state.
- The poller dispatches only devices that appear online based on recent
  Defender/Sentinel telemetry.
- The collector removes the tag only after Live Response and blob upload both
  succeed.
- Failed or offline devices remain pending and can be retried automatically.
- Concurrency should remain controlled to avoid overlapping Live Response
  sessions on the same host.
