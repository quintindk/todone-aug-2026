---
name: issue-scaffolding
description: >
  Scaffold the standard ToDone issue folder structure, GitHub issue, and project-board linkage for a new work item.
---

# Issue Scaffolding Skill

Create the full ToDone issue structure: GitHub issue -> folder -> templated README -> project-board linkage -> commit. Follow every step in order; do not skip any.

## Inputs

Collect these before starting. All are required unless marked optional.

| Input              | Required | Example                                                |
|--------------------|----------|--------------------------------------------------------|
| **Customer name**  | Yes      | Fabrikam                                               |
| **Issue title**    | Yes      | Reverse-engineer IaC for payments webhook handler      |
| **Work type**      | Yes      | One of: `Investigation`, `Architecture Review`, `Support Case`, `Meeting Prep`, `Deployment`, `Documentation` |
| **Priority**       | Yes      | `P0`, `P1`, or `P2`                                    |
| **Reference**      | Optional | Ticket / case ref (ICM, ServiceNow, Jira)              |

## Customer Slug Map

Map the customer name to its folder slug from the table in `.github/copilot-instructions.md`. If the customer is not in the table, ask the user to add it first before continuing.

## Execution Steps

### 1. Create the GitHub Issue

```bash
gh issue create \
  --title "<title>" \
  --label "<work-type>" \
  --body "Customer: <customer name>
Priority: <priority>
Reference: <ref or N/A>"
```

Extract the issue number from the URL returned by `gh issue create`. The URL format is `https://github.com/<owner>/<repo>/issues/<number>`. Parse `<number>` from it.

### 2. Create the Issue Folder

```bash
mkdir -p knowledge/<slug>/<number>/
```

If `knowledge/<slug>/` does not yet exist, create it.

### 3. Copy and Populate the README Template

Copy `templates/issue-readme.md` to `knowledge/<slug>/<number>/README.md`.

Then replace every placeholder in the new file with real values:

| Placeholder                                  | Replace with                            |
|----------------------------------------------|-----------------------------------------|
| `<Title>`                                    | The issue title                         |
| `<number>`                                   | The issue number (digits only)          |
| `<owner>`                                    | The github owner from copilot-instructions.md |
| `<repo>`                                     | The repo name                           |
| `<customer name>`                            | Full customer name                      |
| `<ticket/case number if applicable>`         | Reference, or `N/A`                     |
| `Open \| In Progress \| In Review \| Done`   | `Open` (always starts as Open)          |

Leave the sections **Overview**, **Key Findings**, **Scope**, **Architecture / Design**, and **Notes** with their placeholder text intact - the user will fill those in.

### 4. Add the Issue to the Project Board

Read the project IDs from `.github/copilot-instructions.md` (the `<PROJECT_NUMBER>`, `<PROJECT_OWNER>`, `<PROJECT_ID>`, `<STATUS_FIELD_ID>` and option IDs).

```bash
gh project item-add <PROJECT_NUMBER> --owner <PROJECT_OWNER> --url <issue-url>
```

Where `<issue-url>` is the full URL returned from step 1.

### 5. Set Project Item Fields

Get the item ID from the output of step 4, then set the status to **Ready**:

```bash
gh project item-edit \
  --project-id <PROJECT_ID> \
  --id <item-id> \
  --field-id <STATUS_FIELD_ID> \
  --single-select-option-id <READY_OPTION_ID>
```

### 6. Git Add and Commit

Use Conventional Commits format:

```bash
git add knowledge/<slug>/<number>/
git commit -m "docs(#<number>): scaffold issue folder for <title>"
```

Append the Copilot co-author trailer:

```
Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>
```

Do **not** push - leave that to the user.

## Conventions

- **Dates:** ISO 8601 (`YYYY-MM-DD`).
- **Commits:** Conventional Commits - `docs(#<number>): <description>`.

## Output

After completing all steps, report:

1. **Issue URL** - the full GitHub issue link.
2. **Folder path** - `knowledge/<slug>/<number>/`.
3. **Commit SHA** - the short SHA of the scaffold commit.

Example:

```
Issue scaffolded
   Issue:  https://github.com/<owner>/<repo>/issues/42
   Folder: knowledge/fabrikam/42/
   Commit: a1b2c3d
```
