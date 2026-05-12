---
name: daily-report
description: >
  Generate a daily summary report from git history, Copilot session history, calendar, emails, and Teams/Slack chats. Produces a markdown report in `reports/`.
---

# Daily Report Skill

Build a comprehensive daily summary by aggregating data from every available source, then writing and committing it to `reports/`.

## Inputs

| Input    | Required | Default               | Example      |
|----------|----------|-----------------------|--------------|
| **date** | No       | Yesterday's date      | `2026-04-15` |

If no date is supplied, default to **yesterday** (the day before the current date).

## Data Sources

Collect data from **all** sources below. If a source is unavailable, note the gap and continue - do not block the report.

### 1 - Git History

```bash
git --no-pager log --all --oneline \
  --since="<date>T00:00:00" --until="<next-day>T00:00:00" \
  --format="%h %s (%an, %ai)" | head -100
```

Extract: commit hash, message, timestamp. Group by time for the hour-by-hour playback. Parse issue numbers from commit messages (e.g. `#12`).

### 2 - Copilot Session History

Session data lives in **two** places. Try both and merge results.

#### 2a - Local SQLite Database (primary)

The local session store at `~/.copilot/session-store.db` is a SQLite database containing all CLI sessions across every repo.

**Schema:**

| Table            | Key Columns                                                                                                 |
|------------------|-------------------------------------------------------------------------------------------------------------|
| `sessions`       | `id`, `cwd`, `repository`, `host_type`, `branch`, `summary`, `created_at`, `updated_at`                     |
| `turns`          | `session_id`, `turn_index`, `user_message`, `assistant_response`, `timestamp`                               |
| `session_files`  | `session_id`, `file_path`, `tool_name`, `first_seen_at`                                                     |
| `session_refs`   | `session_id`, `ref_type`, `ref_value`, `turn_index`, `created_at`                                           |
| `checkpoints`    | `session_id`, `checkpoint_number`, `title`, `overview`, `created_at`                                        |

**Queries:**

```bash
# Sessions active on the target date
sqlite3 ~/.copilot/session-store.db "
SELECT id, repository, branch, summary, created_at, updated_at
FROM sessions
WHERE date(created_at) = '<date>'
   OR (date(created_at) < '<date>' AND date(updated_at) >= '<date>')
ORDER BY created_at;
"

# Turn-level detail
sqlite3 ~/.copilot/session-store.db "
SELECT session_id, turn_index, timestamp,
       substr(COALESCE(user_message, ''), 1, 300) as user_msg
FROM turns
WHERE session_id IN ('<id1>', '<id2>')
ORDER BY timestamp;
"

# File changes made in those sessions
sqlite3 ~/.copilot/session-store.db "
SELECT session_id, file_path, tool_name, first_seen_at
FROM session_files
WHERE session_id IN ('<id1>', '<id2>')
ORDER BY first_seen_at;
"
```

> **Timestamps:** Local SQLite stores UTC. Convert to your local timezone for the report.

#### 2b - Cloud Session Store (fallback)

If the local DB is unavailable, fall back to the `session_store_sql` tool. Use both `personal` and `repository` scopes to capture cross-repo sessions.

> The cloud store may be empty or incomplete. If it returns 0 rows, this is expected. Always try the local DB first.

### 3 - Calendar (M365 via WorkIQ, or your calendar MCP)

```
What meetings did I have on my calendar for <day-name> <date>?
List each meeting with the time, title, and attendees.
```

Extract: time, title, attendees, customer mapping.

### 4 - Emails (M365 via WorkIQ, or your email MCP)

```
What emails did I send and receive on <day-name> <date>?
Include the time, subject, sender/recipient, and a one-line summary.
```

Filter out noise (newsletters, automated announcements, personal). Keep work-relevant emails.

### 5 - GitHub Issues & Project Board Activity

Capture issues that were **opened, closed, or moved** on the target date. This catches work that doesn't show up in commits.

Read the project number and owner from `.github/copilot-instructions.md`.

```bash
# Issues closed on the date
gh issue list --state all --search "closed:<date>" \
  --json number,title,state,closedAt --limit 50

# Issues created on the date
gh issue list --state all --search "created:<date>" \
  --json number,title,state,createdAt --limit 50

# Any issue with activity on the date
gh issue list --state all --search "updated:<date>" \
  --json number,title,state,updatedAt,labels --limit 100

# Project board snapshot - current Status column for each item
gh project item-list <PROJECT_NUMBER> --owner <PROJECT_OWNER> --format json --limit 200 \
  | jq '.items[] | select(.content.number) | {num: .content.number, title: .content.title, status: .status}'
```

**Use this data to:**
- Add an **Issues Touched** row for every issue closed/created/moved that day, even with no commit.
- Cross-check the activity timeline.
- If an issue was closed but you have no other context for it, **ask the user** before guessing - don't fabricate detail.

### 6 - Teams / Slack Chats (via WorkIQ or your chat MCP)

