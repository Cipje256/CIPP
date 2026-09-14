#Requires -Version 5.1
<#
.SYNOPSIS
  Remove temporary bootstrap directory roles from CIPP service account.
#>
[CmdletBinding()]
param(
  [string]$UserPrincipalName = "CIPPServiceAccount@coenework.onmicrosoft.com",
  [switch]$KeepGlobalAdmin
)

$ErrorActionPreference = "Stop"
$token = az account get-access-token --resource https://graph.microsoft.com --query accessToken -o tsv
$h = @{ Authorization = "Bearer $token" }

$user = Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/users/$([uri]::EscapeDataString($UserPrincipalName))?`$select=id" -Headers $h
$memberOf = Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/users/$($user.id)/memberOf" -Headers $h
$roles = $memberOf.value | Where-Object { $_.'@odata.type' -eq '#microsoft.graph.directoryRole' }

$removeNames = @(
  "Application Administrator",
  "Privileged Role Administrator",
  "User Administrator"
)
if (-not $KeepGlobalAdmin) { $removeNames += "Global Administrator" }

foreach ($role in $roles) {
  if ($removeNames -contains $role.displayName) {
    Write-Host "Removing $($role.displayName)"
    Invoke-RestMethod -Method DELETE -Uri "https://graph.microsoft.com/v1.0/directoryRoles/$($role.id)/members/$($user.id)/`$ref" -Headers $h
  }
}

$after = Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/users/$($user.id)/memberOf" -Headers $h
$left = ($after.value | Where-Object { $_.'@odata.type' -eq '#microsoft.graph.directoryRole' }).displayName
Write-Host "Remaining roles: $($left -join ', ')"
