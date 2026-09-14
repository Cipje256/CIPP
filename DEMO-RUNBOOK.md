# CIPP Live Demo Runbook

**Status:** PoC completed successfully on 2026-09-14 (Europe/Brussels).  
**Purpose:** One-shot redeploy for presentation day with minimal human interaction.  
**Official method:** CyberDrain Linux container Web App (`deployment/cipp-deploy.json`), **not** legacy SWA + Functions.

---

## 0. Canonical identifiers

| Item | Value |
| --- | --- |
| Entra tenant ID | `6e389209-800c-48cc-9091-295f2fb92fb8` |
| Initial domain | `coenework.onmicrosoft.com` |
| Azure subscription | Visual Studio Enterprise MPN `f3873ae8-fb19-4972-bc44-21b7ceea508f` |
| Azure operator | `thomas@coene.work` (Global Admin in Entra; must be **Owner** on target RG) |
| GitHub account | **Cipje256** only — never `thc256v2` (billing lock) |
| GitHub fork | https://github.com/Cipje256/CIPP |
| Local clones | `C:\CIPP-Cipje256` (fork), `C:\CIPP` (notes + tooling + timeline artifacts) |
| Automation | `demo-automation/` (this repo) and `C:\CIPP\demo-automation\` |
| Demo mode | Single Tenant – Own Tenant Mode (`tenantMode=owntenant`) |
| Service account UPN | `CIPPServiceAccount@coenework.onmicrosoft.com` |
| Successful PoC URL | `https://cippngm3syz.azurewebsites.net` (names change per deploy suffix) |

**Do not use:** customer/CSP subscriptions, `thc256v2`, legacy SWA deploy paths.

**Never touch:** `rg-teslamate*`, `rg-dranco-travel-poc`, or any non-CIPP RGs.

---

## 1. Exact successful deployment sequence

1. **Authenticate** Azure CLI as `thomas@coene.work` on MPN subscription; GitHub CLI as `Cipje256`.
2. **Ensure fork** `Cipje256/CIPP` exists (from `KelvinTegelaar/CIPP`) and local clone is current.
3. **Fetch official template** `cipp-deploy.json` from CyberDrain/CIPP `deployment/` (or use repo copy under `demo-automation/templates/`).
4. **Create / reuse RG** in `westeurope` where the operator is **Owner** (Contributor alone cannot create `roleAssignments`).
5. **Deploy ARM** with `baseName` e.g. `CIPPNG` (suffix is `uniqueString` → names like `cippngxxxxx`).
6. **Wait for health** `GET /api/setup/health` → `ready:true`, `phase:Ready`; UI `/` and `/setup` HTTP 200.
7. **Provision service account** via Graph (Setup Wizard does **not** create it): User Admin + App Admin + Priv Role Admin + temporary GA for bootstrap.
8. **Human:** MFA enroll for service account; sign into Setup Wizard as that account.
9. **Human:** Setup Wizard — create SSO app, create CIPP-SAM, admin consent, partner/own-tenant OAuth (refresh token).
10. **Autofix if Step 3 “Application ID is not valid”:** SAM was certificate-only → create client secret, write Key Vault `applicationid` / `applicationsecret` / `tenantid`, set FeatureFlags `CertificateAuthentication=false`, restart Web App.
11. **Set Own Tenant Mode** (`tenantMode=owntenant`) and seed Tenants table for the demo tenant.
12. **Validate Graph** via CIPP-SAM: org, users, mailboxes/mail users, Entra devices, Secure Score.
13. **Strip bootstrap roles** from service account; keep **Global Administrator** only (required for `owntenant`).
14. **Mark tenant refresh** / open CIPP UI and confirm tenant selector.

Presentation-day shortcut: run `demo-automation/scripts/Deploy-CippDemo.ps1` then follow interactive pauses only.

---

## 2. Commands used (successful path)

### 2.1 Auth / context

```powershell
az login
az account set --subscription f3873ae8-fb19-4972-bc44-21b7ceea508f
gh auth status
# Must show Cipje256 — if thc256v2 appears:
gh auth logout
gh auth login   # device flow as Cipje256
gh auth setup-git
```

### 2.2 Template + deploy

```powershell
$rg = "CIPP"
$loc = "westeurope"
$baseName = "CIPPNG"
$template = "C:\CIPP-Cipje256\cipp-deploy.json"   # or demo-automation\templates\cipp-deploy.json

az group create -n $rg -l $loc --tags Purpose=CIPPDemo Environment=Demo
# Operator MUST be Owner on $rg (not only Contributor on subscription)

az deployment group create `
  -g $rg `
  -n "cipp-demo-$(Get-Date -Format 'yyyyMMddHHmm')" `
  -f $template `
  --parameters baseName=$baseName updateKeyVaultSecrets=true `
  -o json
