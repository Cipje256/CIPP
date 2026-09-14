#Requires -Version 5.1
<#
.SYNOPSIS
  Validate CIPP-SAM can read tenant, users, devices, mailboxes, Secure Score.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$KeyVaultName
)

$ErrorActionPreference = "Stop"
$appId = az keyvault secret show --vault-name $KeyVaultName --name applicationid --query value -o tsv
$secret = az keyvault secret show --vault-name $KeyVaultName --name applicationsecret --query value -o tsv
$tenantId = az keyvault secret show --vault-name $KeyVaultName --name tenantid --query value -o tsv

if ($secret -eq "AppSecret" -or [string]::IsNullOrWhiteSpace($secret)) {
  throw "applicationsecret is still placeholder. Run Repair-CippSamSecret.ps1 first."
}

$body = @{
  client_id     = $appId
  client_secret = $secret
  scope         = "https://graph.microsoft.com/.default"
  grant_type    = "client_credentials"
}
$tokenResp = Invoke-RestMethod -Method POST -Uri "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token" -Body $body
$h = @{ Authorization = "Bearer $($tokenResp.access_token)" }

function Try-Get($name, $uri) {
  try {
    $r = Invoke-RestMethod -Uri $uri -Headers $h
    Write-Host "OK  $name"
    return $r
  } catch {
    Write-Host "FAIL $name : $($_.Exception.Message)"
    return $null
  }
}

$org = Try-Get "organization" "https://graph.microsoft.com/v1.0/organization?`$select=displayName,verifiedDomains"
$users = Try-Get "users" "https://graph.microsoft.com/v1.0/users?`$top=5&`$select=displayName,userPrincipalName,mail"
$devices = Try-Get "devices" "https://graph.microsoft.com/v1.0/devices?`$top=5&`$select=displayName,operatingSystem"
$mailUsers = Try-Get "users-with-mail" "https://graph.microsoft.com/v1.0/users?`$filter=mail ne null&`$top=5&`$count=true&`$select=mail,userPrincipalName" 
# Exchange reports often need reports read
$mbox = Try-Get "mailboxUsage" "https://graph.microsoft.com/v1.0/reports/getMailboxUsageDetail(period='D7')"
$score = Try-Get "secureScore" "https://graph.microsoft.com/v1.0/security/secureScores?`$top=1"
$intune = Try-Get "intune-managedDevices" "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?`$top=5"

if ($org) { Write-Host "  org=$($org.value[0].displayName)" }
if ($users) { Write-Host "  usersReturned=$($users.value.Count)" }
if ($devices) { Write-Host "  devicesReturned=$($devices.value.Count)" }
if ($score -and $score.value) {
  $s = $score.value[0]
  Write-Host "  secureScore=$($s.currentScore)/$($s.maxScore)"
}
if (-not $intune) {
  Write-Host "NOTE: Intune managedDevices often Forbidden on this demo tenant — expected."
}

$rt = az keyvault secret show --vault-name $KeyVaultName --name refreshtoken --query value -o tsv 2>$null
if ($rt -and $rt.Length -gt 20 -and $rt -notmatch "placeholder|RefreshToken") {
  Write-Host "OK  refreshtoken length=$($rt.Length)"
} else {
  Write-Warning "refreshtoken missing/placeholder — complete Setup Wizard OAuth."
}
