#Requires -Version 5.1
<#
.SYNOPSIS
  Remove CIPP PoC resources. Defaults to -WhatIf. Requires explicit -Execute after inventory approval.
#>
[CmdletBinding(SupportsShouldProcess)]
param(
  [string]$ConfigPath = (Join-Path $PSScriptRoot "..\config\demo-env.json"),
  [switch]$Execute,
  [switch]$DeleteResourceGroupCIPP,
  [switch]$DeleteResourceGroupCIPPNG,
  [switch]$DeleteEntraApps,
  [switch]$DeleteServiceAccount
)

$ErrorActionPreference = "Stop"
$cfg = Get-Content $ConfigPath -Raw | ConvertFrom-Json

Write-Host @"

=== CIPP CLEANUP GUARDRAILS ===
NEVER delete: $($cfg.doNotTouchResourceGroups -join ', ')
NEVER delete SP: $($cfg.doNotDeleteServicePrincipals.displayName -join ', ')
KEEP: GitHub $($cfg.githubRepo), local $($cfg.localClone), $($cfg.localTooling)

"@

if (-not $Execute) {
  Write-Host "Dry run only. Re-run with -Execute after approval, plus the delete switches you want."
  Write-Host "Example:"
  Write-Host "  .\Remove-CippDemo.ps1 -Execute -DeleteResourceGroupCIPP -DeleteResourceGroupCIPPNG -DeleteEntraApps -DeleteServiceAccount"
  return
}

$token = az account get-access-token --resource https://graph.microsoft.com --query accessToken -o tsv
$h = @{ Authorization = "Bearer $token" }

if ($DeleteResourceGroupCIPP) {
  if ($PSCmdlet.ShouldProcess("RG CIPP", "Delete resource group and ALL contained resources")) {
    az group delete -n CIPP --yes --no-wait
    Write-Host "Delete started: RG CIPP"
  }
}

if ($DeleteResourceGroupCIPPNG) {
  if ($PSCmdlet.ShouldProcess("RG CIPP-NG", "Delete empty PoC resource group")) {
    az group delete -n CIPP-NG --yes --no-wait
    Write-Host "Delete started: RG CIPP-NG"
  }
}

if ($DeleteEntraApps) {
  foreach ($app in $cfg.pocCreatedApps) {
    $found = Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/applications?`$filter=appId eq '$($app.appId)'" -Headers $h
    foreach ($a in $found.value) {
      if ($PSCmdlet.ShouldProcess($a.displayName, "Delete application $($a.appId)")) {
        Invoke-RestMethod -Method DELETE -Uri "https://graph.microsoft.com/v1.0/applications/$($a.id)" -Headers $h
        Write-Host "Deleted app $($a.displayName)"
      }
    }
  }
}

if ($DeleteServiceAccount) {
  $upn = $cfg.serviceAccountUpn
  try {
    $u = Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/users/$([uri]::EscapeDataString($upn))?`$select=id,userPrincipalName" -Headers $h
    if ($PSCmdlet.ShouldProcess($upn, "Delete service account")) {
      Invoke-RestMethod -Method DELETE -Uri "https://graph.microsoft.com/v1.0/users/$($u.id)" -Headers $h
      Write-Host "Deleted $upn"
    }
  } catch {
    Write-Host "Service account not found or already deleted."
  }
}

Write-Host "Cleanup requests submitted. Verify Azure portal + Entra before demo day redeploy."
