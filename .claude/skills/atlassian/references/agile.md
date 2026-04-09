# Jira Agile REST API Reference

Base path: `/rest/agile/1.0`

> Examples use bare `atlassian_api.sh` — prepend `$SKILL_DIR/` as defined in SKILL.md.

The Agile API provides access to boards, sprints, backlogs, and epics. Use this
alongside the standard Jira REST API for sprint-related workflows.

## Boards

### List Boards

```http
GET /rest/agile/1.0/board?type=scrum&maxResults=50
```

Query params:

- `type` — `scrum`, `kanban`, or omit for all
- `name` — filter by board name (contains match)
- `projectKeyOrId` — filter by project
- `startAt` / `maxResults` — pagination

Response:

```json
{
  "maxResults": 50,
  "startAt": 0,
  "total": 5,
  "values": [
    {
      "id": 42,
      "name": "CODE Board",
      "type": "scrum",
      "location": {
        "projectId": 10001,
        "projectName": "Code Project",
        "projectKey": "CODE"
      }
    }
  ]
}
```

### Get Board

```http
GET /rest/agile/1.0/board/{boardId}
```

### Get Board Configuration

```http
GET /rest/agile/1.0/board/{boardId}/configuration
```

Returns column mappings, estimation field, ranking settings.

## Sprints

### List Sprints for a Board

```http
GET /rest/agile/1.0/board/{boardId}/sprint?state=active&maxResults=50
```

Query params:

- `state` — `future`, `active`, `closed` (comma-separated for multiple)
- `startAt` / `maxResults` — pagination

Response:

```json
{
  "values": [
    {
      "id": 123,
      "name": "Sprint 14",
      "state": "active",
      "startDate": "2026-03-25T09:00:00.000Z",
      "endDate": "2026-04-08T09:00:00.000Z",
      "originBoardId": 42,
      "goal": "Complete auth refactor"
    }
  ]
}
```

### Get Sprint

```http
GET /rest/agile/1.0/sprint/{sprintId}
```

### Get Issues in Sprint

```http
GET /rest/agile/1.0/sprint/{sprintId}/issue?maxResults=50&fields=summary,status,assignee,priority
```

Query params:

- `fields` — comma-separated field names to return
- `jql` — additional JQL filter applied within the sprint
- `startAt` / `maxResults` — pagination

Response: same format as Jira search (`issues` array with `total`).

### Get Issues in Backlog

```http
GET /rest/agile/1.0/board/{boardId}/backlog?maxResults=50&fields=summary,status,assignee
```

Returns issues not assigned to any active/future sprint.

### Move Issues to Sprint

```http
POST /rest/agile/1.0/sprint/{sprintId}/issue
{
  "issues": ["CODE-123", "CODE-124", "CODE-125"]
}
```

### Move Issues to Backlog

```http
POST /rest/agile/1.0/backlog/issue
{
  "issues": ["CODE-123", "CODE-124"]
}
```

### Create Sprint

```http
POST /rest/agile/1.0/sprint
{
  "name": "Sprint 15",
  "startDate": "2026-04-08T09:00:00.000Z",
  "endDate": "2026-04-22T09:00:00.000Z",
  "originBoardId": 42,
  "goal": "Sprint goal here"
}
```

### Update Sprint

```http
PUT /rest/agile/1.0/sprint/{sprintId}
{
  "name": "Sprint 15 - Extended",
  "goal": "Updated goal",
  "state": "active"
}
```

### Start/Complete Sprint

Use `POST` with `/{sprintId}` for state transitions (partial update). This is different from
`POST` without an ID (create) and `PUT /{sprintId}` (full update of name/goal/dates).

Start a sprint:

```http
POST /rest/agile/1.0/sprint/{sprintId}
{
  "state": "active"
}
```

Close a sprint:

```http
POST /rest/agile/1.0/sprint/{sprintId}
{
  "state": "closed",
  "completeDate": "2026-04-22T17:00:00.000Z"
}
```

### Sprint Report (Velocity)

```http
GET /rest/agile/1.0/board/{boardId}/sprint/{sprintId}/report
```

## Epics

### List Epics on a Board

```http
GET /rest/agile/1.0/board/{boardId}/epic?maxResults=50
```

### Get Issues for Epic

```http
GET /rest/agile/1.0/epic/{epicIdOrKey}/issue?maxResults=50&fields=summary,status,assignee
```

### Get Issues Without Epic

```http
GET /rest/agile/1.0/board/{boardId}/epic/none/issue?maxResults=50
```

### Move Issues to Epic

```http
POST /rest/agile/1.0/epic/{epicIdOrKey}/issue
{
  "issues": ["CODE-123", "CODE-124"]
}
```

## Ranking

### Rank Issues

```http
PUT /rest/agile/1.0/issue/rank
{
  "issues": ["CODE-123"],
  "rankBeforeIssue": "CODE-100"
}
```

Or rank after:

```json
{
  "issues": ["CODE-123"],
  "rankAfterIssue": "CODE-200"
}
```

## Common Workflows

### "What's in the current sprint?"

```bash
# 1. Find the board
atlassian_api.sh GET '/rest/agile/1.0/board?projectKeyOrId=CODE&type=scrum' | \
  python3 .claude/skills/atlassian/scripts/format_response.py boards

# 2. Get active sprint
atlassian_api.sh GET '/rest/agile/1.0/board/42/sprint?state=active'

# 3. Get sprint issues
atlassian_api.sh GET '/rest/agile/1.0/sprint/123/issue?fields=summary,status,assignee,priority' | \
  python3 .claude/skills/atlassian/scripts/format_response.py search
```

### "What's in the backlog?"

```bash
atlassian_api.sh GET '/rest/agile/1.0/board/42/backlog?fields=summary,status,priority&maxResults=30' | \
  python3 .claude/skills/atlassian/scripts/format_response.py search
```

### "Move these tickets to the next sprint"

```bash
# Find future sprints
atlassian_api.sh GET '/rest/agile/1.0/board/42/sprint?state=future'

# Move issues
atlassian_api.sh POST '/rest/agile/1.0/sprint/124/issue' '{"issues":["CODE-123","CODE-124"]}'
```
