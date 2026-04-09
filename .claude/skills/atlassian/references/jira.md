# Jira REST API v3 Reference

Base path: `/rest/api/3`

> Examples use bare `atlassian_api.sh` — prepend `$SKILL_DIR/` as defined in SKILL.md.

## Contents

- [Issues](#issues) — Get, search (JQL), create, edit, transitions, comments, worklogs, remote links
- [Projects](#projects) — List, issue types
- [Users](#users) — Search, current user
- [Atlassian Document Format (ADF)](#atlassian-document-format-adf) — Block/inline nodes for rich text
- [Issue Links](#issue-links) — Link types, create/delete/read links
- [Attachments](#attachments) — Upload, list, download, delete
- [Bulk Operations](#bulk-operations) — Bulk edit, transition, create, delete

## Issues

### Get Issue

```http
GET /rest/api/3/issue/{issueIdOrKey}
```

Query params:

- `fields` — comma-separated field names (e.g. `summary,status,assignee`)
- `expand` — comma-separated expansions (e.g. `renderedFields,changelog,transitions`)

Response key fields:

```json
{
  "key": "CODE-123",
  "fields": {
    "summary": "Issue title",
    "description": {
      /* ADF document */
    },
    "status": { "name": "In Progress", "id": "3" },
    "priority": { "name": "High", "id": "2" },
    "assignee": { "accountId": "...", "displayName": "John Doe" },
    "reporter": { "accountId": "...", "displayName": "Jane Doe" },
    "issuetype": { "name": "Story", "id": "10001" },
    "project": { "key": "CODE", "name": "Project Name" },
    "created": "2026-01-15T10:30:00.000+0000",
    "updated": "2026-04-01T14:22:00.000+0000",
    "labels": ["frontend", "urgent"],
    "components": [{ "name": "UI" }],
    "fixVersions": [{ "name": "v2.1" }],
    "customfield_10020": [
      { "id": 123, "name": "Sprint 14", "state": "active" }
    ],
    "customfield_10016": 5,
    "parent": { "key": "CODE-100" },
    "subtasks": [{ "key": "CODE-124" }]
  }
}
```

### Search Issues (JQL)

```http
GET /rest/api/3/search/jql?jql={jql}&startAt=0&maxResults=50&fields=summary,status,assignee
```

Or POST for complex queries:

```http
POST /rest/api/3/search/jql
{
  "jql": "project = CODE AND status = 'In Progress' ORDER BY updated DESC",
  "startAt": 0,
  "maxResults": 50,
  "fields": ["summary", "status", "assignee", "priority"]
}
```

Response:

```json
{
  "startAt": 0,
  "maxResults": 50,
  "total": 142,
  "issues": [
    /* array of issue objects */
  ]
}
```

### Common JQL Patterns

```jql
assignee = currentUser()
assignee = "accountId"
project = CODE AND status = "In Progress"
sprint in openSprints()
sprint = "Sprint 14"
labels = "frontend"
created >= -7d
updated >= startOfDay()
issuetype = Story
priority = High
text ~ "search term"
issuekey in (CODE-1, CODE-2, CODE-3)
parent = CODE-100
```

### Create Issue

```http
POST /rest/api/3/issue
{
  "fields": {
    "project": { "key": "CODE" },
    "summary": "Issue title",
    "issuetype": { "name": "Task" },
    "description": { /* ADF document */ },
    "assignee": { "accountId": "..." },
    "priority": { "name": "High" },
    "labels": ["frontend"],
    "components": [{ "name": "UI" }],
    "parent": { "key": "CODE-100" }
  }
}
```

To discover required fields for a project/issue-type:

```http
GET /rest/api/3/issue/createmeta/{projectIdOrKey}/issuetypes
GET /rest/api/3/issue/createmeta/{projectIdOrKey}/issuetypes/{issueTypeId}
```

### Edit Issue

```http
PUT /rest/api/3/issue/{issueIdOrKey}
{
  "fields": {
    "summary": "Updated title",
    "labels": ["frontend", "reviewed"]
  }
}
```

Only include fields you want to change. For array fields, the value replaces the entire array.

### Transitions

```http
GET /rest/api/3/issue/{issueIdOrKey}/transitions
```

Response:

```json
{
  "transitions": [
    { "id": "21", "name": "In Progress", "to": { "name": "In Progress" } },
    { "id": "31", "name": "Done", "to": { "name": "Done" } }
  ]
}
```

Execute transition:

```http
POST /rest/api/3/issue/{issueIdOrKey}/transitions
{
  "transition": { "id": "31" },
  "update": {
    "comment": [{
      "add": {
        "body": { /* ADF document */ }
      }
    }]
  }
}
```

### Comments

```http
GET /rest/api/3/issue/{issueIdOrKey}/comment
POST /rest/api/3/issue/{issueIdOrKey}/comment
{
  "body": { /* ADF document */ }
}
```

### Worklogs

```http
POST /rest/api/3/issue/{issueIdOrKey}/worklog
{
  "timeSpentSeconds": 3600,
  "started": "2026-04-03T09:00:00.000+0000",
  "comment": { /* ADF document, optional */ }
}
```

### Remote Links

```http
GET /rest/api/3/issue/{issueIdOrKey}/remotelink
```

## Projects

### List Projects

```http
GET /rest/api/3/project/search?startAt=0&maxResults=50
```

Query params:

- `query` — filter by name
- `keys` — comma-separated project keys
- `action` — `view`, `browse`, `edit`

### Issue Types for a Project

```http
GET /rest/api/3/issue/createmeta/{projectIdOrKey}/issuetypes
```

## Users

### Search Users

```http
GET /rest/api/3/user/search?query=john
```

Returns array of user objects with `accountId`, `displayName`, `emailAddress`.

### Current User

```http
GET /rest/api/3/myself
```

## Atlassian Document Format (ADF)

ADF is used for all rich text in Jira v3 (description, comments, etc.).

### Basic Structure

```json
{
  "type": "doc",
  "version": 1,
  "content": [
    /* block nodes */
  ]
}
```

### Block Nodes

**Paragraph:**

```json
{ "type": "paragraph", "content": [{ "type": "text", "text": "Hello" }] }
```

**Heading (levels 1-6):**

```json
{
  "type": "heading",
  "attrs": { "level": 2 },
  "content": [{ "type": "text", "text": "Title" }]
}
```

**Bullet list:**

```json
{
  "type": "bulletList",
  "content": [
    {
      "type": "listItem",
      "content": [
        {
          "type": "paragraph",
          "content": [{ "type": "text", "text": "Item 1" }]
        }
      ]
    }
  ]
}
```

**Ordered list:**

```json
{
  "type": "orderedList",
  "content": [
    {
      "type": "listItem",
      "content": [
        {
          "type": "paragraph",
          "content": [{ "type": "text", "text": "Step 1" }]
        }
      ]
    }
  ]
}
```

**Code block:**

```json
{
  "type": "codeBlock",
  "attrs": { "language": "javascript" },
  "content": [{ "type": "text", "text": "const x = 1;" }]
}
```

**Table:**

```json
{
  "type": "table",
  "content": [
    {
      "type": "tableRow",
      "content": [
        {
          "type": "tableHeader",
          "content": [
            {
              "type": "paragraph",
              "content": [{ "type": "text", "text": "Header" }]
            }
          ]
        },
        {
          "type": "tableHeader",
          "content": [
            {
              "type": "paragraph",
              "content": [{ "type": "text", "text": "Value" }]
            }
          ]
        }
      ]
    },
    {
      "type": "tableRow",
      "content": [
        {
          "type": "tableCell",
          "content": [
            {
              "type": "paragraph",
              "content": [{ "type": "text", "text": "Row 1" }]
            }
          ]
        },
        {
          "type": "tableCell",
          "content": [
            {
              "type": "paragraph",
              "content": [{ "type": "text", "text": "Data" }]
            }
          ]
        }
      ]
    }
  ]
}
```

**Block quote:**

```json
{
  "type": "blockquote",
  "content": [
    { "type": "paragraph", "content": [{ "type": "text", "text": "Quote" }] }
  ]
}
```

**Rule (horizontal line):**

```json
{ "type": "rule" }
```

**Panel (info, note, warning, error, success):**

```json
{
  "type": "panel",
  "attrs": { "panelType": "info" },
  "content": [
    {
      "type": "paragraph",
      "content": [{ "type": "text", "text": "Note text" }]
    }
  ]
}
```

### Inline Nodes

**Bold/italic/code:**

```json
{ "type": "text", "text": "bold text", "marks": [{ "type": "strong" }] }
{ "type": "text", "text": "italic text", "marks": [{ "type": "em" }] }
{ "type": "text", "text": "code", "marks": [{ "type": "code" }] }
```

**Link:**

```json
{
  "type": "text",
  "text": "Click here",
  "marks": [{ "type": "link", "attrs": { "href": "https://example.com" } }]
}
```

**Mention:**

```json
{ "type": "mention", "attrs": { "id": "accountId", "text": "@John Doe" } }
```

**Emoji:**

```json
{ "type": "emoji", "attrs": { "shortName": ":thumbsup:" } }
```

## Issue Links

### List Link Types

```http
GET /rest/api/3/issueLinkType
```

Response:

```json
{
  "issueLinkTypes": [
    {
      "id": "10000",
      "name": "Blocks",
      "inward": "is blocked by",
      "outward": "blocks"
    },
    {
      "id": "10001",
      "name": "Cloners",
      "inward": "is cloned by",
      "outward": "clones"
    },
    {
      "id": "10002",
      "name": "Duplicate",
      "inward": "is duplicated by",
      "outward": "duplicates"
    },
    {
      "id": "10003",
      "name": "Relates",
      "inward": "relates to",
      "outward": "relates to"
    }
  ]
}
```

### Create Issue Link

```http
POST /rest/api/3/issueLink
{
  "type": { "name": "Blocks" },
  "inwardIssue": { "key": "CODE-124" },
  "outwardIssue": { "key": "CODE-123" },
  "comment": {
    "body": { "type": "doc", "version": 1, "content": [
      { "type": "paragraph", "content": [{ "type": "text", "text": "Linked via API" }] }
    ]}
  }
}
```

This means CODE-123 **blocks** CODE-124 (outward blocks inward).

### Delete Issue Link

```http
DELETE /rest/api/3/issueLink/{linkId}
```

Get `linkId` from the issue's `fields.issuelinks` array.

### Reading Links on an Issue

Links appear in `fields.issuelinks` when you GET an issue:

```json
{
  "issuelinks": [
    {
      "id": "54321",
      "type": {
        "name": "Blocks",
        "inward": "is blocked by",
        "outward": "blocks"
      },
      "outwardIssue": {
        "key": "CODE-124",
        "fields": { "summary": "...", "status": { "name": "Open" } }
      }
    }
  ]
}
```

## Attachments

### Add Attachment

Use the `--file` flag with `atlassian_api.sh` — it handles the multipart upload automatically:

```bash
$SKILL_DIR/atlassian_api.sh --file /path/to/file.pdf POST '/rest/api/3/issue/CODE-123/attachments'
```

Response:

```json
[
  {
    "id": "10001",
    "filename": "file.pdf",
    "mimeType": "application/pdf",
    "size": 123456,
    "content": "https://yoursite.atlassian.net/rest/api/3/attachment/content/10001"
  }
]
```

### List Attachments

Attachments appear in `fields.attachment` when you GET an issue:

```json
{
  "attachment": [
    {
      "id": "10001",
      "filename": "screenshot.png",
      "mimeType": "image/png",
      "size": 54321,
      "content": "https://yoursite.atlassian.net/rest/api/3/attachment/content/10001",
      "created": "2026-04-01T10:00:00.000+0000",
      "author": { "displayName": "John Doe" }
    }
  ]
}
```

### Download Attachment

```bash
curl -s -L \
  -H "Authorization: Basic $(printf '%s:%s' "$ATLASSIAN_EMAIL" "$ATLASSIAN_API_TOKEN" | base64)" \
  -o /tmp/downloaded-file.pdf \
  "https://${ATLASSIAN_DOMAIN}/rest/api/3/attachment/content/10001"
```

### Delete Attachment

```http
DELETE /rest/api/3/attachment/{attachmentId}
```

## Bulk Operations

### Bulk Edit Issues

The REST API doesn't have a single bulk-edit endpoint. Instead, loop over issues:

```bash
# Bulk update labels on multiple issues
for KEY in CODE-101 CODE-102 CODE-103; do
  atlassian_api.sh PUT "/rest/api/3/issue/$KEY" '{"fields":{"labels":["reviewed"]}}'
done
```

### Bulk Transition Issues

```bash
# First get the transition ID
TRANSITION_ID=$(atlassian_api.sh GET '/rest/api/3/issue/CODE-101/transitions' | \
  python3 -c "import sys,json; ts=json.load(sys.stdin)['transitions']; print(next(t['id'] for t in ts if t['name']=='Done'))")

# Then transition multiple issues
for KEY in CODE-101 CODE-102 CODE-103; do
  atlassian_api.sh POST "/rest/api/3/issue/$KEY/transitions" "{\"transition\":{\"id\":\"$TRANSITION_ID\"}}"
done
```

### Bulk Create Issues

```http
POST /rest/api/3/issue/bulk
{
  "issueUpdates": [
    {
      "fields": {
        "project": { "key": "CODE" },
        "summary": "Task 1",
        "issuetype": { "name": "Task" }
      }
    },
    {
      "fields": {
        "project": { "key": "CODE" },
        "summary": "Task 2",
        "issuetype": { "name": "Task" }
      }
    }
  ]
}
```

Response:

```json
{
  "issues": [
    { "id": "10100", "key": "CODE-201", "self": "..." },
    { "id": "10101", "key": "CODE-202", "self": "..." }
  ],
  "errors": []
}
```

### Bulk Delete Issues

There is no bulk delete endpoint. Loop over issues:

```bash
for KEY in CODE-201 CODE-202; do
  atlassian_api.sh DELETE "/rest/api/3/issue/$KEY"
done
```
