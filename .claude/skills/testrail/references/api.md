# TestRail API Reference

## Base URL

```
https://<TESTRAIL_DOMAIN>/index.php?/api/v2
```

## Authentication

All endpoints require HTTP Basic Auth:

```
Authorization: Basic base64(email:api_key)
```

In curl, use `-u "email:api_key"`.

## Content Type

All requests should include:

```
Content-Type: application/json
```

## Endpoint Reference

### Projects

| Method | Endpoint                   | Purpose              |
| ------ | -------------------------- | -------------------- |
| GET    | `/get_projects`            | List all projects    |
| GET    | `/get_project/:project_id` | Get project by ID    |
| POST   | `/add_project`             | Create a new project |

### Suites

| Method | Endpoint                  | Purpose                      |
| ------ | ------------------------- | ---------------------------- |
| GET    | `/get_suites/:project_id` | List all suites in a project |
| GET    | `/get_suite/:suite_id`    | Get suite by ID              |
| POST   | `/add_suite/:project_id`  | Create a new suite           |
| POST   | `/update_suite/:suite_id` | Update suite                 |
| POST   | `/delete_suite/:suite_id` | Delete suite                 |

### Sections

| Method | Endpoint                                       | Purpose                  |
| ------ | ---------------------------------------------- | ------------------------ |
| GET    | `/get_sections/:project_id?suite_id=:suite_id` | List sections in a suite |
| GET    | `/get_section/:section_id`                     | Get section by ID        |
| POST   | `/add_section/:project_id?suite_id=:suite_id`  | Create a new section     |
| POST   | `/update_section/:section_id`                  | Update section           |
| POST   | `/delete_section/:section_id`                  | Delete section           |

### Cases (Test Cases)

| Method | Endpoint                                    | Purpose                   |
| ------ | ------------------------------------------- | ------------------------- |
| GET    | `/get_cases/:project_id?suite_id=:suite_id` | List cases in suite       |
| GET    | `/get_case/:case_id`                        | Get case by ID            |
| POST   | `/add_case/:section_id`                     | Create case under section |
| POST   | `/update_case/:case_id`                     | Update case               |
| POST   | `/delete_case/:case_id`                     | Delete case               |

### Pagination

When listing resources, use query parameters:

- `limit` — results per page (default 250, max 250)
- `offset` — start index (default 0)

Example:

```
GET /get_cases/7?suite_id=4812&limit=250&offset=0
```

### Case Payload Fields

When creating or updating cases (`POST /add_case/:section_id`), send JSON with:

```json
{
  "title": "Case Title",
  "refs": "TICKET-123",
  "custom_preconds": "Precondition HTML or text",
  "custom_steps_separated": [
    { "content": "Step 1", "expected": "Expected result 1" },
    { "content": "Step 2", "expected": "Expected result 2" }
  ],
  "priority_id": 2,
  "type_id": 3,
  "estimate": "30m"
}
```

#### Field Details

| Field                    | Type   | Required | Notes                              |
| ------------------------ | ------ | -------- | ---------------------------------- |
| `title`                  | string | ✓        | Case title                         |
| `refs`                   | string | —        | Reference ID(s), e.g., "JIRA-123"  |
| `custom_preconds`        | string | —        | Preconditions (HTML or plain text) |
| `custom_steps_separated` | array  | —        | Array of step objects              |
| `priority_id`            | int    | —        | 1=High, 2=Medium, 3=Low            |
| `type_id`                | int    | —        | Case type ID                       |
| `estimate`               | string | —        | Time estimate, e.g., "30m", "2h"   |

#### Step Object

Each step in `custom_steps_separated`:

```json
{
  "content": "Step description",
  "expected": "Expected result",
  "additional_info": "",
  "refs": ""
}
```

### Response Structure

All list responses include pagination metadata:

```json
{
  "offset": 0,
  "limit": 250,
  "size": 7,
  "_links": {
    "next": null,
    "prev": null
  },
  "projects": [...],
  "cases": [...],
  "suites": [...]
}
```

### Common Fields in Objects

Most objects include:

- `id` — unique identifier
- `name` — display name
- `created_on` — Unix timestamp
- `updated_on` — Unix timestamp
- `created_by` — user ID of creator
- `updated_by` — user ID of last updater
- `url` — direct link in TestRail UI

### Error Responses

**401 Unauthorized:**

```json
{
  "error": "Authentication failed: invalid or missing user/password or session cookie."
}
```

Check credentials in `.env`.

**404 Not Found:**

```json
{ "error": "Field :resource not found." }
```

Verify resource ID is correct.

## Session/Pagination Notes

- List endpoints default to 250 results per page
- Use `offset=250` to fetch the next 250 results
- Total count is in the `size` field of the response
- API returns URLs to browse results in TestRail UI (check `url` field on objects)
