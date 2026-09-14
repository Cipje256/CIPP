#Requires -Version 5.1
<#
.SYNOPSIS
  End-to-end CIPP demo deploy (Azure + pauses for MFA/consent).
.NOTES
  Official path: CyberDrain cipp-deploy.json Linux container Web App (B2).
#>
[CmdletBinding()]
param(
  [string]$ResourceGroup = "CIPP",
  [string]$Location = "westeurope",
  [string]$BaseName = "CIPPNG",
  [string]$ConfigPath = (Join-Path $PSScriptRoot "..\config\demo-env.json"),
  [string]$TemplatePath = (Join-Path $PSScriptRoot "..\templates\cipp-deploy.json"),
  [switch]$SkipServiceAccount,
  [switch]$SkipDeploy
)

$ErrorActionPreference = "Stop"
$envCfg = Get-Content $ConfigPath -Raw | ConvertFrom-Json
$sub = $envCfg.subscriptionId
$tenantId = $envCfg.tenantId
$saUpn = $envCfg.serviceAccountUpn

function Write-Step($m) { Write-Host "`n=== $m ===" -ForegroundColor Cyan }
function Write-Human($m) { Write-Host "`n>>> HUMAN REQUIRED: $m" -ForegroundColor Yellow }

Write-Step "Preflight"
az account show -o none 2>$null
if ($LASTEXITCODE -ne 0) { Write-Human "Run: az login"; az login | Out-Null }
az account set --subscription $sub
$acct = az account show | ConvertFrom-Json
if ($acct.tenantId -ne $tenantId) { throw "Wrong tenant $($acct.tenantId); expected $tenantId" }

$ghUser = gh api user --jq .login 2>$null
if ($ghUser -and $ghUser -ne $envCfg.githubOrgOrUser) {
  Write-Warning "GitHub CLI user is '$ghUser' (expected $($envCfg.githubOrgOrUser)). Do not use thc256v2."
}

$owner = az role assignment list -g $ResourceGroup --assignee $envCfg.operatorUpn --query "[?roleDefinitionName=='Owner']" -o tsv 2>$null
if (-not $owner) {
  Write-Warning "No Owner assignment detected for $($envCfg.operatorUpn) on RG $ResourceGroup. roleAssignments will fail without Owner."
}

if (-not $SkipDeploy) {
  Write-Step "Ensure resource group"
  az group create -n $ResourceGroup -l $Location --tags Purpose=CIPPDemo Environment=Demo | Out-Null

  if (-not (Test-Path $TemplatePath)) { throw "Template missing: $TemplatePath" }

  Write-Step "Deploy ARM (B2 Linux container)"
  $depName = "cipp-demo-$(Get-Date -Format 'yyyyMMddHHmmss')"
  $outFile = Join-Path $env:TEMP "$depName-out.json"
  az deployment group create -g $ResourceGroup -n $depName -f $TemplatePath `
    --parameters baseName=$BaseName updateKeyVaultSecrets=true `
    --query properties.outputs -o json | Tee-Object -FilePath $outFile
  $outputs = Get-Content $outFile -Raw | ConvertFrom-Json
  $hostname = $outputs.hostname.value
  $webApp = $outputs.webAppName.value
  $kv = $outputs.keyVaultName.value
  Write-Host "URL: https://$hostname  WebApp: $webApp  KV: $kv"
} else {
  $webApp = az webapp list -g $ResourceGroup --query "[?contains(name,'cipp')].name | [0]" -o tsv
  $hostname = "$webApp.azurewebsites.net"
  $kv = $webApp
}

Write-Step "Wait for health Ready"
$base = "https://$hostname"
$deadline = (Get-Date).AddMinutes(10)
do {
  try {
    $h = Invoke-RestMethod "$base/api/setup/health" -TimeoutSec 30
    Write-Host ("health phase={0} ready={1}" -f $h.phase, $h.ready)
    if ($h.ready -eq $true -and $h.phase -eq "Ready") { break }
  } catch {
    Write-Host "health not ready yet: $($_.Exception.Message)"
  }
  Start-Sleep -Seconds 15
} while ((Get-Date) -lt $deadline)

if (-not $SkipServiceAccount) {
  Write-Step "Provision CIPP service account"
  & (Join-Path $PSScriptRoot "New-CippServiceAccount.ps1") -UserPrincipalName $saUpn
}

Write-Human @"
1) Enroll MFA for $saUpn (password in C:\CIPP\cipp-service-account.cred.txt or demo-automation\local\).
2) Open $base/setup and complete CIPP Setup Wizard as the service account:
   - Create CIPP-SSO
   - Create CIPP-SAM + admin consent
   - Complete partner/own-tenant OAuth so refresh token is stored
Press Enter after the wizard finishes (dashboard reachable)...
"@
[void](Read-Host)

Write-Step "Repair SAM secret if Step 3 was certificate-only"
& (Join-Path $PSScriptRoot "Repair-CippSamSecret.ps1") -ResourceGroup $ResourceGroup -KeyVaultName $kv -WebAppName $webApp

Write-Step "Own Tenant Mode + seed demo tenant"
$stg = az storage account list -g $ResourceGroup --query "[?contains(name,'cippng') || contains(name,'stg')].name | [0]" -o tsv
# Prefer storage matching web app prefix
$stgExact = az storage account list -g $ResourceGroup --query "[?starts_with(name, 'cippng')].name | [0]" -o tsv
if ($stgExact) { $stg = $stgExact }
& (Join-Path $PSScriptRoot "Set-CippOwnTenantMode.ps1") -StorageAccountName $stg `
  -TenantId $tenantId -DefaultDomain $envCfg.defaultDomain

Write-Step "Validate Graph via CIPP-SAM"
& (Join-Path $PSScriptRoot "Test-CippGraphAccess.ps1") -KeyVaultName $kv

Write-Step "Remove bootstrap directory roles (keep GA)"
& (Join-Path $PSScriptRoot "Clear-CippBootstrapRoles.ps1") -UserPrincipalName $saUpn -KeepGlobalAdmin

Write-Step "DONE"
Write-Host "CIPP URL: $base"
Write-Host "Next: open UI, refresh tenant selector, confirm users/devices/mailboxes/Secure Score."
