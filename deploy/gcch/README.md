# GCCH Draft Deployment Templates

This folder contains draft GCCH copies of the commercial templates.

They are not final yet.

## Why They Are Draft

The current copied templates still include commercial cloud endpoints in some places.

Examples that need verification and parameterization:

```text
https://management.azure.com
https://api.loganalytics.io
https://api.securitycenter.microsoft.com
https://securitycenter.onmicrosoft.com/windowsatpservice
```

GCCH may require Azure Government endpoints, different managed API connector behavior, and different MDE token audience values.

## Before Using In GCCH

Verify:

1. Azure Government portal and ARM endpoint.
2. Log Analytics API endpoint and audience.
3. MDE API endpoint and token audience.
4. Logic App connector availability in the chosen Azure Government region.
5. Function host storage with managed identity.
6. Evidence storage with shared key disabled.
7. MDE Live Response permission model.

## Future Goal

Replace these draft copies with one of these approaches:

1. Separate fully tested GCCH templates.
2. One shared template with a `cloudSettings` parameter object.

Do not publish one-click GCCH deployment buttons until validation is complete.

## Draft Azure Government Button Pattern

These are the button patterns that will be used after GCCH validation. They intentionally point at draft templates today.

Collection playbook draft:

[![Deploy to Azure Government](https://aka.ms/deploytoazuregovbutton)](https://portal.azure.us/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FCyberlorians%2FCyberTriage%2Fmain%2Fdeploy%2Fgcch%2Fcybertriage-live-response-collection.gcch-draft.json)

Incident tagging playbook draft:

[![Deploy to Azure Government](https://aka.ms/deploytoazuregovbutton)](https://portal.azure.us/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FCyberlorians%2FCyberTriage%2Fmain%2Fdeploy%2Fgcch%2Fset-cybertriage.gcch-draft.json)

Queue checker draft:

[![Deploy to Azure Government](https://aka.ms/deploytoazuregovbutton)](https://portal.azure.us/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FCyberlorians%2FCyberTriage%2Fmain%2Fdeploy%2Fgcch%2Fcheck-cybertriage-queue.gcch-draft.json)
