# JSM Ops (Jira Service Management Operations) API Reference

Base path: `/jsm/ops/api/v1`

JSM Ops provides alert management, on-call scheduling, and team management for
incident response workflows.

## Alerts

### Get Alert by ID

```http
GET /jsm/ops/api/v1/alerts/{alertId}
```

Query params:

- `identifierType` — `id` (default) or `alias`

Response:

```json
{
  "data": {
    "id": "alert-uuid",
    "alias": "alert-alias",
    "message": "CPU usage exceeded 90%",
    "status": "open",
    "acknowledged": false,
    "priority": "P1",
    "createdAt": "2026-04-03T08:00:00Z",
    "updatedAt": "2026-04-03T08:05:00Z",
    "source": "monitoring-service",
    "tags": ["production", "critical"],
    "teams": [{ "id": "team-uuid", "name": "SRE Team" }],
    "responders": [
      { "type": "team", "id": "team-uuid", "name": "SRE Team" },
      { "type": "user", "id": "user-uuid", "username": "john.doe" }
    ],
    "description": "Detailed alert description",
    "details": {
      "host": "prod-server-01",
      "metric": "cpu_usage",
      "value": "95%"
    }
  }
}
```

### Search Alerts

```http
GET /jsm/ops/api/v1/alerts?query={query}&limit=10&offset=0&sort=createdAt&order=desc
```

Query examples:

- `status:open` — all open alerts
- `status:open AND priority:P1` — critical open alerts
- `tag:production` — alerts tagged "production"
- `createdAt > '2026-04-01T00:00:00Z'` — alerts since a date
- `teams.name:SRE` — alerts assigned to SRE team

Query params:

- `query` — search query string
- `limit` — max results (default 20, max 100)
- `offset` — pagination offset
- `sort` — field to sort by (`createdAt`, `updatedAt`, `status`)
- `order` — `asc` or `desc`
- `searchIdentifier` — saved search name
- `searchIdentifierType` — `name` or `id`

### Alert Actions

**Acknowledge:**

```http
POST /jsm/ops/api/v1/alerts/{alertId}/acknowledge
{
  "user": "user@example.com",
  "note": "Looking into this"
}
```

**Unacknowledge:**

```http
POST /jsm/ops/api/v1/alerts/{alertId}/unacknowledge
{
  "user": "user@example.com",
  "note": "Need more investigation"
}
```

**Close:**

```http
POST /jsm/ops/api/v1/alerts/{alertId}/close
{
  "user": "user@example.com",
  "note": "Resolved — scaled up instances"
}
```

**Escalate:**

```http
POST /jsm/ops/api/v1/alerts/{alertId}/escalate
{
  "escalation": { "name": "Critical Escalation Policy" },
  "user": "user@example.com",
  "note": "Escalating to on-call lead"
}
```

**Add note to alert:**

```http
POST /jsm/ops/api/v1/alerts/{alertId}/notes
{
  "user": "user@example.com",
  "note": "Investigating root cause"
}
```

## Schedules

### List Schedules

```http
GET /jsm/ops/api/v1/schedules
```

Response:

```json
{
  "data": [
    {
      "id": "schedule-uuid",
      "name": "Primary On-Call",
      "description": "24/7 primary on-call rotation",
      "timezone": "America/Chicago",
      "enabled": true,
      "ownerTeam": { "id": "team-uuid", "name": "SRE Team" },
      "rotations": [
        {
          "id": "rotation-uuid",
          "name": "Weekly Rotation",
          "type": "weekly",
          "participants": [
            { "type": "user", "id": "user-uuid", "username": "john.doe" }
          ]
        }
      ]
    }
  ]
}
```

### Get Current On-Call

```http
GET /jsm/ops/api/v1/schedules/{scheduleId}/on-calls
```

Query params:

- `date` — specific date/time (ISO 8601), defaults to now
- `flat` — `true` to flatten the response

Response:

```json
{
  "data": {
    "onCallParticipants": [
      {
        "id": "user-uuid",
        "name": "John Doe",
        "type": "user"
      }
    ]
  }
}
```

### Get Next On-Call

```http
GET /jsm/ops/api/v1/schedules/{scheduleId}/next-on-calls
```

## Teams

### List Teams

```http
GET /jsm/ops/api/v1/teams
```

Response:

```json
{
  "data": [
    {
      "id": "team-uuid",
      "name": "SRE Team",
      "description": "Site Reliability Engineering",
      "members": [
        {
          "user": { "id": "user-uuid", "username": "john.doe" },
          "role": "admin"
        }
      ]
    }
  ]
}
```

### Get Team Details

```http
GET /jsm/ops/api/v1/teams/{teamId}
```

Query params:

- `identifierType` — `id` (default) or `name`

Returns full team info including members, escalation policies, and routing rules.

### Get Team Escalation Policies

```http
GET /jsm/ops/api/v1/teams/{teamId}/escalation-policies
```

### Get Team Routing Rules

```http
GET /jsm/ops/api/v1/teams/{teamId}/routing-rules
```
