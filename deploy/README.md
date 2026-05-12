# CyberTriage Deployment

The full step-by-step deployment guide lives on the main repo page:

[Repo README](../README.md)

ARM templates in this folder:

| File | Purpose |
|---|---|
| `commercial/cybertriage-full-deployment.json` | One-click full deploy for Commercial Azure. |
| `gcch/cybertriage-full-deployment.json` | One-click full deploy for Azure Government / GCC High. |
| `commercial/sas-broker-function.json` | SAS broker Function App only (Commercial). |
| `gcch/sas-broker-function.json` | SAS broker Function App only (GCCH). |
| `commercial/cybertriage-live-response-collection.json` | Collection Logic App only (Commercial). |
| `gcch/cybertriage-live-response-collection.json` | Collection Logic App only (GCCH). |
| `commercial/set-cybertriage.json` | Incident tagging Logic App only (Commercial). |
| `gcch/set-cybertriage.json` | Incident tagging Logic App only (GCCH). |
| `commercial/check-cybertriage-queue.json` | Queue checker Logic App only (Commercial). |
| `gcch/check-cybertriage-queue.json` | Queue checker Logic App only (GCCH). |
