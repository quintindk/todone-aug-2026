# ToDone

> A template repo for using **GitHub Copilot CLI as a personal assistant and second brain** — not just a coding assistant.

ToDone enforces a process, not a product. Clone it, point Copilot at it, and your week becomes legible: every meeting, investigation, decision, and commit gets captured against an issue, rolled up into daily and weekly reports, and tracked on a Kanban board.

## What's in here

```
.github/
  copilot-instructions.md     ← teaches Copilot how to behave in this repo
  ISSUE_TEMPLATE/             ← structured work-item form
  skills/                     ← reusable Copilot skills
    issue-scaffolding/        ← create issue + folder + board entry in one prompt
    daily-report/             ← end-of-day rollup from git, sessions, calendar, email
    weekly-report/            ← Friday-afternoon rollup, timesheet-ready
    weekly-planning/          ← Monday-morning plan from last week + board + calendar
knowledge/                    ← work-item documentation (one folder per issue)
code/                         ← scratch / utilities / generated IaC
templates/                    ← document templates (issue README, etc.)
reports/                      ← generated daily and weekly reports
planning/                     ← generated weekly plans
```

## Getting started

> Status: bootstrap. Full quickstart guide pending — see `docs/getting-started.md` once it exists.

1. **Use this template** — click "Use this template" on github to create your own copy.
2. **Edit `.github/copilot-instructions.md`** — fill in your name, role, and the customer/context map.
3. **Create a GitHub Project** (board) for your repo and capture the IDs into `.github/copilot-instructions.md` (see the placeholders marked `<PROJECT_ID>`, `<STATUS_FIELD_ID>`, etc.).
4. **Open the repo with Copilot CLI** — it reads `.github/copilot-instructions.md` and the skills automatically.
5. **Try a skill:** `> Use the issue-scaffolding skill to create an issue for "Investigate X for Customer Y"`.

## Philosophy

- **Issues are the backlog.** Every piece of substantive work is a GitHub Issue. Every issue gets a folder under `knowledge/`.
- **The board is the narrator.** Status transitions (Todo → In Progress → Done) make your work visible in real time.
- **Capture beats memory.** Daily and weekly reports turn invisible work into evidence — for timesheets, for status reports, for your future self.
- **Skills compound.** Anything you do twice gets a skill. Anything that needs structure gets a template.

## Built for the talk

This repo is the open-source companion to the Azure User Group talk *"Copilot isn't a coding assistant — it's a personal assistant."* (12 May 2026). Slide deck and recording links will be added after delivery.

## Licence

MIT — see [LICENSE](LICENSE).
