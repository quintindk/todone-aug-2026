# Copilot Instructions — ToDone

## About This Repo

ToDone is a personal knowledge base, documentation hub, and task-tracking template for using **GitHub Copilot CLI as a personal assistant and second brain**. It captures hands-on work, investigation notes, meeting prep, and runbooks — all tied to GitHub Issues as the source of truth for active work items.

This instance was bootstrapped on 2026-05-12 for the **AUG Cape Town talk** ("ToDone: GitHub Copilot CLI as your second brain"). The synthetic prior week is Fabrikam payments-webhook work running Mon 4 May → Fri 8 May 2026.

## About the Author

**Quintin De Kok** — Senior Cloud Solutions Architect at Microsoft South Africa. Strong bias toward hands-on delivery and real-world troubleshooting on Azure (networking, identity, hybrid, AKS, IaC); expect engineer-level commands, KQL, Bicep and PowerShell rather than slide-ware.

## Customer & Context Map

Work items are organised by customer (or context — internal projects, learning, side work). Use the **lowercase slug** as the folder name under `knowledge/`.

| Customer / Context | Folder Slug | Notes |
|--------------------|-------------|-------|
| Fabrikam           | `fabrikam`  | Payments retail webhook handler — built in dev via the portal, needs reverse-IaC for compliance. RG: `rg-fabrikam-dev-webhook`. |
| Internal           | `internal`  | Self-directed work, learning, admin |

> **Tip:** When a new customer or context appears, add a row here and create the slug folder under `knowledge/`.

## Repo Structure

```
knowledge/
  <slug>/                  ← lowercase customer/context slug (see table above)
    <issue-number>/        ← maps 1-to-1 to a GitHub Issue
      README.md            ← overview / living summary of the issue
      *.md                 ← supporting docs (research, meeting prep, runbooks, etc.)
      *.drawio             ← editable architecture diagrams (draw.io)
code/                      ← scratch utilities, generated IaC, throwaway scripts
templates/                 ← reusable document templates
reports/                   ← generated daily and weekly reports
planning/                  ← generated weekly plans
docs/                      ← documentation about this repo itself
.github/
  ISSUE_TEMPLATE/          ← GitHub issue forms
  skills/                  ← reusable Copilot skills
  copilot-instructions.md  ← this file
```

- **GitHub Issues are the backlog.** Every `knowledge/` folder maps to an issue number.
- Folder names under `knowledge/` are lowercase slugs from the table above.
- Each issue folder contains a `README.md` as the canonical summary, plus any related artefacts.

## Writing & Style Guidelines

- **Be direct and technical.** Write for an experienced practitioner audience. Avoid filler and marketing language.
- **Use plain Markdown.** No custom components or proprietary extensions.
- **Tables over prose** for timelines, comparisons, and structured data.
- **Code blocks with language tags** for CLI commands, config snippets, YAML, JSON, Bicep, etc.
- **Include links** to relevant docs, GitHub issues, and tickets.
- **Date format:** ISO 8601 (`YYYY-MM-DD`) in content and filenames.
- **Do not use en-dashes (–) or em-dashes (—).** Use hyphens (`-`), commas, parentheses, or colons. Long dashes mangle in copy/paste and terminals, and are a tell-tale sign of AI-generated text.

## Document Templates

Reusable templates live in `templates/`. Copy the relevant template when starting a new issue folder.

| Template      | File                         | Use case                                                       |
|---------------|------------------------------|----------------------------------------------------------------|
| Issue README  | `templates/issue-readme.md`  | Default starting point for any issue folder                    |

## Skills

Reusable Copilot skills live in `.github/skills/`. Each skill has step-by-step instructions for a specific task.

### Tier 1 — Leaf Skills

