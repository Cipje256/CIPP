# CIPP PoC cleanup inventory — AWAITING APPROVAL

**Generated:** 2026-09-14  
**Action:** Review only. **No deletions executed.**

Subscription: `f3873ae8-fb19-4972-bc44-21b7ceea508f`  
Tenant: `6e389209-800c-48cc-9091-295f2fb92fb8` (`coenework.onmicrosoft.com`)

---

## A. PROPOSED FOR DELETION (created for this CIPP PoC)

### A1. Azure resources — Resource group `CIPP` (westeurope)

All resources below have `createdTime` on **2026-09-14** during this PoC.

#### A1a. Successful NG stack (official container path)

| Name | Type | Created (UTC) |
| --- | --- | --- |
| `cippngm3syz` | Microsoft.Web/sites (linux container) | 2026-09-14T10:00:41Z |
| `cippngm3syz-plan` | Microsoft.Web/serverFarms (B2 Linux) | 2026-09-14T10:00:14Z |
| `cippngstgm3syz` | Microsoft.Storage/storageAccounts | 2026-09-14T10:00:13Z |
| `cippngm3syz` | Microsoft.KeyVault/vaults | 2026-09-14T10:01:14Z |

#### A1b. Failed/legacy SWA+Functions attempt (same PoC day — also delete)

| Name | Type | Created (UTC) |
| --- | --- | --- |
| `cipp-swa-m3syz` | Microsoft.Web/staticSites | 2026-09-14T09:12:46Z |
| `cippm3syz` | Microsoft.Web/sites (Function App) | 2026-09-14T09:13:11Z |
| `CIPP-srv-m3syz` | Microsoft.Web/serverFarms (Y1) | 2026-09-14T09:12:46Z |
| `cippstgm3syz` | Microsoft.Storage/storageAccounts | 2026-09-14T09:12:46Z |
| `cippm3syz` | Microsoft.KeyVault/vaults | 2026-09-14T09:13:58Z |

**Recommended action:** Delete **entire resource group `CIPP`** (removes A1a+A1b + deployment history + MI role assignments on that RG).

### A2. Azure resource group `CIPP-NG`

| Name | Notes |
| --- | --- |
| `CIPP-NG` | Empty RG created for PoC; deploy failed (no Owner). Tags: Purpose=CIPPDemo |

**Recommended action:** Delete RG `CIPP-NG`.

### A3. Entra app registrations (PoC-created 2026-09-14)

| Display name | App ID | Object ID | Created |
| --- | --- | --- | --- |
| **CIPP-SSO** | `5f75bbe3-2938-4626-8663-5e4912cf4516` | `65666170-f766-449e-9bba-ad12fa33a744` | 2026-09-14T10:16:12Z |
| **CIPP-SAM** | `92386ade-dede-44b6-8e87-12460482eb4d` | `d8f0a66d-95d0-40c6-b1c2-d26301c65e72` | 2026-09-14T10:46:15Z |

### A4. Enterprise applications / service principals (PoC)

| Display name | Type | App ID / note | Created |
| --- | --- | --- | --- |
| CIPP-SSO | Application | `5f75bbe3-…` | 2026-09-14 |
| CIPP-SAM | Application (+ ~73 app role assignments, oauth grants) | `92386ade-…` | 2026-09-14 |
| `cippngm3syz` | Managed Identity | goes away with Web App delete | 2026-09-14 |
| `cippm3syz` | Managed Identity | goes away with Function App delete | 2026-09-14 |

Deleting the **app registrations** removes the Application SPs and Graph grants.

### A5. CIPP service account

| UPN | Object ID | Created | Current roles |
| --- | --- | --- | --- |
| `CIPPServiceAccount@coenework.onmicrosoft.com` | `7b33a0eb-f647-4de8-98ab-95c85bc011e3` | 2026-09-14T10:36:25Z | Global Administrator |

**Recommended action:** Delete user (GA assignment removed with user).

### A6. Role assignments

| Scope | Assignment | Action |
| --- | --- | --- |
| RG `CIPP` | MI `cippm3syz` → Contributor | Removed when RG/resources deleted |
| RG `CIPP` | Template-created MI → KV/storage roles | Removed with RG |
| Directory | GA on CIPPServiceAccount | Removed when user deleted |
| Directory | CIPP-SAM app roles / oauth2 grants | Removed when CIPP-SAM app deleted |

No proposal to change `thomas@coene.work` subscription Contributor / Usage Billing Contributor.

### A7. CIPP tenant configuration

Lives in storage tables inside `cippngstgm3syz` (`tenantMode`, `Tenants`, `allowedUsers`, FeatureFlags, etc.).  
**Removed automatically** when storage / RG is deleted. No separate Entra tenant-wide config beyond the apps/user above.

### A8. GitHub resources

| Item | Action |
| --- | --- |
| https://github.com/Cipje256/CIPP | **KEEP** |
| Actions probe workflows on fork | **KEEP** |
| `thc256v2` anything | Already abandoned — do not touch |

---

## B. EXPLICITLY KEEP (existed before / unrelated)

### B1. Azure resource groups — DO NOT DELETE

| Resource group | Reason |
| --- | --- |
| `rg-teslamate-prod` | TeslaMate — **NEVER DELETE** |
| `rg-teslamate` | TeslaMate — **NEVER DELETE** |
| `rg-dranco-travel-poc` | Unrelated demo |
| `rg-windows` | Pre-existing |
| `rg-linux` | Pre-existing |
| `rg-externalid-lab` | Pre-existing |
| `NetworkWatcherRG` | Platform |
| `DefaultResourceGroup-WEU` | Platform |

### B2. Entra — DO NOT DELETE

| Object | App ID | Reason |
| --- | --- | --- |
| SP **`cipp3fmpr`** | `b7bf42e7-bde1-49f8-b575-96807afe526a` | Created **2026-04-17** — **before** this PoC |
| `Dranco-Travel-App` | `9d8de0c9-…` | Unrelated |
| `func-dranco-travel-poc` | `bfb53d23-…` | Unrelated |
| `sp-terraform-homelab` | `d0f4247a-…` | Pre-existing |
| `NSG-RemoteAccess-Test` | `c95c601a-…` | Pre-existing |
| `P2P Server` | `1b5240fb-…` | Pre-existing |
| All non-CIPP users (e.g. `thomas@coene.work`) | — | Tenant identities |

### B3. Local / automation — DO NOT DELETE

| Path | Reason |
| --- | --- |
| `C:\CIPP\` | Timeline, notes, creds, tooling |
| `C:\CIPP-Cipje256\` | Fork clone |
| `DEMO-RUNBOOK.md` + `demo-automation/` | Redeploy readiness |

### B4. Azure RBAC on operator — DO NOT REMOVE

- `thomas@coene.work` Owner on RG `CIPP` (RG may disappear; subscription Contributor stays)
- Subscription-level Contributor / Usage Billing Contributor

---

## C. Proposed cleanup command (after your approval only)

```powershell
cd C:\CIPP-Cipje256
.\demo-automation\scripts\Remove-CippDemo.ps1 -Execute `
  -DeleteResourceGroupCIPP `
  -DeleteResourceGroupCIPPNG `
  -DeleteEntraApps `
  -DeleteServiceAccount
```

Optional follow-up: purge soft-deleted Key Vaults if name reuse is needed immediately.

---

## D. Approval checklist

Reply with approval to delete **all of section A**, or call out exclusions (e.g. keep service account, keep SSO app, etc.).

**Nothing has been deleted yet.**
