# Commercial vs GCCH

Commercial Azure and GCCH are different clouds. Do not assume every URL, connector, authority, or API behaves the same way.

This repo currently has:

```text
Commercial templates: validated lab starter
GCCH templates: draft copies pending endpoint verification
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

## GCCH Values To Verify

These must be verified in the actual GCCH tenant before final deployment:

| Item | GCCH / Azure Government Candidate |
|---|---|
| Azure Resource Manager | `https://management.usgovcloudapi.net` |
| ARM managed identity audience | `https://management.usgovcloudapi.net/` |
| Azure portal | `https://portal.azure.us` |
| Storage DNS suffix | `blob.core.usgovcloudapi.net` |
| Microsoft Entra authority | `https://login.microsoftonline.us` |
| MDE API URL | Verify tenant cloud. Common government endpoints differ by environment. |
| MDE token audience | Verify with Defender API docs and tenant service principal. Do not guess. |
| Logic App managed API connector availability | Verify in Azure Government region. |

## Why The GCCH Templates Are Draft

The current templates have commercial values embedded in variables such as:

```text
https://management.azure.com
https://api.loganalytics.io
https://api.securitycenter.microsoft.com
https://securitycenter.onmicrosoft.com/windowsatpservice
```

For GCCH, these should become parameters or environment variables instead of hardcoded strings.

## Recommended Template Improvement

Create a cloud settings object like this:

```json
{
  "cloudName": "commercial",
  "armBaseUri": "https://management.azure.com",
  "armAudience": "https://management.azure.com/",
  "logAnalyticsApiBaseUri": "https://api.loganalytics.io",
  "logAnalyticsAudience": "https://api.loganalytics.io",
  "mdeApiBaseUri": "https://api.securitycenter.microsoft.com",
  "mdeAudience": "https://securitycenter.onmicrosoft.com/windowsatpservice",
  "storageBlobDnsSuffix": "blob.core.windows.net"
}
```

Then create one parameter file for commercial and one for GCCH.

## Commercial Deployment Buttons

After this repo is pushed to GitHub, add buttons like this to the README and commercial deployment page:

```markdown
[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/<raw-commercial-template-url>)
```

## GCCH Deployment Buttons

After GCCH templates are verified and pushed to GitHub, add Azure Government buttons like this:

```markdown
[![Deploy to Azure Government](https://aka.ms/deploytoazuregovbutton)](https://portal.azure.us/#create/Microsoft.Template/uri/<raw-gcch-template-url>)
```

Do not publish a one-click GCCH button until the endpoint values are verified.

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
