#Requires -Version 5.1
<#
.SYNOPSIS
  Print proposed CIPP PoC deletion inventory (no deletes).
#>
[CmdletBinding()]
param(
  [string]$ConfigPath = (Join-Path $PSScriptRoot "..\config\demo-env.json")
)

$cfg = Get-Content $ConfigPath -Raw | ConvertFrom-Json
az account set --subscription $cfg.subscriptionId | Out-Null

Write-Host "`n## Azure resources (RG CIPP)" -ForegroundColor Cyan
az resource list -g CIPP --query "[].{name:name,type:type,created:createdTime}" -o table

Write-Host "`n## Azure resource groups (PoC)" -ForegroundColor Cyan
az group list --query "[?name=='CIPP' || name=='CIPP-NG'].{name:name,location:location,tags:tags}" -o json

Write-Host "`n## KEEP forever (examples)" -ForegroundColor Green
$cfg.doNotTouchResourceGroups | ForEach-Object { Write-Host " KEEP RG $_" }

Write-Host "`n## Entra apps (PoC delete candidates)" -ForegroundColor Cyan
$cfg.pocCreatedApps | ForEach-Object { Write-Host " DELETE candidate: $($_.displayName) $($_.appId)" }

Write-Host "`n## Entra KEEP" -ForegroundColor Green
$cfg.doNotDeleteServicePrincipals | ForEach-Object { Write-Host " KEEP SP $($_.displayName) $($_.appId) — $($_.reason)" }

Write-Host "`n## Service account DELETE candidate" -ForegroundColor Cyan
Write-Host " $($cfg.serviceAccountUpn)"

Write-Host "`n## GitHub / local KEEP" -ForegroundColor Green
Write-Host " KEEP $($cfg.githubRepoUrl)"
Write-Host " KEEP $($cfg.localClone)"
Write-Host " KEEP $($cfg.localTooling)"
Write-Host " KEEP demo-automation/"
