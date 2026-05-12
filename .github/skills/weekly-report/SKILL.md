---
name: weekly-report
description: >
  Generate a weekly summary report on Friday afternoons by aggregating daily reports, git history, GitHub project board, calendar, emails, and chats. Produces a markdown report in `reports/` optimised for timesheet completion.
---

# Weekly Report Skill

Build a comprehensive weekly summary by aggregating the week's daily reports, git history, project board changes, meetings, emails, and chats. Designed to run Friday afternoon before timesheets.

## Inputs

| Input    | Required | Default              | Example |
|----------|----------|----------------------|---------|
| **week** | No       | Current ISO week     | `W16`   |
| **year** | No       | Current year         | `2026`  |

If no week is supplied, default to the **current ISO week**. Calculate the Monday-Friday date range.

## Data Sources

### 1 - Daily Reports (Primary Source)

```bash
ls reports/<YYYY>-<MM>-<DD>.md  # for each day in the week range
```

Read **every** daily report for the week. These are the richest source and contain pre-validated, timestamped data. Extract from each:
- **Hour-by-Hour Playback** -> feeds the Daily Breakdown section.
- **Summary by Customer** -> aggregate into weekly Hours by Customer.
- **Commits** -> merge into weekly totals.
- **Issues Touched** -> track all issue activity across the week.
- **Meetings** -> compile full meeting list.
- **Notable Items & Follow-ups** -> Friday's follow-ups become Carry-Forward Items.

If daily reports are missing for some days, fall back to git log + calendar.

### 2 - Git History

```bash
git --no-pager log --all --oneline \
  --since="<monday>T00:00:00" --until="<saturday>T00:00:00" \
  --format="%h %s (%an, %ai)" | head -200
```

Use to fill gaps, count weekly commits, extract issue numbers, and verify daily report accuracy.

### 3 - GitHub Project Board

Read project number and owner from `.github/copilot-instructions.md`.

```bash
# All items and current status
gh project item-list <PROJECT_NUMBER> --owner <PROJECT_OWNER> --format json \
  | jq '[.items[] | {number: .content.number, title: .content.title, status: .status}]'

# Issues closed this week
gh issue list --state closed --json number,title,closedAt \
  --jq '[.[] | select(.closedAt >= "<monday>T00:00:00Z")]'
```

### 4 - Calendar (M365 via WorkIQ, or your calendar MCP)

```
What meetings did I attend from <Monday date> to <Friday date>?
List each meeting with the day, time, title, duration, and attendees.
```

### 5 - Emails (M365 via WorkIQ, or your email MCP)

```
What important work emails did I send and receive from <Monday date> to <Friday date>?
Summarise the key action items and decisions.
```

### 6 - Teams/Slack Chats

```
What significant Teams conversations did I have from <Monday date> to <Friday date>
that involved decisions, commitments, or action items?
```

## Report Structure

### Header

```markdown
# Weekly Summary Report - W<NN> (<DD>-<DD> <Month> <YYYY>)

**Name:** <Your Name> - <Your Role>
**Report Date:** Friday <DD> <Month> <YYYY>

---
```

### Hours by Customer

Aggregate time from all daily reports. Break down by Meetings, Engineering, and Training.

```markdown
## Hours by Customer

| Customer        | Meetings   | Engineering | Training | Total (approx) |
| --------------- | ---------- | ----------- | -------- | -------------- |
| **Fabrikam**    | ~4.5 h     | ~10 h       | -        | **~14.5 h**    |
| **Internal**    | ~1 h       | ~1.5 h      | ~6 h     | **~8.5 h**     |
| **Total**       | **~7.5 h** | **~16.5 h** | **~6 h** | **~30 h**      |
```

**Rules:**
- Include **every** customer that had activity this week.
- Use the customer map from copilot-instructions.md.
- Round to nearest 0.5 h.
- **This table is the timesheet input** - accuracy matters.

**Classification:**
- **Meetings** - calendar events you attended (not just invited).
- **Engineering** - commits, documentation, investigation, coding, architecture work.
- **Training** - learning sessions, courses, certification study.

### Key Deliverables

Numbered table of the week's most significant outputs - things that shipped, were delivered, or materially advanced a workstream.

```markdown
## Key Deliverables

| # | Deliverable | Customer | Issue |
|---|-------------|----------|-------|
| 1 | Webhook reverse-IaC delivered | Fabrikam | #27 ✅ |
| 2 | RBAC blocker resolved | Internal | #1 |
```

**Rules:**
- Only substantive deliverables, not routine admin.
- Mark closed issues with ✅.
- Concise but specific descriptions.

