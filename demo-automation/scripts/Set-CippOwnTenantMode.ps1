#Requires -Version 5.1
<#
.SYNOPSIS
  Set CIPP tenantMode=owntenant and seed the demo tenant row.
  Entity shape matches Invoke-ExecPartnerMode.ps1 / successful PoC.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$StorageAccountName,
  [Parameter(Mandatory)][string]$TenantId,
  [Parameter(Mandatory)][string]$DefaultDomain,
  [string]$DisplayName,
  [string]$ResourceGroup = "CIPP"
)

$ErrorActionPreference = "Stop"
if (-not $DisplayName) { $DisplayName = $DefaultDomain }

$key = az storage account keys list -g $ResourceGroup -n $StorageAccountName --query "[0].value" -o tsv
if (-not $key) { throw "Cannot read storage key for $StorageAccountName" }

function Set-Entity {
  param([string]$Table, [hashtable]$Entity)
  $flat = @()
  foreach ($k in $Entity.Keys) { $flat += "$k=$($Entity[$k])" }
  az storage entity insert `
    --account-name $StorageAccountName `
    --account-key $key `
    --table-name $Table `
    --entity $flat `
    --if-exists replace `
    -o none
}

Write-Host "Setting tenantMode state=owntenant (PartitionKey=Setting / RowKey=PartnerModeSetting)"
Set-Entity -Table "tenantMode" -Entity @{
  PartitionKey = "Setting"
  RowKey       = "PartnerModeSetting"
  state        = "owntenant"
}

Write-Host "Seeding Tenants for $DefaultDomain / $TenantId"
Set-Entity -Table "Tenants" -Entity @{
  PartitionKey      = "Tenants"
  RowKey            = $TenantId
  customerId        = $TenantId
  defaultDomainName = $DefaultDomain
  displayName       = $DisplayName
  initialDomainName = $DefaultDomain
  domains           = "PartnerTenant"
  Excluded          = "false"
  RequiresRefresh   = $true
  GraphErrorCount   = "0"
  LastGraphError    = ""
  ExcludeDate       = ""
  ExcludeUser       = ""
}

Write-Host "Own tenant mode configured."
