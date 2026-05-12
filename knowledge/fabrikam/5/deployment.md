# Deployment guide - Fabrikam payments webhook handler

**Issue:** [#5](https://github.com/quintindk/todone-aug-2026/issues/5)
**IaC:** `iac/main.bicep`
**Region:** `southafricanorth`

## Prerequisites

- Azure CLI 2.60+ (`az --version`).
- Bicep CLI bundled with `az` (`az bicep version`; auto-installed on first build).
- Subscription roles required to deploy:
  - `Contributor` on the target resource group (or subscription, if creating the RG).
  - `User Access Administrator` on the target RG (role assignments are part of the template).
  - Alternative: split into a separate `Owner`-scoped run for the role-assignment modules.
- The Function App code is deployed separately (Functions Core Tools, GitHub Actions, or Azure DevOps). This template provisions infrastructure only.

## Parameters

The template parameters file lives at `iac/main.parameters.<env>.json`. For prod, fill in:

| Parameter             | Value                                                        |
|-----------------------|--------------------------------------------------------------|
| `env`                 | `prod`                                                       |
| `nameSuffix`          | 5-8 lowercase alphanumeric chars, unique to this deployment  |
| `operatorObjectIds`   | AAD object IDs (users or groups) that get KV Secrets Officer + Cosmos Data Contributor at the account scope |

Get an operator group object ID with:

```bash
az ad group show --group "Fabrikam Payments Platform Operators" --query id -o tsv
```

## Step 1 - create the resource group

```bash
SUB="quintindekok-demo"        # or the prod sub once known
RG="rg-fabrikam-prod-webhook"
LOC="southafricanorth"

az account set --subscription "$SUB"
az group create -n "$RG" -l "$LOC"
```

## Step 2 - validate the template (what-if)

```bash
cd knowledge/fabrikam/5/iac

az deployment group what-if \
  -g "$RG" \
  -f main.bicep \
  -p main.parameters.prod.json
```

Review the diff. Confirm 8 resources are being created (Function App, Plan, Cosmos, KV, App Insights, LAW, 2x Storage) plus 4 role assignments.

## Step 3 - deploy

```bash
az deployment group create \
  -g "$RG" \
  -f main.bicep \
  -p main.parameters.prod.json \
  -n "fabrikam-webhook-$(date +%Y%m%d-%H%M)"
```

Capture the outputs:

```bash
az deployment group show -g "$RG" -n "<deployment-name>" --query properties.outputs -o json
```

Expected outputs:

- `functionAppName`
- `functionAppHostname`
- `cosmosEndpoint`
- `keyVaultName`
- `appInsightsConnectionString`

## Step 4 - deploy the Function App code

The application code is owned by the Fabrikam payments team. Once they hand it over:

```bash
func azure functionapp publish <functionAppName> --dotnet-isolated
```

or wire the build artifact in their existing pipeline using `<functionAppName>` from Step 3.

## Step 5 - smoke test

```bash
HOST=$(az functionapp show -g "$RG" -n "$FUNC_NAME" --query defaultHostName -o tsv)

# Replace <function-name> and adapt the body to a real webhook payload.
curl -i -X POST "https://${HOST}/api/<function-name>" \
  -H "Content-Type: application/json" \
  -d '{"merchantId":"smoke-test","eventId":"00000000","occurredAt":"2026-05-12T10:00:00Z"}'
```

Verify in parallel:

```bash
# Cosmos: the event landed
az cosmosdb sql query \
  -g "$RG" -a "$COSMOS_NAME" \
  -d webhook -c events \
  --query-text "SELECT TOP 5 c.eventId, c.merchantId, c._ts FROM c ORDER BY c._ts DESC"

# Archive blob: the payload was written
az storage blob list \
  --account-name "$ST_ARCHIVE" \
  --container-name payload-archive \
  --auth-mode login \
  --query "[].{name:name, size:properties.contentLength}" -o table

# App Insights: requests + dependencies in the last 15 min
az monitor app-insights query \
  --app "$APPI_NAME" -g "$RG" \
  --analytics-query "requests | where timestamp > ago(15m) | summarize count() by resultCode"
```

## Step 6 - operational handover

1. Add the deployment artifact (parameters file + outputs) to the Fabrikam team's runbook repo.
2. Schedule a 30-min walkthrough with Sipho's team covering: how the MI auth chain works (no keys), how to rotate the `operatorObjectIds`, and where logs live.
3. Add the prod resources to the Fabrikam Azure Monitor action group for alerting.

## Rollback

The deployment is idempotent. To roll forward, edit the parameters or template and re-run Step 3. To remove the environment entirely:

```bash
az group delete -n "$RG" --yes --no-wait
```

> Key Vault has `enablePurgeProtection: true` in prod. Once enabled it cannot be turned off. The vault will be soft-deleted on RG deletion and will block re-using the same `kv-fabrk-wh-prod-<suffix>` name for the retention window (90 days). Plan accordingly.

## Hardening checklist (post-deployment, P1)

- [ ] Decide on the prod hosting tier: stay on Y1 Consumption or move to Flex / EP for VNet integration.
- [ ] If VNet: add private endpoints for Cosmos, KV, and both storage accounts; restrict `publicNetworkAccess` to `Disabled` and bind via PE.
- [ ] Front the Function App with APIM or Azure Front Door + WAF for inbound HMAC validation, rate limiting, and IP allowlisting.
- [ ] Add Azure Monitor alerts: Function App 5xx rate, Cosmos 429 rate, Blob write failures, KV `Forbidden` events.
- [ ] Wire Defender for Cloud (Storage + Cosmos + Key Vault plans) at subscription scope.
- [ ] Tag-policy + budget on the RG.
