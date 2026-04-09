# Tempo API Reference

## Endpoints Used

### POST /4/worklogs — Create Worklog

**URL:** `https://api.us.tempo.io/4/worklogs`

**Auth:** `Authorization: Bearer <TEMPO_API_TOKEN>`

**Request Body:**

```json
{
  "issueId": 123456,
  "timeSpentSeconds": 4500,
  "startDate": "2026-03-16",
  "startTime": "09:00:00",
  "authorAccountId": "712020:abc123...",
  "description": "Optional description"
}
```

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `issueId` | integer | yes | Numeric Jira issue ID (not the key like CODE-7605) |
| `timeSpentSeconds` | integer | yes | Duration in seconds |
| `startDate` | string | yes | `YYYY-MM-DD` format |
| `startTime` | string | yes | `HH:MM:SS` format (24-hour) |
| `authorAccountId` | string | yes | Atlassian account ID from `/rest/api/3/myself` |
| `description` | string | no | Free-text description for the worklog |

**Success Response:** `200 OK` with worklog object including `tempoWorklogId`.

---

### GET /rest/api/3/issue/{key} — Resolve Issue Key to ID

**URL:** `https://{ATLASSIAN_DOMAIN}/rest/api/3/issue/{key}?fields=id`

**Auth:** Basic auth with `ATLASSIAN_EMAIL:ATLASSIAN_API_TOKEN`

**Example:**

```bash
curl -u "$ATLASSIAN_EMAIL:$ATLASSIAN_API_TOKEN" \
  "https://augeomarketing.atlassian.net/rest/api/3/issue/CODE-7605?fields=id"
```

**Response:**

```json
{
  "id": "123456",
  "key": "CODE-7605",
  ...
}
```

Use the `id` field (string, but cast to integer for Tempo).

---

### GET /rest/api/3/myself — Get Account ID

**URL:** `https://{ATLASSIAN_DOMAIN}/rest/api/3/myself`

**Auth:** Basic auth with `ATLASSIAN_EMAIL:ATLASSIAN_API_TOKEN`

**Response:**

```json
{
  "accountId": "712020:abc123...",
  "emailAddress": "user@example.com",
  "displayName": "Aaron Gesmer"
}
```

---

## Tempo API Regions

| Region | Base URL |
|--------|----------|
| US | `https://api.us.tempo.io/4` |
| EU | `https://api.eu.tempo.io/4` |

Use the US endpoint (`api.us.tempo.io`) — covers all US timezones.

---

## WE Category Issue Keys

| Bucket | Key | Issue ID | Description & Examples |
|--------|-----|----------|----------------------|
| WE_PTO_Personal | TEMPO-370 | 715682 | Paid time off, vacation, sick leave, personal time, lunch. Any planned or unplanned absence from work. Note: Holidays are pre-set in Tempo, no need to enter time against official Augeo holidays (unless you actually worked). |
| WE_Team_Meetings | TEMPO-371 | 715686 | Regular team meetings, standups, Town Halls & All-BU meetings, leadership meetings, strategic planning sessions, off-sites, company events, and conferences. |
| WE_1:1_Meetings | TEMPO-372 | 715687 | One-on-one meetings with managers or direct reports; mentoring or coaching conversations. |
| WE_Admin | TEMPO-373 | 715688 | General administrative work such as emails, reporting, paperwork, scheduling, general peer reviews (code/document reviews), general quality assurance tasks, and other support tasks. Includes internal general support/help desk and general operational communications. |
| WE_Training | TEMPO-374 | 715689 | Formal training sessions, webinars, certifications, skill development, workshops, and innovation or R&D time when focused on personal or team skill growth. |
| WE_Operations | TEMPO-375 | 715690 | Operational activities like system maintenance, process improvements, updates, travel time related to work, client calls not linked to tickets, and customer support. |
| WE_Product | TEMPO-401 | 774429 | Covers all product-related strategy and initiatives that are not directly linked to a specific Jira ticket. Use this for high-level product planning, roadmap discussions, and general product strategy work. |
| WE_Business_Development | TEMPO-402 | 774430 | Tracks all business development activities prior to converting a prospect into an official opportunity. Includes lead qualification, prospect engagement, and initial relationship-building efforts. |
| WE_Research & Insights | TEMPO-403 | 774431 | Supports research into industry trends, market dynamics, and competitive intelligence. Use this bucket for gathering insights that inform strategy and decision-making. |

> **Note:** Issue IDs are pre-known — the script can skip the Jira API lookup for TEMPO-* keys by using this table directly.

---

## curl Examples

### Log a single worklog

```bash
curl -X POST \
  -H "Authorization: Bearer $TEMPO_API_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "issueId": 123456,
    "timeSpentSeconds": 4500,
    "startDate": "2026-03-16",
    "startTime": "09:00:00",
    "authorAccountId": "712020:abc123..."
  }' \
  "https://api.us.tempo.io/4/worklogs"
```

### Get worklogs for a date range

```bash
curl -H "Authorization: Bearer $TEMPO_API_TOKEN" \
  "https://api.us.tempo.io/4/worklogs?from=2026-03-16&to=2026-03-16&limit=50"
```

### Delete a worklog

```bash
curl -X DELETE \
  -H "Authorization: Bearer $TEMPO_API_TOKEN" \
  "https://api.us.tempo.io/4/worklogs/{tempoWorklogId}"
```