### Issues Closed

```markdown
## Issues Closed

| Issue | Title |
|-------|-------|
| #27 | Fabrikam - Reverse-engineer IaC for payments webhook |
```

Source from `gh issue list --state closed` filtered to this week.

### Daily Breakdown

For each day (Monday-Friday), create a table of activities. Condensed version of the daily reports.

```markdown
## Daily Breakdown

### Monday <DD> <Month>

| Time | Activity | Customer | Details |
|------|----------|----------|---------|
| 06:20-08:30 | Engineering | Fabrikam (#12) | Drafted reverse-IaC, committed |
| 09:00-10:00 | Meeting | Internal | Team standup |
```

**Activity types:** `Meeting`, `Engineering`, `Training`, `Admin`.

**Rules:**
- Merge adjacent blocks of the same activity type.
- Include issue references where applicable.
- Keep Details column concise - one line per row.
- If a daily report exists, extract from its hour-by-hour playback.
- If no daily report exists, reconstruct from git log + calendar.
- For public holidays or leave: `> Light day - public holiday.`

### Training Attended

Only include if there were training sessions.

```markdown
## Training Attended

| Session | Level |
|---------|-------|
| Architecture Design with Agent Factory | L200 |
```

### Carry-Forward Items

**The most important section for Monday planning.**

```markdown
## Carry-Forward Items

| Item | Customer | Priority | Notes |
|------|----------|----------|-------|
| Respond to compliance follow-up | Fabrikam (#12) | 🔴 P0 | Email Mon morning |
| Schedule production review | Fabrikam | 🟠 P1 | Follow-up from #27 |
| Cert exam | Internal (#29) | 🟡 P2 | Mon next week 07:45 |
```

**Sources for carry-forward items:**
- Friday's daily report Notable Items & Follow-ups.
- Outstanding email actions from the week.
- Slipped deadlines from the weekly plan.
- Board items still in progress or waiting.
- New commitments made during meetings.

**Priority indicators:**
- 🔴 P0 - Overdue or due Monday/Tuesday next week.
- 🟠 P1 - Due next week, medium priority.
- 🟡 P2 - Lower priority or flexible deadline.

## Execution Steps

### Step 1 - Determine the week

Calculate the ISO week number, Monday-Friday date range, and report date (Friday).

### Step 2 - Collect data in parallel

Run **all** data-collection queries simultaneously:
- Daily reports for Mon-Fri (view x 5)
- Git log for the week (bash)
- GitHub project board + closed issues (bash x 2)
- Weekly plan (view)
- Calendar for the week (WorkIQ)
- Emails summary (WorkIQ)
- Teams/Slack chats (WorkIQ)

### Step 3 - Aggregate and reconcile

1. **Daily report aggregation** - Merge all daily reports into a unified weekly view. Sum hours by customer.
2. **Gap filling** - For days without daily reports, reconstruct from git log + calendar.
3. **Deliverable extraction** - Identify the week's top deliverables from commits, issue closures, and meeting outcomes.
4. **Carry-forward synthesis** - Combine Friday's follow-ups, outstanding emails, slipped plan items, active board items.
5. **Plan vs actual** - Compare the weekly plan's deadlines against what was achieved. Note slippage.

### Step 4 - Write the report

Create the report following the structure above.

**Important:**
- Hours accuracy is critical - this feeds timesheets.
- Cross-reference daily reports against git log to catch missing activity.
- The Carry-Forward section directly feeds next Monday's weekly planning skill.

### Step 5 - Commit

```bash
git add reports/<YYYY>-W<NN>.md
git commit -m "chore: add W<NN> weekly summary report

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

Do **not** push - leave that to the user.

## Output

```
Weekly report created
   File:     reports/<YYYY>-W<NN>.md
   Commit:   <short-sha>
   Week:     <Monday> - <Friday>
   Sources:  daily reports (N/5), git (N commits), board (N items, N closed), calendar (N meetings), emails (✓/✗), chats (✓/✗)

Timesheet summary:
- <Customer 1>: ~N h (N meetings, N engineering, N training)
- <Customer 2>: ~N h
- Total: ~N h
```

The timesheet summary is printed to the terminal for quick copy-paste into the timesheet tool.

## Conventions

- **Dates:** ISO 8601 in filenames; human-readable in content.
- **Week format:** `W<NN>` (ISO week number, zero-padded).
- **File naming:** `<YYYY>-W<NN>.md` - e.g. `2026-W16.md`.
- **Commits:** Conventional Commits - `chore: add W<NN> weekly summary report`.
