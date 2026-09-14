# CIPP demo automation

See root [DEMO-RUNBOOK.md](../DEMO-RUNBOOK.md).

## Quick start (presentation day)

```powershell
cd C:\CIPP-Cipje256
.\demo-automation\scripts\Deploy-CippDemo.ps1
```

## Scripts

| Script | Purpose |
| --- | --- |
| `Deploy-CippDemo.ps1` | Full deploy + pauses for MFA/consent |
| `New-CippServiceAccount.ps1` | Create SA + bootstrap roles |
| `Repair-CippSamSecret.ps1` | Fix certificate-only SAM / placeholder secret |
| `Set-CippOwnTenantMode.ps1` | `owntenant` + seed tenant |
| `Test-CippGraphAccess.ps1` | Validate Graph via SAM |
| `Clear-CippBootstrapRoles.ps1` | Remove temp roles; keep GA |
| `Show-CippCleanupInventory.ps1` | Print delete inventory |
| `Remove-CippDemo.ps1` | Cleanup (**requires `-Execute`**) |

Config (no secrets): `config/demo-env.json`  
Template: `templates/cipp-deploy.json`
