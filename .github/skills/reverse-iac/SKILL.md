---
name: reverse-iac
description: >
  Reverse-engineer a deployed Azure resource group into Bicep IaC plus an architecture diagram,
  security write-up, and deployment guide. Use when a customer needs to lift a portal-built
  workload into source-controlled, prod-ready infrastructure.
---

# Reverse-IaC + Architecture Review Skill

Take a live Azure resource group and produce a complete prod-ready deliverable pack: Bicep modules, draw.io architecture diagram, security write-up (findings + remediations), and a deployment guide. Optimised for the typical "the team clicked it together in dev and now compliance wants it in prod" scenario.

Assumes the issue folder already exists (run the `issue-scaffolding` skill first if not). All deliverables land under `knowledge/<slug>/<issue>/`.

## Inputs

| Input                    | Required | Example                                                |
|--------------------------|----------|--------------------------------------------------------|
| **Issue number**         | Yes      | `5`                                                    |
| **Customer slug**        | Yes      | `fabrikam`                                             |
| **Resource group**       | Yes      | `rg-fabrikam-dev-webhook`                              |
| **Subscription**         | Yes      | `quintindekok-demo`                                    |
| **Target envs**          | Yes      | `dev,prod` (Bicep gets parameterised for each)         |
| **Operator group**       | Optional | AAD group object ID(s) for KV / Cosmos data-plane RBAC |
| **Compliance ask**       | Optional | Free text - e.g. "PCI-adjacent, 90d audit retention"   |

If the resource group has anything stateful in it (DB, storage), confirm with the user that read access is sufficient before running `az ... show` against everything.

## Output Layout

```
knowledge/<slug>/<issue>/
  README.md                    <- updated with findings + deliverable index
  architecture.drawio          <- target topology
  security.md                  <- findings + remediations
  deployment.md                <- what-if / deploy / smoke / rollback
  discovery/                   <- raw `az ... show` JSON for every resource
    func.json, plan.json, cosmos.json, kv.json, st-*.json, appi.json, log.json, ...
  iac/
    main.bicep
    main.parameters.<env>.json
    modules/
      monitoring.bicep
      keyvault.bicep
      storage.bicep
      cosmos.bicep
      functionapp.bicep      (or other compute - aks.bicep, appservice.bicep, ...)
      *-role-assignment.bicep
```

## Execution Steps

### 1. Inventory the resource group

```bash
az account set --subscription "<sub>"
az resource list -g "<rg>" -o json | jq -r '.[] | "\(.name) | \(.type)"'
```

Group the resources by role:

- **Compute** (Function App / App Service / AKS / Container App)
- **Data** (Cosmos / SQL / Storage / Service Bus)
- **Identity / secrets** (Key Vault, Managed Identities)
- **Networking** (VNet, NSG, Private Endpoints, Front Door, APIM)
- **Observability** (App Insights, Log Analytics)
- **Auxiliary** (Action Groups, Workbooks, alerts)

### 2. Parallel deep-dive

Create `knowledge/<slug>/<issue>/discovery/` and run `az ... show` for every resource in parallel. Always capture JSON, never table output. Suggested commands (extend as needed):

```bash
az functionapp show ...                  > func.json &
az functionapp config show ...           > func-config.json &
az functionapp config appsettings list   > func-appsettings.json &
az functionapp identity show ...         > func-identity.json &
az appservice plan show ...              > plan.json &
az cosmosdb show ...                     > cosmos.json &
az cosmosdb sql database list ...        > cosmos-dbs.json &
az cosmosdb sql container list ...       > cosmos-containers.json &
az cosmosdb sql role assignment list ... > cosmos-roles.json &
az keyvault show ...                     > kv.json &
az storage account show ...              > st-<role>.json &
az monitor app-insights component show   > appi.json &
az monitor log-analytics workspace show  > log.json &
az network ...                           > net.json &       # if any networking
wait
```

For each managed identity, also capture role assignments across the RG:

```bash
az role assignment list --assignee <principalId> --all -o json > <name>-mi-roles.json
```

Use the discovery JSONs as the source of truth for the Bicep. **Do not infer** properties you have not seen in the live output.

### 3. Hunt for gaps (the high-signal output)

Read the discovery JSONs with `jq` and look specifically for:

| Gap                                                                 | How to check                                                                    |
|---------------------------------------------------------------------|---------------------------------------------------------------------------------|
| Data plane "local auth off" but no RBAC assigned                    | `disableLocalAuth: true` on Cosmos with empty `sqlRoleAssignments`              |
| Storage `allowSharedKeyAccess: false` but no MI role                | `az role assignment list --scope <storage-account-id>`                          |
| `AzureWebJobsStorage` set as a connection string instead of identity| Look for `DefaultEndpointsProtocol=...AccountKey=...` in app settings           |
| KV with `enablePurgeProtection: null` and short soft-delete         | `kv.json` properties                                                            |
| No diagnostic settings on KV / Function App / Storage / Cosmos      | `az monitor diagnostic-settings list --resource <id>`                           |
| Cosmos `Periodic` backup on stateful workloads                      | `backupPolicy.type`                                                             |
| TLS < 1.2, HTTP/2 off, FTPS enabled, public network access wide-open| `siteConfig` / `publicNetworkAccess` / `networkAcls`                            |
| KV access policies + RBAC mixed                                     | `enableRbacAuthorization` + non-empty `accessPolicies`                          |
| Public-access-enabled storage containers                            | `az storage container list --auth-mode login --query "[].properties.publicAccess"` |

