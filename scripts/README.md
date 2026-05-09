# Scripts

These scripts are helpers. They do not replace the detailed deployment guide.

## Files

| File | Purpose |
|---|---|
| `Grant-CyberTriagePermissions.ps1` | Grants Azure RBAC roles to the SAS broker and Logic App managed identities after deployment. Optional MDE app-role grants are included for raw-HTTP managed identity designs. |
| `Test-CyberTriageDeployment.ps1` | Runs read-only checks for storage posture, broker health, watchlist rows, recent Logic App runs, and recent blobs. |

## Safety

Scripts should not print:

```text
SAS URLs
broker shared secrets
function keys
storage account keys
```

If a script needs to test SAS generation, it should print only metadata such as `success`, `expiresOnUtc`, and `authMode`.
