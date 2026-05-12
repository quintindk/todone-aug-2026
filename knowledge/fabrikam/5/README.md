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
| `func-fabrikam-webhook-uvqvxk`    | `Microsoft.Web/sites`                      | Function App - .NET 8 isolated Linux  |
| `plan-fabrikam-webhook-uvqvxk`    | `Microsoft.Web/serverFarms`                | App Service Plan - Y1 Consumption     |
| `stfabrkwhuvqvxk`                 | `Microsoft.Storage/storageAccounts`        | Function App runtime storage          |
| `fabrikamwebhookhackuvqv`         | `Microsoft.Storage/storageAccounts`        | Payload archive (`payload-archive`)   |
| `cosmos-fabrikam-webhook-uvqvxk`  | `Microsoft.DocumentDB/databaseAccounts`    | SQL API serverless, db `webhook`, container `events` (PK `/merchantId`, TTL 30d) |
| `kv-fabrk-wh-uvqvxk`              | `Microsoft.KeyVault/vaults`                | Secrets (RBAC mode)                   |
| `appi-fabrikam-webhook-uvqvxk`    | `Microsoft.Insights/components`            | App Insights (workspace-based)        |
| `log-fabrikam-webhook-uvqvxk`     | `Microsoft.OperationalInsights/workspaces` | Log Analytics                         |

**Critical gaps found in dev** (see [security.md](security.md) for full detail):

- **F1** Cosmos has `disableLocalAuth: true` but the Function App MI has **no** Cosmos data-plane role -> writes will fail.
- **F2** Archive storage has `allowSharedKeyAccess: false` and **no** role assignments -> the MI cannot write the archive blob.
- **F3** `AzureWebJobsStorage` is a key connection string in app settings - replaced with identity-based access.
- **F4** No diagnostic settings on KV or the Function App.
- **F5** KV soft-delete retention 7 days, purge protection off.
- **F7** Cosmos backup `Periodic` (8h retention) - moved to continuous PITR in prod.

## Deliverables

| Artefact            | Path                                                                                  |
|---------------------|---------------------------------------------------------------------------------------|
| Bicep IaC           | [`iac/main.bicep`](iac/main.bicep) + modules under `iac/modules/`                     |
| Dev parameters      | [`iac/main.parameters.dev.json`](iac/main.parameters.dev.json)                        |
| Prod parameters     | [`iac/main.parameters.prod.json`](iac/main.parameters.prod.json) (placeholders)       |
| Architecture diagram| [`architecture.drawio`](architecture.drawio)                                          |
| Security write-up   | [`security.md`](security.md)                                                          |
| Deployment guide    | [`deployment.md`](deployment.md)                                                      |
| Raw discovery       | `discovery/*.json` (output of `az ... show` for every resource)                       |

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

See [`architecture.drawio`](architecture.drawio) for the editable diagram. Text summary:

```
Retail PSP --HTTPS--> Function App (.NET 8 isolated, Y1, MI)
                          |
                          +--MI--> Storage (runtime)   AzureWebJobsStorage
                          +--MI--> Storage (archive)   payload-archive container
                          +--MI--> Cosmos DB           db webhook / container events
                          +--MI--> Key Vault           secrets (RBAC)
                          +------> App Insights        telemetry
                          +------> Log Analytics       diagnostic logs
```

## Notes

- Source: email from Lerato Mokoena (Senior Engineering Manager, Fabrikam Payments Platform), Fri 2026-05-08 16:47 SAST.
- Read access on the subscription already granted.
- Deadline: end of May 2026.
- Next: deep-dive each resource (`az ... show` in parallel), build Bicep modules, then diagram + security write-up + deployment guide.
