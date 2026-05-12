---
name: weekly-planning
description: >
  Generate a weekly plan every Monday morning by reviewing the previous week's report, daily reports, current plan, GitHub project board, calendar, emails, and chats. Produces a markdown planner in `planning/`.
---

# Weekly Planning Skill

Build a comprehensive week plan by reviewing what happened last week, what's on the board, and what's coming up - then write and commit it to `planning/`.

## Inputs

| Input    | Required | Default            | Example |
|----------|----------|--------------------|---------|
| **week** | No       | Current ISO week   | `W17`   |
| **year** | No       | Current year       | `2026`  |

If no week is supplied, default to the **current ISO week** based on today's date. Calculate the Monday-Friday date range for that week.

## Data Sources

### 1 - Previous Week's Summary Report

```bash
ls -t reports/????-W??.md | head -1
```

Read and extract:
- **Carry-Forward Items** - high-priority inputs for the new week.
- **Hours by Customer** - context for capacity planning.
- **Issues Closed** - to know what's done.
- **Key Deliverables** - to track momentum.
- **Training Attended** - to avoid double-booking.

### 2 - Previous Week's Daily Reports

```bash
ls reports/????-??-??.md | sort -r | head -7
```

Read recent daily reports (especially Friday's) and extract:
- **Notable Items & Follow-ups** - unactioned items carry forward.
- **Issues Touched** - ongoing work threads.
- Meeting outcomes and decisions affecting this week.

### 3 - Current/Previous Week's Plan

```bash
ls -t planning/????-W??.md | head -1
```

Read and extract:
- **Deadlines & Commitments** - check which are overdue vs completed.
- **In Progress (Board)** - current state of active issues.
- **Study Plan** or other recurring blocks - carry forward if still relevant.

### 4 - GitHub Project Board

Read project number and owner from `.github/copilot-instructions.md`.

```bash
gh project item-list <PROJECT_NUMBER> --owner <PROJECT_OWNER> --format json \
  | jq '[.items[] | select(.status != "Done") | {number: .content.number, title: .content.title, status: .status, labels: .labels}]'
```

Group items by status:
- **In Progress** - actively worked on; need next-steps.
- **Ready** - scoped and available to pick up.
- **Todo** - backlog items that might be promoted.
- **Waiting** - blocked items; check if blockers are resolved.

Also check for recently closed issues:

```bash
gh issue list --state closed --json number,title,closedAt \
  --jq '[.[] | select(.closedAt > "<previous-week-monday>")]'
```

### 5 - Calendar (M365 via WorkIQ, or your calendar MCP)

```
What meetings do I have on my calendar for the week of <Monday date> to <Friday date>?
List each meeting with the day, time, title, and attendees.
```

Identify:
- Recurring standups and syncs.
- Key customer meetings that need prep.
- Training / learning sessions.
- Free blocks available for deep work.

### 6 - Emails (M365 via WorkIQ, or your email MCP)

```
What important or action-required emails did I receive in the last 7 days that I haven't responded to or actioned?
Include the date, subject, sender, and what action is needed.
```

Extract outstanding actions, pending requests, commitments made via email.

### 7 - Teams/Slack Chats

```
What chat messages from the last 7 days contain action items, requests, or commitments I need to follow up on?
Include the date, who sent it, and what was requested.
```

> **Note:** WorkIQ Teams queries may return "Constraint conflict" - this is a known limitation. If it fails, note the gap and continue.

## Plan Structure

### Header

```markdown
# Week <NN> - <DD>-<DD> <Month> <YYYY>

**Name:** <Your Name> - <Your Role>

---
```

### Key Dates

Table of **all** calendar events for the week, plus known deadlines. Mark important items in **bold**. Include customer mapping and issue references.

```markdown
## Key Dates

| Date | Time | Item | Customer | Issue | Notes |
|------|------|------|----------|-------|-------|
| Mon DD Mon | 09:00 | Team Standup | Internal | - | Routine |
| **Tue DD Mon** | **14:00** | **Customer Workshop** | Fabrikam | #42 | Prep: review knowledge/fabrikam/42/ |
```

**Rules:**
- Include **all** calendar meetings (mark optional ones with "Optional").
- Add known deadlines even without calendar event.
- Sort chronologically.
- Bold rows for items requiring prep or deliverables.

### Deadlines & Commitments

```markdown
## Deadlines & Commitments

| Deadline | Item | Customer | Status |
|----------|------|----------|--------|
| Mon DD Mon | Complete Bicep modification | Fabrikam (#11) | 🔴 Due today |
| This week | Fix repo access | Internal (#26) | 🔴 ASAP |
| Before Wed | Prep equipment spec | Fabrikam (#18) | 🟠 Before sync |
| Fri DD Mon | Vendor response | Fabrikam (#8) | 🟠 |
| TBD | Schedule follow-up workshop | Fabrikam | 🟡 New |
```

**Priority indicators:**
- 🔴 - Due today/tomorrow or overdue.
- 🟠 - Due this week, medium priority.
- 🟡 - Lower priority or flexible deadline.

**Sources:**
- Carry-forward items from last week's report/plan.
- Outstanding email actions.
- Chat commitments.
- Issue deadlines from the board.

### In Progress (Board)

Table of all non-Done issues with next steps.

```markdown
## In Progress (Board)

| Issue | Title | Next Steps |
|-------|-------|------------|
| #1 | Internal - RBAC & IAM | Continue rollout now blocker resolved |
| #18 | Fabrikam - POC | Vendor review, dispatch dates |
```

**Rules:**
- Include issues in **In Progress**, **Ready**, and **Waiting** states.
- For each issue, write concrete next steps from previous week's activity.
- Flag issues where the blocker may have been resolved.

### Focus Blocks (Optional)

If recurring study plans, deep-work blocks, or other structured time exist:

```markdown
## Study Plan

| Evening | Focus |
|---------|-------|
| Mon DD | AZ-104: Identity & Governance |
```

Only include this section if there are active study/training commitments.

## Execution Steps

### Step 1 - Determine the week

Calculate the ISO week number, Monday-Friday date range, and previous week's identifiers.

### Step 2 - Collect data in parallel

Run **all** data-collection queries simultaneously:
- Previous weekly report (view)
- Recent daily reports (view)
- Current/previous weekly plan (view)
- GitHub project board (bash)
- Calendar for the week (WorkIQ)
- Outstanding emails (WorkIQ)
- Teams/Slack chat actions (WorkIQ)

### Step 3 - Analyse and synthesise

1. **Carry-forward analysis** - Compare last week's plan deadlines against daily reports. Identify completed vs slipped.
2. **Board reconciliation** - Cross-reference board state with daily report outcomes. Update next-steps.
3. **Calendar mapping** - Map meetings to customers and issues. Identify meetings needing prep.
4. **Commitment extraction** - Pull outstanding actions from emails, chats, and carry-forward items.
5. **Priority ranking** - Rank commitments using 🔴/🟠/🟡 based on deadline proximity and customer impact.

### Step 4 - Write the plan

Create the plan file following the structure above.

**Important:**
- Be specific in next-steps - "Continue RBAC rollout" beats "Work on IAM".
- Cross-reference issue numbers throughout.
- Include prep notes for key meetings (e.g. "Prep: review `knowledge/fabrikam/42/` findings").
- Flag new items from emails/chats that don't yet have issues - suggest scaffolding them.

### Step 5 - Commit

```bash
git add planning/<YYYY>-W<NN>.md
git commit -m "chore: add W<NN> weekly plan for <DD>-<DD> <Month> <YYYY>

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

Do **not** push - leave that to the user.

## Output

```
Weekly plan created
   File:    planning/<YYYY>-W<NN>.md
   Commit:  <short-sha>
   Week:    <Monday> - <Friday>
   Sources: prev weekly report (✓/✗), prev daily reports (N/7), board (N active), calendar (N meetings), emails (N actions), chats (N actions)

Top priorities:
1. <Highest-priority commitment>
2. <Next>
3. <Next>
```

## Conventions

- **Dates:** ISO 8601 in filenames; human-readable in content.
- **Week format:** `W<NN>` (ISO week number, zero-padded).
- **File naming:** `<YYYY>-W<NN>.md` - e.g. `2026-W17.md`.
- **Commits:** Conventional Commits - `chore: add W<NN> weekly plan ...`.