| Skill                | Directory                          | Purpose                                                                              |
|----------------------|------------------------------------|--------------------------------------------------------------------------------------|
| `issue-scaffolding`  | `.github/skills/issue-scaffolding/`| Create GitHub issue + `knowledge/<slug>/<issue>/` folder from template + board entry |
| `reverse-iac`        | `.github/skills/reverse-iac/`      | Reverse-engineer a live Azure RG into Bicep IaC + diagram + security + deployment    |
| `daily-report`       | `.github/skills/daily-report/`     | Generate daily summary from git, sessions, calendar, emails, chats                   |
| `weekly-planning`    | `.github/skills/weekly-planning/`  | Monday-morning plan from previous reports, board, calendar, emails                   |
| `weekly-report`      | `.github/skills/weekly-report/`    | Friday-afternoon rollup from daily reports, git, board — timesheet-ready             |

> Skills are invoked by name from Copilot CLI (e.g. `> Use the daily-report skill for yesterday`).

## How Copilot Should Help

1. **Drafting documentation** — generate issue READMEs, meeting prep docs, summaries following the templates and style above.
2. **Investigation support** — analyse logs, queries, configs. Provide actionable next steps, not generic advice.
3. **Code & automation** — produce CLI commands, IaC templates, scripts that are production-ready and idempotent where possible.
4. **Organising work** — triage, summarise, and link findings back to the relevant GitHub Issue.
5. **Meeting prep** — draft agendas, talking points, and question lists from the current state of an investigation.

## GitHub Project & Kanban Workflow

All issues live in a GitHub Project board:

- **Project number:** `6`
- **Project owner:** `quintindk`
- **Project ID:** `PVT_kwHOAYi-Fs4BXVwZ`
- **Status field ID:** `PVTSSF_lAHOAYi-Fs4BXVwZzhSjOvk`

> Re-derive these if needed: `gh project list --owner quintindk`, then `gh project field-list 6 --owner quintindk --format json`.

### Kanban Columns (Status field)

| Status      | Option ID    | When to use                                  |
|-------------|--------------|----------------------------------------------|
| Todo        | `f75ad846`   | New / untriaged items                        |
| In Progress | `47fc9ee4`   | Actively being worked on                     |
| Done        | `98236657`   | Completed and closed                         |

### Common `gh` Commands

```bash
# Find an item's project-item ID by issue number
gh project item-list 6 --owner quintindk --format json \
  | jq '.items[] | select(.content.number == <ISSUE_NUM>)'

# Move an issue to a Kanban column (e.g. In Progress)
gh project item-edit \
  --project-id PVT_kwHOAYi-Fs4BXVwZ \
  --id <ITEM_ID> \
  --field-id PVTSSF_lAHOAYi-Fs4BXVwZzhSjOvk \
  --single-select-option-id 47fc9ee4
```

### Sub-Issues

Use sub-issues for blocking dependencies (tickets, access requests, third-party items). Link with `gh issue edit <child> --add-parent <parent>`.

## Tooling Preferences

- **Use the GitHub MCP server** for GitHub operations (issues, PRs, repos, actions) where available. Fall back to the `gh` CLI when MCP doesn't cover an operation.
- **Use `pandoc`** for markdown -> Word conversion when delivering to customers:
  ```bash
  pandoc knowledge/<slug>/<n>/README.md -o knowledge/<slug>/<n>/README.docx
  ```
- **Use draw.io** for architecture diagrams. Save `.drawio` files directly and open them in VS Code with the `hediet.vscode-drawio` extension. Use Azure icons and stencils where relevant.

## Issue Naming Convention

Issue titles follow the pattern: `<Customer> - <Description>`. Use the customer display name from the context map (not the folder slug).

**Examples:**
- `Fabrikam - Reverse-engineer IaC for payments webhook handler`
- `Internal - Submit Q1 expense report`

For sub-issues, keep the same prefix and add context: `Fabrikam - Reverse IaC: Threat model review for webhook handler`.

## Commit Conventions

- Commit messages reference the issue number: `docs(#15): add architecture diagram`.
- Use [Conventional Commits](https://www.conventionalcommits.org/) prefixes: `docs:`, `fix:`, `feat:`, `chore:`.
- Append the Copilot co-author trailer:
  ```
  Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>
  ```

## Communication Style

- **Match the user's energy** — direct, casual, professional but not corporate.
- **Be proactive** — suggest next steps, flag related issues, offer to batch work.
- **Don't ask for permission on obvious actions** — if a commit, push, or status update is clearly implied, just do it and report back.
