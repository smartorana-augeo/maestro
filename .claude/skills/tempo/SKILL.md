---
name: tempo
description: >-
  Log time entries to Tempo (Jira time tracking) by fetching Outlook calendar events
  via Microsoft 365 MCP or parsing a pasted list of time ranges and issue keys.
  Use this skill proactively whenever the user mentions logging time, submitting worklogs,
  tracking hours, filling out timesheets, or billing time to Jira issues. Also trigger
  when the user references their calendar or schedule and wants to extract billable hours,
  asks "what did I work on yesterday", or provides a list of times and issue keys —
  even without explicitly mentioning Tempo.
---

# Tempo Time Logging

Log time to Tempo from pasted entries or Outlook calendar events via `log_time.sh`.

## Execution Behavior

Always dry-run first and present the preview table. Only post worklogs after explicit user confirmation.

## Authentication

Four env vars required — add to the project `.env` file:

```bash
TEMPO_API_TOKEN=<token from Jira → Apps → Tempo → Settings → API Integration>
ATLASSIAN_API_TOKEN=<token from id.atlassian.com/manage-profile/security/api-tokens>
ATLASSIAN_EMAIL=<your jira email>              # already in .env
ATLASSIAN_DOMAIN=augeomarketing.atlassian.net  # already in .env
```

## Script Usage

```bash
.claude/skills/tempo/scripts/log_time.sh [--date YYYY-MM-DD] [--dry-run] < /tmp/time_entries.txt
```

| Flag         | Description                          | Default |
| ------------ | ------------------------------------ | ------- |
| `--date, -d` | Date for all entries                 | today   |
| `--dry-run`  | Preview parsed entries; no API calls | off     |
| `--help, -h` | Show usage                           |         |

Use Bash (not the Write tool) to create `/tmp/time_entries.txt` — the file may not exist yet and the Write tool requires a prior read. Then run with `--dry-run`. On confirmation, run without it.

## Input Format

One entry per line on stdin:

```text
- 9:00 - 10:15 CODE-7605
- 10:15 - 10:30 TEMPO-371 (AWE Daily Standup)
- 1:00 - 3:30 CODE-7605
```

- Times: `H:MM` or `HH:MM` — no AM/PM suffix
- **AM/PM rule:** 1–6 = PM (13–18), 7–11 = AM, 12 = 12:00 noon (not midnight)
- Issue key required; description in parentheses optional
- Duration calculated from the time range

## Calendar Workflow

When the user asks to log time without pasting entries, fetch from Outlook:

1. **Determine date** — default today; adjust if the user says "yesterday" or gives a specific date.
2. **Fetch events** — use Microsoft 365 MCP `outlook_calendar_search` for the target date. Compute the full day window (00:00–23:59 local) and convert to UTC for the query. If MCP fails, ask the user to paste entries manually.
3. **Filter** — exclude declined, cancelled, all-day, and zero-duration events. Include tentative with "(tentative)" in description.
4. **Extract issue keys** — scan titles with regex `[A-Z][A-Z0-9]+-\d+`; first match wins, strip surrounding brackets. Convert UTC event times to local timezone using Python's `datetime.astimezone()`.
5. **Resolve missing keys** — prompt for ALL unmatched events at once in a single numbered list. Show the WE Category table from `references/tempo-api.md`. Accept flexible formats (`1: TEMPO-371, 2: skip`). Never ask one-by-one.
6. **Handle edge cases** — warn on overlapping events and let the user decide. Ask about private/busy events. Flag midnight-spanning events for splitting.
7. **Assemble** — format as `- HH:MM - HH:MM KEY (Title)`, use Bash to write `/tmp/time_entries.txt` (not the Write tool), then dry-run via script.

## Examples

```bash
# Dry-run preview for today
.claude/skills/tempo/scripts/log_time.sh --dry-run < /tmp/time_entries.txt

# Post entries for today after confirmation
.claude/skills/tempo/scripts/log_time.sh < /tmp/time_entries.txt

# Post entries for a specific date
.claude/skills/tempo/scripts/log_time.sh --date 2026-03-15 < /tmp/time_entries.txt
```

## Troubleshooting

- **`TEMPO_API_TOKEN is not set`** — add to project `.env`
- **`Could not resolve issue key XYZ-123`** — verify key exists in Jira; check `ATLASSIAN_API_TOKEN` and `ATLASSIAN_EMAIL`
- **`401 Unauthorized` from Tempo** — regenerate token in Jira → Apps → Tempo → Settings → API Integration
- **Time math wrong** — remember AM/PM rule: `1:00` = 13:00, `9:00` = 09:00, `12:00` = 12:00 noon
- **Network timeout** — API calls timeout after 30s; check connectivity or retry
- **Partial success** — if some entries fail, script exits with code 1; successful entries are still logged

## Exit Codes

| Code | Meaning                                                      |
| ---- | ------------------------------------------------------------ |
| `0`  | All entries logged successfully (or dry-run completed)       |
| `1`  | One or more entries failed, missing config, or invalid input |

## Discovery

For API endpoints, response schemas, and the full WE Category issue key table, see `references/tempo-api.md`.

## Permissions

Entries in `.claude/settings.local.json` that allow this skill to run without approval:

```json
"Bash(bash .claude/skills/tempo/*)",
"Bash(.claude/skills/tempo/scripts/log_time.sh *)",
"mcp__claude_ai_Microsoft_365__outlook_calendar_search"
```