Every gap becomes a numbered finding in `security.md` (F1, F2, ...) with: what was found, why it matters, and the IaC remediation.

### 4. Author the Bicep

Use the layout in **Output Layout** above. Conventions:

- `targetScope = 'resourceGroup'`.
- Parameters: `env` (`@allowed(['dev','test','prod'])`), `location` (default `resourceGroup().location`), `nameSuffix` (5-8 lowercase alphanumeric), `operatorObjectIds array`, `tags object`.
- Naming: `<type>-<workload>-<env>-<nameSuffix>`. Storage accounts: compress to `<short><role><env><suffix>` to fit 24 chars / no hyphens.
- Modules return outputs (`id`, `name`, key endpoints, `principalId` for compute). `main.bicep` composes only.
- Wire **all** required data-plane role assignments in `main.bicep` from compute MI to data services. This is the most common dev-vs-prod gap.
- Replace `AzureWebJobsStorage` connection-string with identity-based (`__accountName` + `__credential=managedidentity`); grant `Storage Blob Data Owner`.
- Diagnostic settings on every resource that supports them, pointed at the workspace.
- Differentiate envs by **conditional values**, not by separate templates: `env == 'prod' ? 90 : 30`, etc.
- Lint with `az bicep build --file main.bicep`. Fix every warning before committing.
- Delete the generated `main.json` after lint - it is a build artefact.

### 5. Architecture diagram

Create `architecture.drawio` showing the **target** topology (post-Bicep), not the dev mess. Required elements:

- All resources in the RG.
- MI arrows labelled with the role granted (e.g. "MI: Cosmos Data Contributor").
- Inbound caller(s) on the left, data planes on the right, observability at the bottom.
- Resource group as a dashed rectangle.

If the user has Azure stencils they prefer, ask; otherwise use coloured rectangles + cylinders.

### 6. Write `security.md`

Required sections:

- **Summary** (one paragraph: what the workload is, why we're reviewing it).
- **Threat surface table** (one row per plane: inbound / control / data per service / identity).
- **Findings** F1..Fn - what, why it matters, IaC remediation. One finding per gap from step 3.
- **What is intentionally NOT changed** - region, scale limits, consistency level, TTL, etc. Surface assumptions for the customer to confirm.
- **Identity model** - ASCII or table mapping MI -> role -> resource.
- **Compliance checklist** - control vs status after deployment, including deferred items (private endpoints, WAF).

### 7. Write `deployment.md`

Required sections:

- **Prerequisites** (CLI versions, required roles - usually `Contributor` + `User Access Administrator` because of role assignments).
- **Parameters** (how to fill `main.parameters.prod.json`; how to look up operator object IDs).
- **Step 1** create RG.
- **Step 2** `az deployment group what-if` - tell the user what to look for in the diff.
- **Step 3** `az deployment group create` with a timestamped name.
- **Step 4** application code deploy (out of scope but linked).
- **Step 5** smoke test with concrete `curl` / `az cosmosdb sql query` / `az storage blob list` / `az monitor app-insights query` commands.
- **Step 6** operational handover.
- **Rollback** notes (incl. KV purge-protection caveat if enabled).
- **Hardening checklist** of P1 follow-ups (private endpoints, WAF / APIM, alerts, Defender for Cloud plans, tag policy, budgets).

### 8. Update the issue README

Replace the placeholder sections with:

- **Key Findings** - inventory table + bulleted summary of F1..Fn (link to `security.md`).
- **Deliverables** - file table pointing to each artefact.
- **Architecture / Design** - ASCII summary + link to `architecture.drawio`.

### 9. Lint, convert, commit

```bash
cd knowledge/<slug>/<issue>/iac && az bicep build --file main.bicep    # must be warning-free
rm -f main.json

cd ..
pandoc README.md     -o README.docx     --resource-path=.
pandoc security.md   -o security.docx   --resource-path=.
pandoc deployment.md -o deployment.docx --resource-path=.
```

`.docx` files are gitignored (`knowledge/**/*.docx`). They stay local for customer share.

Commit:

```bash
git add knowledge/<slug>/<issue>/
git commit -m "feat(#<issue>): reverse-engineer <workload> - Bicep, diagram, security & deployment docs

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

### 10. Close the loop on the project board

Move the issue to **In Progress** during the work, **Done** on hand-off. See `.github/copilot-instructions.md` for the option IDs.

## Conventions

- **Discovery first, Bicep second.** Never write Bicep from memory of how a service usually looks - drive every property from the JSON in `discovery/`.
- **Surface assumptions explicitly.** Anything you parameterised because the dev value looked wrong (e.g. consistency level, TTL, scale limit) goes in the "What is intentionally NOT changed" section so the customer can correct you.
- **High-signal findings only.** Don't pad `security.md` with generic Azure platform notes; only items that are genuinely wrong or missing in *this* deployment.
- **Mirror, then improve.** The Bicep should reproduce the dev topology when `env=dev` (with the breaking gaps fixed), and tighten naturally for `env=prod` via conditionals.
- **Don't push.** Leave the final `git push` to the user.

## Output

After completing all steps, report:

1. **Issue URL** with new status (`Done`).
2. **Deliverable paths** - `iac/`, `architecture.drawio`, `security.md`, `deployment.md`.
3. **Word exports** - paths to the three `.docx` files.
4. **Top 3 findings** - one-line summaries of the most critical gaps found in dev.
5. **Commit SHA(s)** - the short SHA(s) of the deliverable commit(s).