```

Expected outputs: `hostname`, `webAppName`, `keyVaultName` (e.g. `cippngm3syz.azurewebsites.net`).

### 2.3 Health checks

```powershell
$base = "https://<webAppName>.azurewebsites.net"
Invoke-RestMethod "$base/api/setup/health"
# Expect: status=ok, ready=true, phase=Ready
Invoke-WebRequest "$base/" -UseBasicParsing | Select-Object StatusCode
Invoke-WebRequest "$base/setup" -UseBasicParsing | Select-Object StatusCode
```

### 2.4 Service account (Graph)

Use `demo-automation/scripts/New-CippServiceAccount.ps1` (preferred), or equivalent Graph calls:

- Create user `CIPPServiceAccount@coenework.onmicrosoft.com`
- Activate directory roles if needed, then assign:
  - Application Administrator
  - Privileged Role Administrator
  - User Administrator
  - Global Administrator (temporary for wizard; **keep** after cleanup for `owntenant`)

Store password only under `C:\CIPP\*.cred.txt` / `demo-automation/local/` — never commit.

### 2.5 Step-3 SAM secret autofix

```powershell
.\demo-automation\scripts\Repair-CippSamSecret.ps1 -KeyVaultName <kv> -WebAppName <webApp> -ResourceGroup $rg
```

What it does: create CIPP-SAM client secret → set KV secrets → disable `CertificateAuthentication` → restart app.

### 2.6 Own-tenant mode + seed

```powershell
.\demo-automation\scripts\Set-CippOwnTenantMode.ps1 `
  -StorageAccountName <cippngstg...> `
  -TenantId 6e389209-800c-48cc-9091-295f2fb92fb8 `
  -DefaultDomain coenework.onmicrosoft.com
```

### 2.7 Post-cleanup roles

```powershell
.\demo-automation\scripts\Clear-CippBootstrapRoles.ps1 `
  -UserPrincipalName CIPPServiceAccount@coenework.onmicrosoft.com `
  -KeepGlobalAdmin
```

---

## 3. Authentication points requiring human interaction

| # | When | Who / what | Why unavoidable |
| --- | --- | --- | --- |
| 1 | Start | Azure CLI `az login` | Microsoft interactive / device auth |
| 2 | Start | GitHub `gh auth login` as **Cipje256** | Device code / browser |
| 3 | After SA create | MFA enroll for `CIPPServiceAccount@…` | Tenant MFA; Graph cannot fully enroll |
| 4 | Setup Wizard | Browser login as service account | CIPP first-run / Easy Auth |
| 5 | Setup Wizard | Admin consent for CIPP-SSO + CIPP-SAM | Entra admin consent screen |
| 6 | Setup Wizard | Partner / own-tenant OAuth (refresh token) | Microsoft identity interactive |
| 7 | Validation | Optional dashboard sign-in as admin | Session cookie / SSO |

Everything else is scriptable.

---

## 4. Known errors encountered

| ID | Symptom | Root cause |
| --- | --- | --- |
| E1 | GitHub Actions: account locked due to billing | `thc256v2` billing lock (even public/`ubuntu-latest`) |
| E2 | `git push` still as wrong user | Cached `thc256v2` credentials |
| E3 | ARM deploy fails on `roleAssignments/write` | Operator only Contributor on subscription / RG without Owner |
| E4 | Deploy to empty `CIPP-NG` failed | Same as E3 — no Owner on that RG |
| E5 | Setup Wizard does not create service account | By design — manual/prep Create User |
| E6 | Role assign `Request_ResourceNotFound` for App/User Admin template IDs | Role not activated in tenant yet — activate then assign |
| E7 | MFA / CA automation fails | No Entra P1/P2 or Graph MFA APIs denied |
| E8 | Step 3: “The Application ID is not valid…” | Step 2 created **certificate-only** SAM; KV `applicationsecret` left as placeholder `AppSecret`; UI gates on `/api/ExecSamSecretStatus` + `/api/ExecListAppId` |
| E9 | Tenants table empty after wizard | Default partner/GDAP mode; need `tenantMode=owntenant` + seed |
| E10 | Intune `managedDevices` Forbidden | Demo tenant Intune backend; not a CIPP deploy bug |
| E11 | Early `GET /` flaky / PowerShell `$HOME` overwrite | Transient warmup; health endpoint is source of truth |

---

## 5. Exact fixes

| ID | Fix |
| --- | --- |
| E1 | Use GitHub **Cipje256**; abandon `thc256v2`. Official container deploy does **not** require Actions for publish. |
| E2 | `gh auth logout` → login Cipje256 → `gh auth setup-git`; verify `gh api user` |
| E3/E4 | Deploy only into RG where `thomas@coene.work` is **Owner** (PoC: RG `CIPP`) |
| E5 | Run `New-CippServiceAccount.ps1` before wizard |
| E6 | POST activate role template, then create roleAssignment |
| E7 | Human MFA enrollment; skip CA automation on free Entra |
| E8 | `Repair-CippSamSecret.ps1` (client secret + KV + flag + restart) |
| E9 | `Set-CippOwnTenantMode.ps1` |
| E10 | Document as known demo limitation; Entra devices + Secure Score still work |
| E11 | Retry health; do not fail on first `/` probe |

---

## 6. Expected output after every major stage

