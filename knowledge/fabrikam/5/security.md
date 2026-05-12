# Security write-up - Fabrikam payments webhook handler

**Issue:** [#5](https://github.com/quintindk/todone-aug-2026/issues/5)
**Scope:** dev resources in `rg-fabrikam-dev-webhook` and the prod IaC under `iac/`.
**Date:** 2026-05-12

## Summary

The dev environment was clicked together in the portal over a two-day offsite and has a number of misalignments between intent (managed-identity-first, key-less) and reality (missing role assignments, fail-open defaults, no diagnostics). This document captures the issues found and how the prod Bicep addresses each one.

## Threat surface

| Plane              | Asset                                      | Exposure in dev today                       |
|--------------------|--------------------------------------------|----------------------------------------------|
| Inbound            | `func-fabrikam-webhook-uvqvxk` (HTTPS)     | Public, HTTPS-only, TLS 1.2+, no client cert |
| Control plane      | All resources                              | Public, no PE / no service tag restrictions  |
| Data plane: Cosmos | `cosmos-fabrikam-webhook-uvqvxk`           | Public, local auth disabled, no MI binding   |
| Data plane: KV     | `kv-fabrk-wh-uvqvxk`                       | Public, RBAC mode, MI bound (Secrets User)   |
| Data plane: Blob   | `fabrikamwebhookhackuvqv` (payload archive)| Public, key auth disabled, no MI binding     |
| Identity           | Function App                                | System-assigned MI, single principal         |

## Findings

### F1 - Cosmos data-plane RBAC missing (BREAKING)

`disableLocalAuth: true` on the Cosmos account combined with **zero SQL role assignments** means the Function App's managed identity cannot read or write the `webhook/events` container. The current dev workload either has not been exercised end-to-end or is being kept alive by a portal-issued temporary key the team is unaware of.

**Fix in IaC:** `main.bicep` -> `funcCosmosRole` grants the Function App MI the built-in `Cosmos DB Data Contributor` role at account scope. Human operators in `operatorObjectIds` receive the same.

### F2 - Archive storage RBAC missing (BREAKING)

`fabrikamwebhookhackuvqv` has `allowSharedKeyAccess: false` and **no role assignments**. The `PAYLOAD_ARCHIVE_*` app settings point the Function App at this account, but the MI cannot write to it.

**Fix in IaC:** `funcArchiveRole` grants `Storage Blob Data Contributor` on the archive account.

### F3 - AzureWebJobsStorage uses an inline connection string

The dev Function App carries a `DefaultEndpointsProtocol=...AccountKey=...` style connection string for `AzureWebJobsStorage`. That is a primary key in cleartext in app settings, harvestable by anyone with site Contributor.

**Fix in IaC:** the Function App switches to identity-based `AzureWebJobsStorage__accountName` + `AzureWebJobsStorage__credential=managedidentity`, and the MI receives `Storage Blob Data Owner` on the runtime storage account. No connection strings persisted anywhere.

### F4 - No diagnostic settings on KV or Function App

Neither resource ships logs to Log Analytics. There is no audit trail for KV reads or for Function App auth failures.

**Fix in IaC:** every module wires a diagnostic setting to the workspace (`audit`, `allLogs`, `AllMetrics` as appropriate).

### F5 - KV soft-delete retention 7 days, purge protection off

7-day soft delete is below most regulated baselines and purge protection is off, so a credentialed attacker (or fat-fingered admin) can wipe the vault.

**Fix in IaC:** prod gets `enablePurgeProtection: true` and `softDeleteRetentionInDays: 90`. Dev keeps 7 days to allow tear-down.

### F6 - Public network access on every resource

Cosmos, Storage, KV, App Insights, LAW, and the Function App all accept traffic from any IP. This is fine for a Y1 (Consumption) Function App that needs outbound to data planes, but the data services should be locked down.

**Mitigation (deferred):** the Bicep keeps `publicNetworkAccess: 'Enabled'` to mirror the dev topology. The deployment guide includes a "Hardening checklist" listing the private-endpoint move as a P1 follow-up once Fabrikam confirms whether the prod Function App stays on Consumption (Y1) or moves to Elastic Premium (EP1) / Flex Consumption with VNet integration.

### F7 - Cosmos backup is Periodic with 8h retention

For a payments-adjacent store, 8 hours of restore window is thin and Periodic backups cannot restore to a point in time.

**Fix in IaC:** prod sets `enableContinuousBackup: true` -> `Continuous7Days`. Dev keeps the existing Periodic policy.

### F8 - Log Analytics retention 30 days

Below most retail-payments audit windows (typically 90+ days hot, archive thereafter).

**Fix in IaC:** prod retention bumped to 90 days. Cold archive to a storage account is a follow-up if compliance asks for >2 year retention.

## What is intentionally NOT changed

- Region stays `southafricanorth`. Confirm with Fabrikam if they expect ZRS / paired-region.
- `functionAppScaleLimit: 200`. Same as dev. Revisit during prod load profiling.
- Cosmos consistency stays `Session`. Same as dev. Confirm with the platform team.
- TTL on the `events` container stays 30 days (`2592000` s). Confirm against retail audit retention - if Fabrikam needs the raw event longer, lift this and lean on the blob archive for replay.

## Identity model (target)

```
+-------------------+      Storage Blob Data Owner      +------------------+
|  Function App MI  +----------------------------------> |  st-runtime      |
|  (System-assigned)|                                    +------------------+
|                   |  Storage Blob Data Contributor     +------------------+
|                   +----------------------------------> |  st-archive      |
|                   |                                    +------------------+
|                   |  Cosmos DB Data Contributor        +------------------+
|                   +----------------------------------> |  cosmos          |
|                   |                                    +------------------+
|                   |  Key Vault Secrets User            +------------------+
|                   +----------------------------------> |  kv              |
+-------------------+                                    +------------------+
```

## Compliance checklist

| Control                         | Status after Bicep deployment |
|---------------------------------|--------------------------------|
| TLS 1.2 minimum, HTTPS only     | yes                            |
| Shared-key auth disabled        | yes (both storage accounts)    |
| Local auth disabled on Cosmos   | yes                            |
| Managed identity only           | yes                            |
| KV RBAC mode + purge protection | yes (prod)                     |
| Diagnostic logs to LAW          | yes                            |
| Continuous backup on Cosmos     | yes (prod)                     |
| Private endpoints               | **deferred** - see F6          |
| WAF in front of Function App    | **deferred** - APIM/Front Door follow-up if Fabrikam wants public ingress with auth before the Function |