```
What Teams chat messages and channel messages did I send or receive on <day-name> <date>?
List the time, participants, and brief content summary.
```

> **Note:** WorkIQ Teams queries may return "Constraint conflict" - this is a known limitation. If it fails, note the gap and continue.

## Report Structure

The report **must** contain these sections in order:

### Header

```markdown
# Daily Summary Report - <Day-Name> <DD> <Month> <YYYY> (W<NN>)

**Name:** <Your Name> - <Your Role>
**Report Date:** <DD> <Month> <YYYY>

---
```

### Hour-by-Hour Playback

Group activities chronologically into hour blocks. Each block has a heading like `### 06:00 - 07:00 - <Theme>`. Within each block, list events as bullet points with bold timestamps:

```markdown
- **08:30** - **Meeting:** <title> (<attendees>).
- **09:14** - Committed <description> (`<hash>`).
- **10:02** - Email from <sender>: <subject> - <one-line summary>.
```

**Rules:**
- Merge all sources into a single unified timeline.
- Use your local timezone for all timestamps.
- Mark meetings with **Meeting:** prefix.
- Mark emails with "Email from" prefix.
- Mark training/learning with **Meeting / Training:** prefix.
- Include commit hashes in backticks and issue references as `#<number>`.

### Summary by Customer

```markdown
| Customer       | Time (approx) | Activities |
|----------------|---------------|------------|
| **Fabrikam**   | ~5 h          | <activities> |
| **Total**      | **~N h**      | -          |
```

### Commits

```markdown
| Time  | Hash      | Message |
|-------|-----------|---------|
| 08:22 | `06132fc` | docs(#12): add meeting notes |
```

### Issues Touched

```markdown
| Issue | Customer | Action |
|-------|----------|--------|
| #12   | Fabrikam | <what was done> |
```

### Meetings

```markdown
| Time        | Meeting | Customer | Attendees |
|-------------|---------|----------|-----------|
| 08:30-09:00 | 1:1 with Manager | Internal | Jane Smith |
```

### Copilot Sessions

```markdown
| Session | Duration | Focus |
|---------|----------|-------|
| `289547c5` | 06:20 - 09:37 (~3 h) | <what was worked on> |
```

### Key Emails (Work-Related)

Filter out automated announcements, personal emails, calendar invite reminders.

```markdown
| Time  | From | Subject | Summary |
|-------|------|---------|---------|
| 10:24 | Carol Wright | Following up after meeting | Recap + next actions |
```

### Notable Items & Follow-ups

Numbered list of key outcomes, decisions, and required follow-up actions. **The most important section** - drives the next day's priorities.

```markdown
1. **Fabrikam Webhook (#27)** - Reverse-IaC produced. Issue closed. Follow-up: production review next week.
2. **Internal IAM (#1)** - Blocker resolved. Can proceed with rollout.
```

## Execution Steps

### Step 1 - Determine the date

If no date provided, calculate yesterday's date. Determine day name and ISO week number.

### Step 2 - Collect data in parallel

Run **all** data-collection queries simultaneously:
- Git log
- Local session store (`sqlite3`)
- GitHub issues (closed/created/updated)
- Project board snapshot
- Calendar (WorkIQ)
- Emails (WorkIQ)
- Teams/Slack chats (WorkIQ)

If the local session store DB doesn't exist, fall back to the cloud `session_store_sql` tool.

### Step 3 - Read the most recent report for format reference

```bash
ls -t reports/????-??-??.md | head -1
```

Read the most recent daily report to match formatting exactly.

### Step 4 - Build the report

Merge all collected data into a single chronological timeline. Write the report following the structure above.

**Important:**
- Convert UTC session timestamps to your local timezone.
- Git commit timestamps are already in local time.
- WorkIQ timestamps are typically already in local time - verify from context.

### Step 5 - Write and commit

```bash
git add reports/<YYYY-MM-DD>.md
git commit -m "docs: add daily summary report for <YYYY-MM-DD>

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

Do **not** push - leave that to the user.

## Output

```
Daily report created
   File:    reports/<YYYY-MM-DD>.md
   Commit:  <short-sha>
   Sources: git (N commits), sessions (N), issues (N closed / N updated), calendar (N meetings), emails (N), chats (N or unavailable)
```

## Conventions

- **Dates:** ISO 8601 (`YYYY-MM-DD`) in filenames; human-readable (`DD Month YYYY`) in content.
- **Times:** Your local timezone, 24-hour format.
- **Commits:** Conventional Commits - `docs: add daily summary report for <YYYY-MM-DD>`.

## Error Handling

| Source                    | If unavailable |
|---------------------------|---------------|
| Git                       | Skip commits section (unlikely to fail) |
| Local session store       | Fall back to cloud `session_store_sql`. If both fail, note "Session data unavailable" |
| GitHub CLI (`gh`)         | Skip Issues Touched cross-check; rely on commits + sessions |
| WorkIQ (calendar/email)   | Note "Calendar/email data unavailable - add manually" |
| WorkIQ (chat)             | Note "Chat data unavailable" and continue |
