#Requires -Version 5.1
<#
.SYNOPSIS
  Fix CIPP Setup Step 3 when SAM is certificate-only and applicationsecret is placeholder.
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)][string]$ResourceGroup,
  [Parameter(Mandatory)][string]$KeyVaultName,
  [Parameter(Mandatory)][string]$WebAppName,
  [string]$SamDisplayName = "CIPP-SAM"
)

$ErrorActionPreference = "Stop"

function Get-GraphToken { az account get-access-token --resource https://graph.microsoft.com --query accessToken -o tsv }

$token = Get-GraphToken
$h = @{ Authorization = "Bearer $token"; "Content-Type" = "application/json" }

$apps = Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/applications?`$filter=displayName eq '$SamDisplayName'" -Headers $h
$app = $apps.value | Select-Object -First 1
if (-not $app) { throw "App registration '$SamDisplayName' not found. Complete Setup Wizard Step 2 first." }

$appId = $app.appId
$objectId = $app.id
$tenantId = (az account show --query tenantId -o tsv)

Write-Host "CIPP-SAM appId=$appId objectId=$objectId"

# Create client secret
$secretBody = @{
  passwordCredential = @{
    displayName = "CIPP-Setup-Autofix-$(Get-Date -Format 'yyyyMMddHHmm')"
    endDateTime = (Get-Date).ToUniversalTime().AddYears(2).ToString("o")
  }
} | ConvertTo-Json
$secret = Invoke-RestMethod -Method POST -Uri "https://graph.microsoft.com/v1.0/applications/$objectId/addPassword" -Headers $h -Body $secretBody
$secretText = $secret.secretText
if (-not $secretText) { throw "Failed to create client secret" }

# Ensure KV secrets (needs access via az)
az keyvault secret set --vault-name $KeyVaultName --name applicationid --value $appId -o none
az keyvault secret set --vault-name $KeyVaultName --name applicationsecret --value $secretText -o none
az keyvault secret set --vault-name $KeyVaultName --name tenantid --value $tenantId -o none

# Disable certificate-only feature flag in Azure Table storage if present
$stg = az webapp config appsettings list -g $ResourceGroup -n $WebAppName --query "[?name=='AzureWebJobsStorage' || name=='StorageConnectionString' || name=='ConnectionStrings__AzureStorage'].value | [0]" -o tsv
# Prefer reading from storage account linked in RG
$storageName = az storage account list -g $ResourceGroup --query "[?contains(name,'$($WebAppName.Substring(0,[Math]::Min(8,$WebAppName.Length)))') || contains(name,'stg')].name | [0]" -o tsv
if ($storageName) {
  $key = az storage account keys list -g $ResourceGroup -n $storageName --query "[0].value" -o tsv
  # FeatureFlags table PartitionKey/RowKey used by CIPP — best effort
  try {
    az storage entity merge --account-name $storageName --account-key $key --table-name FeatureFlags `
      --entity PartitionKey=CertificateAuthentication RowKey=CertificateAuthentication Value=false -o none 2>$null
    az storage entity insert --account-name $storageName --account-key $key --table-name FeatureFlags `
      --entity PartitionKey=CertificateAuthentication RowKey=CertificateAuthentication Value=false `
      --if-exists replace -o none 2>$null
    Write-Host "FeatureFlags CertificateAuthentication=false (best effort)"
  } catch {
    Write-Warning "Could not set FeatureFlags table: $($_.Exception.Message)"
  }
}

Write-Host "Restarting web app $WebAppName"
az webapp restart -g $ResourceGroup -n $WebAppName -o none
Start-Sleep -Seconds 20
Write-Host "SAM secret repair complete. Re-check Setup Wizard Step 3 / tenant OAuth if refresh token still missing."
