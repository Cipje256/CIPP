#Requires -Version 5.1
<#
.SYNOPSIS
  Create CIPP service account and assign bootstrap directory roles.
#>
[CmdletBinding()]
param(
  [string]$UserPrincipalName = "CIPPServiceAccount@coenework.onmicrosoft.com",
  [string]$DisplayName = "CIPP Service Account",
  [string]$UsageLocation = "BE",
  [string]$CredOutPath = "C:\CIPP\cipp-service-account.cred.txt"
)

$ErrorActionPreference = "Stop"

function Get-GraphToken {
  az account get-access-token --resource https://graph.microsoft.com --query accessToken -o tsv
}

function Invoke-Graph {
  param([string]$Method, [string]$Uri, [object]$Body)
  $token = Get-GraphToken
  $headers = @{ Authorization = "Bearer $token"; "Content-Type" = "application/json" }
  if ($Body) {
    return Invoke-RestMethod -Method $Method -Uri $Uri -Headers $headers -Body ($Body | ConvertTo-Json -Depth 8)
  }
  return Invoke-RestMethod -Method $Method -Uri $Uri -Headers $headers
}

function Ensure-DirectoryRole {
  param([string]$TemplateId, [string]$Name)
  $roles = Invoke-Graph GET "https://graph.microsoft.com/v1.0/directoryRoles"
  $existing = $roles.value | Where-Object { $_.roleTemplateId -eq $TemplateId }
  if ($existing) { return $existing }
  Write-Host "Activating directory role: $Name"
  try {
    return Invoke-Graph POST "https://graph.microsoft.com/v1.0/directoryRoles" @{ roleTemplateId = $TemplateId }
  } catch {
    Start-Sleep -Seconds 2
    $roles = Invoke-Graph GET "https://graph.microsoft.com/v1.0/directoryRoles"
    return ($roles.value | Where-Object { $_.roleTemplateId -eq $TemplateId })
  }
}

function Ensure-RoleMember {
  param([string]$RoleId, [string]$UserId, [string]$Name)
  try {
    Invoke-Graph POST "https://graph.microsoft.com/v1.0/directoryRoles/$RoleId/members/`$ref" @{
      "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$UserId"
    } | Out-Null
    Write-Host "Assigned $Name"
  } catch {
    if ($_.Exception.Message -match "already exist|Conflict") {
      Write-Host "$Name already assigned"
    } else {
      Write-Warning "Assign $Name failed: $($_.Exception.Message)"
    }
  }
}

# Password: avoid committing; write to local cred file only
$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
$bytes = New-Object byte[] 24
$rng.GetBytes($bytes)
$pwd = ([Convert]::ToBase64String($bytes) -replace '[+/=]', 'A') + "!Aa1"

$user = $null
try {
  $user = Invoke-Graph GET "https://graph.microsoft.com/v1.0/users/$([uri]::EscapeDataString($UserPrincipalName))?`$select=id,userPrincipalName,displayName"
  Write-Host "Service account already exists: $($user.userPrincipalName)"
} catch {
  Write-Host "Creating $UserPrincipalName"
  $user = Invoke-Graph POST "https://graph.microsoft.com/v1.0/users" @{
    accountEnabled    = $true
    displayName       = $DisplayName
    mailNickname      = ($UserPrincipalName -split "@")[0]
    userPrincipalName = $UserPrincipalName
    usageLocation     = $UsageLocation
    passwordProfile   = @{
      password = $pwd
      forceChangePasswordNextSignIn = $false
    }
  }
  $dir = Split-Path $CredOutPath -Parent
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  @"
UPN=$UserPrincipalName
PASSWORD=$pwd
CREATED=$(Get-Date -Format o)
"@ | Set-Content -Path $CredOutPath -Encoding UTF8
  Write-Host "Password written to $CredOutPath"
}

# Bootstrap roles (activate if needed). GA required for owntenant steady-state too.
$roleMap = @(
  @{ Name = "Application Administrator"; TemplateId = "9b895d92-2cd3-44c7-9d02-a6f93c2d1d8e" },
  @{ Name = "Privileged Role Administrator"; TemplateId = "e8611ab8-c189-46e8-94e1-60213ab1f814" },
  @{ Name = "User Administrator"; TemplateId = "fe930be7-5e62-47db-91af-98c3a49a551b" },
  @{ Name = "Global Administrator"; TemplateId = "62e90394-69f5-4237-9190-012177145e10" }
)

foreach ($r in $roleMap) {
  $role = Ensure-DirectoryRole -TemplateId $r.TemplateId -Name $r.Name
  if (-not $role) { Write-Warning "Could not activate $($r.Name)"; continue }
  Ensure-RoleMember -RoleId $role.id -UserId $user.id -Name $r.Name
}

Write-Host "NEXT HUMAN STEP: enroll MFA for $UserPrincipalName, then run CIPP Setup Wizard as this account."
