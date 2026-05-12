# Fabrikam - Reverse-engineer IaC for payments webhook handler

**Issue:** [#5](https://github.com/quintindk/todone-aug-2026/issues/5)
**Status:** In Progress
**Customer:** Fabrikam
**Reference:** N/A

## Overview

Fabrikam's retail payments webhook handler was built in the Azure portal during a two-day offsite in February 2026 and has been running in dev (`rg-fabrikam-dev-webhook`, subscription `quintindekok-demo`, region `southafricanorth`) ever since. Compliance now needs it in prod by end of May 2026 with IaC, an architecture diagram, a security write-up, and a deployment guide. No Bicep / ARM / Terraform exists - everything is being reverse-engineered from the live resources.

## Key Findings

Initial resource inventory in `rg-fabrikam-dev-webhook` (region `southafricanorth`):

| Name                              | Type                                       | Role                                  |
|-----------------------------------|--------------------------------------------|---------------------------------------|
| `func-fabrikam-webhook-uvqvxk`    | `Microsoft.Web/sites`                      | Function App - webhook handler        |
| `plan-fabrikam-webhook-uvqvxk`    | `Microsoft.Web/serverFarms`                | App Service Plan                      |
| `stfabrkwhuvqvxk`                 | `Microsoft.Storage/storageAccounts`        | Function App runtime storage          |
| `fabrikamwebhookhackuvqv`         | `Microsoft.Storage/storageAccounts`        | Second storage - role TBD             |
| `cosmos-fabrikam-webhook-uvqvxk`  | `Microsoft.DocumentDB/databaseAccounts`    | Persistence                           |
| `kv-fabrk-wh-uvqvxk`              | `Microsoft.KeyVault/vaults`                | Secrets                               |
| `appi-fabrikam-webhook-uvqvxk`    | `Microsoft.Insights/components`            | App Insights                          |
| `log-fabrikam-webhook-uvqvxk`     | `Microsoft.OperationalInsights/workspaces` | Log Analytics (App Insights backing)  |

Naming pattern: `<purpose>-fabrikam-webhook-<suffix>` with `uvqvxk` as a randomised suffix. Storage accounts compress (24-char limit, no hyphens). Parameterise both `name prefix` and `suffix` in Bicep.

## Scope

**In scope:**
- Resource discovery (`az resource list` + per-resource `show`) for all 8 resources.
- Bicep IaC that recreates dev and parameterises for prod (env name, SKUs, names, region).
- Architecture diagram (draw.io, Azure stencils) - data flow, identity, secrets.
- Security write-up - identity (managed identity vs keys), secrets (KV references), data (Cosmos encryption, TLS), network (public/private endpoints), RBAC.
- Deployment guide - prereqs, parameter file, `az deployment group create`, smoke test.

**Out of scope:**
- Code changes to the Function App.
- Migration of dev data to prod.
- DR / multi-region (flagged as a follow-up if relevant).

## Architecture / Design

```
TBD - populated after per-resource discovery (Function App kind/runtime,
plan SKU, Cosmos API + containers, KV access model, storage account roles,
network exposure).
```

## Notes

- Source: email from Lerato Mokoena (Senior Engineering Manager, Fabrikam Payments Platform), Fri 2026-05-08 16:47 SAST.
- Read access on the subscription already granted.
- Deadline: end of May 2026.
- Next: deep-dive each resource (`az ... show` in parallel), build Bicep modules, then diagram + security write-up + deployment guide.
