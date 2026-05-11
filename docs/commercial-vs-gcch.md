# Commercial vs GCCH

Commercial Azure and GCCH are different clouds. Do not assume every URL, connector, authority, or API behaves the same way.

This repo currently has:

```text
Commercial templates: shared workflow templates with commercial defaults
GCCH templates: Azure Government wrappers with GCCH defaults
```

## Commercial Values From The Lab

| Item | Commercial Value |
|---|---|
| Azure Resource Manager | `https://management.azure.com` |
| ARM managed identity audience | `https://management.azure.com/` |
| Log Analytics API | `https://api.loganalytics.io` |
| Log Analytics audience | `https://api.loganalytics.io` |
| MDE API URL | `https://api.securitycenter.microsoft.com` |
| MDE managed identity audience used in lab notes | `https://securitycenter.onmicrosoft.com/windowsatpservice` |
| Azure portal | `https://portal.azure.com` |
| Storage DNS suffix | `blob.core.windows.net` |

Important commercial MDE gotcha:

The token audience used for MDE managed identity is not the same as the API URL. Using the API URL as the audience caused 403 errors in previous testing.

## GCCH Values Verified May 9, 2026

These values were verified in an AzureUSGovernment tenant in `usgovvirginia`.
Runtime MDE collection still requires an onboarded active device.

| Item | GCCH / Azure Government Value |
|---|---|
| Azure Resource Manager | `https://management.usgovcloudapi.net/` |
| ARM managed identity audience | `https://management.usgovcloudapi.net/` |
| Azure portal | `https://portal.azure.us` |
| Storage DNS suffix | `blob.core.usgovcloudapi.net` |
| Microsoft Entra authority | `https://login.microsoftonline.us` |
| Microsoft Graph resource | `https://graph.microsoft.us/` |
| MDE API URL for GCC High | `https://api-gov.securitycenter.microsoft.us` |
| MDE token audience used by GCCH wrappers | `https://api-gov.securitycenter.microsoft.us` |
| WindowsDefenderATP app ID | `fc780465-2017-40d4-a0c5-307022471b92` |
| Logic App managed API connectors in `usgovvirginia` | `azuresentinel`, `azuremonitorlogs`, `office365`, `wdatp` present |

For regular GCC, Microsoft documents the Defender for Endpoint API endpoint as
`https://api-gcc.securitycenter.microsoft.us`. GCC High uses
`https://api-gov.securitycenter.microsoft.us`.

## How The Templates Handle Cloud Values

The shared templates expose these values as parameters instead of hardcoding
them:

```text
DefenderApiBaseUri
DefenderApiAudience
ArmBaseUri
ArmAudience
StorageBlobDnsSuffix
StorageTokenResource
```

The GCCH wrappers in [../deploy/gcch](../deploy/gcch) pass Azure Government
defaults into the shared templates in [../deploy/commercial](../deploy/commercial).

## Parameter Files

Use [../deploy/commercial/full.sample.parameters.json](../deploy/commercial/full.sample.parameters.json)
for commercial deployments and [../deploy/gcch/full.sample.parameters.json](../deploy/gcch/full.sample.parameters.json)
for Azure Government / GCCH deployments.

## Commercial Deployment Buttons

After this repo is pushed to GitHub, add buttons like this to the README and commercial deployment page:

```markdown
[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/<raw-commercial-template-url>)
```

## GCCH Deployment Buttons

Azure Government buttons use `https://portal.azure.us` and point at templates in
`deploy/gcch`:

```markdown
[![Deploy to Azure Government](https://aka.ms/deploytoazuregovbutton)](https://portal.azure.us/#create/Microsoft.Template/uri/<raw-gcch-template-url>)
```

## Connector Warning

Some Logic App managed connectors behave differently by cloud.

For each cloud, verify:

```text
azuresentinel connector exists
office365 connector exists, if notifications are used
azuremonitorlogs connector supports managed identity
raw HTTP managed identity can get an MDE token with WindowsDefenderATP app roles
```

If a connector is not available or does not support the needed auth mode, use raw HTTP actions with managed identity instead.

## GCCH Validation Checklist

Before calling GCCH ready, prove these steps in GCCH:

```text
SAS broker deploys
Function host storage works with managed identity
Broker health returns 200
Broker can create user-delegation SAS
Evidence storage keeps shared key disabled
Set-CyberTriage can tag MDE devices
Watchlist enqueue works
Queue checker can query Sentinel/Log Analytics
Collection playbook can submit MDE Live Response
Endpoint can upload artifact via SAS
Watchlist cleanup works
```
