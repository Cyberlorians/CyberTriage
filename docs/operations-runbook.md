# Operations Runbook

This page is for day-to-day use after the deployment exists.

## Normal Test Flow

1. Pick an active MDE device.
2. Add the `ForensicCollect` tag or trigger `Set-CyberTriage` from an incident.
3. Confirm a row appears in `ForensicCollectQueue`.
4. Wait for the queue checker or run it manually.
5. Confirm `CyberTriage-LiveResponse-Collection` runs.
6. Confirm `Generate_CyberTriage_Sas` succeeds.
7. Confirm `Run_LR_Collection` succeeds.
8. Confirm the MDE machine action succeeds.
9. Confirm the watchlist row is removed.
10. Wait for the encrypted blob artifact.

## What Current Queue Rows Mean

| Status | Meaning |
|---|---|
| blank | Eligible/pending. |
| `Pending` | Eligible/pending. |
| `BlockedLiveResponse` | Another Live Response action was active; retry later. |
| `FailedRetryable` | A previous attempt failed but should be tried again later. |
| `Offline` | Device was not active when checked. |

## Why A Row May Stay In The Queue

A row stays in the queue when:

- The device is inactive in MDE.
- The device has no recent `DeviceInfo` telemetry.
- A retry time is set in `RetryAfterUtc`.
- Another Live Response action is already active.
- The collection playbook failed before cleanup.

## How To Check MDE Status

Use the MDE API or portal.

You care about:

```text
healthStatus
lastSeen
machineTags
```

Good shape:

```text
healthStatus = Active
machineTags includes ForensicCollect
```

Bad shape:

```text
healthStatus = Inactive
```

A running Azure VM is not enough. The endpoint must be active in MDE.

## Healthy Logic App Actions

In `CyberTriage-LiveResponse-Collection`, healthy actions look like:

```text
Generate_CyberTriage_Sas: Succeeded
Run_LR_Collection: Succeeded
Remove_Tag: Succeeded
Delete_Watchlist_Item: Succeeded
Run_Summary: Succeeded
```

`Email_Started` may fail if the Office 365 connector is not authorized. That does not block Live Response.

## Healthy MDE Action

A healthy machine action looks like:

```text
type: LiveResponse
status: Succeeded
commands: Completed
requestor: CyberTriage-LiveResponse-Collection
```

## Blob Names

Probe or noise blob:

```text
cttest-blob
```

Real Cyber Triage artifacts:

```text
cttout_<device>_<timestamp>.json.gz.enc.01
cttout_<device>_<timestamp>.json.gz.enc.02
```

## If SAS Fails

Check these in order:

1. Broker `/api/health` returns 200.
2. Function host storage is reachable.
3. Evidence storage public endpoint is reachable by the broker.
4. Shared key access is disabled but Entra/SAS path works.
5. Broker managed identity has `Storage Blob Delegator`.
6. Broker managed identity has `Storage Blob Data Contributor`.
7. The Logic App has the correct broker URL.
8. The broker secret is correct.

## If Live Response Fails

Check these in order:

1. Device is active in MDE.
2. Device is onboarded.
3. Device has no active pending LR action.
4. `CyberTriageCollector.exe` exists in the MDE Live Response Library.
5. `Run-CyberTriage.ps1` exists in the MDE Live Response Library.
6. The MDE connector or managed identity has permission to run Live Response.
7. The endpoint can reach Blob Storage over HTTPS.

## If Blob Does Not Appear

The Logic App confirms the Live Response handoff, not the full collector upload.

If LR succeeded but the blob is missing:

1. Wait longer for full collection.
2. Check endpoint `C:\CyberTriage\work\cttout.status.json` if you have access.
3. Check endpoint logs under `C:\CyberTriage\work`.
4. Confirm SAS did not expire too quickly.
5. Confirm endpoint can reach Blob Storage.
6. Confirm collector process launched.

## Safe Evidence Handling

The Cyber Triage output is encrypted.

Customer standard password used in lab:

```text
infected
```

Only share that password with people authorized to open the evidence in the Cyber Triage product.
