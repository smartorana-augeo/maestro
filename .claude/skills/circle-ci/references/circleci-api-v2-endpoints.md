# CircleCI API v2 — Endpoint Reference

Base URL: `https://circleci.com/api/v2`

All requests require the header: `Circle-Token: $CIRCLECI_TOKEN`

## Project Slug Format

CircleCI uses "project slugs" in the format: `gh/{org}/{repo}` (for GitHub).

Primary project: `gh/Structuralapp/ambassador`

---

## Pipelines

### List Pipelines for a Project

```text
GET /project/{project-slug}/pipeline
```

Query params:

- `branch` — filter by branch name (optional)
- `page-token` — pagination token (optional)

Response shape:

```json
{
  "items": [
    {
      "id": "pipeline-uuid",
      "number": 123,
      "state": "created",
      "trigger": { "type": "webhook", "actor": { "login": "username" } },
      "vcs": { "branch": "main", "revision": "sha" },
      "created_at": "2026-01-01T00:00:00.000Z"
    }
  ],
  "next_page_token": "..."
}
```

### Get a Single Pipeline

```text
GET /pipeline/{pipeline-id}
```

### List Pipelines Triggered by You

```text
GET /project/{project-slug}/pipeline/mine
```

---

## Workflows

### List Workflows for a Pipeline

```text
GET /pipeline/{pipeline-id}/workflow
```

Response shape:

```json
{
  "items": [
    {
      "id": "workflow-uuid",
      "name": "build-test-deploy",
      "status": "failed",
      "created_at": "2026-01-01T00:00:00.000Z",
      "stopped_at": "2026-01-01T00:05:00.000Z",
      "pipeline_id": "pipeline-uuid",
      "pipeline_number": 123
    }
  ]
}
```

Workflow statuses: `success`, `running`, `not_run`, `failed`, `error`, `failing`, `on_hold`, `canceled`, `unauthorized`

### Get a Single Workflow

```text
GET /workflow/{workflow-id}
```

### Rerun a Workflow

```text
POST /workflow/{workflow-id}/rerun
```

Body (optional):

```json
{
  "from_failed": true,
  "sparse_tree": false
}
```

### Cancel a Workflow

```text
POST /workflow/{workflow-id}/cancel
```

---

## Jobs

### List Jobs for a Workflow

```text
GET /workflow/{workflow-id}/job
```

Response shape:

```json
{
  "items": [
    {
      "id": "job-uuid",
      "name": "test",
      "job_number": 456,
      "status": "failed",
      "type": "build",
      "started_at": "2026-01-01T00:01:00.000Z",
      "stopped_at": "2026-01-01T00:03:00.000Z"
    }
  ]
}
```

Job statuses: `success`, `running`, `not_run`, `failed`, `retried`, `timedout`, `infrastructure_fail`, `canceled`, `blocked`, `queued`

### Get Job Details

```text
GET /project/{project-slug}/job/{job-number}
```

### Get Job Artifacts

```text
GET /project/{project-slug}/{job-number}/artifacts
```

Response:

```json
{
  "items": [
    {
      "path": "test-results/results.xml",
      "url": "https://output.circle-artifacts.com/...",
      "node_index": 0
    }
  ]
}
```

### Get Test Results for a Job

```text
GET /project/{project-slug}/{job-number}/tests
```

Response:

```json
{
  "items": [
    {
      "name": "should create a user",
      "classname": "UserService",
      "status": "failure",
      "message": "Expected 200 but got 404",
      "run_time": 0.123,
      "source": "test-results/results.xml"
    }
  ],
  "next_page_token": "..."
}
```

Test statuses: `success`, `failure`, `error`, `skipped`

---

## Insights

### Get Workflow Summary Metrics

```text
GET /insights/{project-slug}/workflows/{workflow-name}
```

Query params:

- `branch` — filter by branch (optional)
- `reporting-window` — `last-7-days`, `last-30-days`, `last-60-days`, `last-90-days` (optional)

### Get Job Summary Metrics

```text
GET /insights/{project-slug}/workflows/{workflow-name}/jobs
```

### Get Flaky Tests

```text
GET /insights/{project-slug}/flaky-tests
```

---

## Environment Variables

### List Env Vars for a Project

```text
GET /project/{project-slug}/envvar
```

### Get a Single Env Var

```text
GET /project/{project-slug}/envvar/{name}
```

Note: Values are masked in responses (only last 4 characters shown).

---

## Pagination

All list endpoints return paginated results. Use the `next_page_token` from the response:

```text
GET /project/{project-slug}/pipeline?page-token={next_page_token}
```

---

## Rate Limits

CircleCI enforces rate limits on API v2 requests. Throttled requests return HTTP `429 Too Many Requests`.

Practical guidelines:

- Add a small delay (0.5–1 s) between calls when iterating over many resources.
- Use pagination (`page-token`) rather than polling the same endpoint repeatedly.
- Cache responses (e.g., pipeline/workflow metadata) when the data does not change frequently.
- If you receive a `429`, back off exponentially before retrying.

> **Official docs:** CircleCI documents current rate-limit thresholds at
> <https://circleci.com/docs/api-developers-guide/#rate-limits>.
> Always check there for the most up-to-date numbers.