| Stage | Expected |
| --- | --- |
| Azure deploy | ProvisioningState `Succeeded`; outputs hostname/webApp/KV |
| Resources | Web App (linux container `ghcr.io/cyberdrain/cipp:latest`), Plan **B2**, StorageV2, Key Vault (name = web app name) |
| Health | `/api/setup/health` → `ready:true`, `phase:Ready` |
| UI pre-auth | `/setup` title “Craft Setup” (or current CIPP branding) |
| After SA | User exists; bootstrap directory roles assigned |
| After wizard | Apps **CIPP-SSO**, **CIPP-SAM**; KV has real `applicationid`, `applicationsecret`, `refreshtoken` (not placeholders) |
| After own-tenant | Table `tenantMode` = `owntenant`; Tenants row for demo tenant |
| Graph validation | Org OK; users ≥1; mail users OK; Entra devices ≥0; Secure Score numbers; Intune may Forbidden |
| Role cleanup | SA has **Global Administrator** only |
| Final | Homepage 200; health Ready |

---

## 7. Rollback / cleanup procedure

**Safe order (after inventory approval):**

1. Delete Azure resources created for this PoC (entire RG `CIPP` and empty `CIPP-NG`, or listed resources).
2. Delete Entra app registrations **CIPP-SAM** and **CIPP-SSO** (SPs and grants go with them).
3. Delete user `CIPPServiceAccount@coenework.onmicrosoft.com`.
4. Confirm managed identities removed with Web Apps.
5. Soft-delete purge optional (KV/apps) if names must be reused immediately.
6. **Keep** GitHub fork, local `C:\CIPP*`, `demo-automation/`.
7. **Never** delete TeslaMate RGs, Dranco, or pre-existing SP `cipp3fmpr` (2026-04-17).

Use `demo-automation/scripts/Remove-CippDemo.ps1 -WhatIf` first, then `-Confirm:$true` after approval.

---

## 8. Complete successful PoC timeline (2026-09-14, Europe/Brussels)

| Local time | Event |
| --- | --- |
| ~10:58 | Inspection / wrong GH path abandoned |
| ~11:01–11:04 | Azure MPN confirmed; RG `CIPP` path started |
| ~11:04–11:35 | Blocked: Actions billing lock on `thc256v2` |
| ~12:01–12:02 | Logged out `thc256v2`; logged in **Cipje256** |
| ~12:07 | Fork `Cipje256/CIPP`; clone `C:\CIPP-Cipje256` |
| ~12:10 | Actions probe success (optional; not required for container publish) |
| ~12:08–12:12 | Official `cipp-deploy.json` → `cippngm3syz` (B2) |
| ~12:12–12:13 | Health Ready; Setup UI up |
| ~12:36 | Service account created + bootstrap roles |
| ~12:36–12:46 | Human MFA + Setup Wizard (SSO, SAM) |
| ~12:46 | CIPP-SAM created (certificate-only initially) |
| ~12:48–12:54 | Autofix client secret + KV + restart (E8) |
| ~12:58 | Dashboard accessible |
| ~13:01 | `owntenant` + tenant seed + Graph validation |
| ~13:02 | Bootstrap roles removed; GA kept; final health OK |

Relative log also in `C:\CIPP\deploy-timeline-v2.txt` and `C:\CIPP\timeline-final.txt`.

---

## 9. Permissions & roles cheat sheet

### Azure

| Principal | Need |
| --- | --- |
| Deployer (`thomas@coene.work`) | **Owner** on target RG (roleAssignments) |
| Web App system MI | Template-assigned (KV secrets user, storage, etc.) |

### Entra – service account (bootstrap)

Application Administrator, Privileged Role Administrator, User Administrator, Global Administrator.

### Entra – service account (steady / own tenant)

**Global Administrator** only.

### CIPP-SAM

Multi-tenant app with Graph application permissions granted via wizard consent (dozens of app roles). Refresh token in Key Vault for delegated CIPP operations.

### CIPP-SSO

App registration for Easy Auth / CIPP login; secret in Key Vault (`SSOAppId` / `SSOAppSecret`).

---

## 10. Presentation-day one-liner

```powershell
cd C:\CIPP-Cipje256
.\demo-automation\scripts\Deploy-CippDemo.ps1 -ResourceGroup CIPP -BaseName CIPPNG
```

Then complete only the interactive prompts (MFA + Setup Wizard consent). Scripts pause with clear instructions at each human gate.

---

## 11. Artifact map

| Path | Contents |
| --- | --- |
| `DEMO-RUNBOOK.md` | This document |
| `demo-automation/config/demo-env.json` | Non-secret identifiers |
| `demo-automation/templates/cipp-deploy.json` | Official ARM template snapshot |
| `demo-automation/scripts/*.ps1` | Deploy / SA / SAM repair / own-tenant / cleanup / validate |
| `C:\CIPP\deploy-timeline-v2.txt` | Verbose PoC timeline |
| `C:\CIPP\FINAL-REPORT.md` | Short PoC report |
| `C:\CIPP\*.cred.txt` | Local secrets — **never commit** |
