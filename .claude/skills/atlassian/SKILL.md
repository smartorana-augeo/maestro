---
name: atlassian
description: >-
  Full Atlassian API integration for Jira, Confluence, JSM, and Compass — use as a
  fallback when the claude.ai Atlassian connector is not available. Use this skill
  proactively whenever the user mentions
  Jira issues, Confluence pages, sprints, backlogs, JQL queries, CQL searches, issue
  transitions, Confluence spaces, page comments, JSM alerts, on-call schedules, Compass
  components, or any Atlassian product interaction. Also trigger for phrases like "check
  the ticket", "update the issue", "create a page", "search Confluence", "who's on call",
  "find issues assigned to me", "link issues", "attach file", "board", "kanban",
  "scrum board", "epic", "on call", "alert", "incident", "sprint report", "velocity",
  "worklog", "log time", "label", "component", "fix version", "story points",
  "custom field", "bulk create", "bulk edit", "bulk transition", "page tree",
  "child pages", "descendants", or any Jira issue key pattern (e.g. CODE-1234, PROJ-567).
  Covers all Atlassian operations via REST API — requires ATLASSIAN_EMAIL, ATLASSIAN_API_TOKEN,
  and ATLASSIAN_DOMAIN in the project .env file.
---

# Atlassian API Skill

Direct REST API integration with Jira, Confluence, JSM Ops, and Compass. Uses
Basic Auth (email + API token) — no OAuth flow needed.

## Authentication

Three env vars are required (loaded automatically from the project `.env` file):

| Variable              | Description                     | Example                     |
| --------------------- | ------------------------------- | --------------------------- |
| `ATLASSIAN_EMAIL`     | Your Atlassian account email    | `user@company.com`          |
| `ATLASSIAN_API_TOKEN` | API token from id.atlassian.com | `ATATT3x...`                |
| `ATLASSIAN_DOMAIN`    | Your Atlassian cloud site       | `yourcompany.atlassian.net` |

Generate tokens at: https://id.atlassian.com/manage-profile/security/api-tokens

## How to Use This Skill

All API calls go through the helper script. Set a variable once so examples are easy to run:

```bash
SKILL_DIR=$(d=$(pwd); while [ "$d" != "/" ]; do [ -d "$d/.claude/skills/atlassian/scripts" ] && echo "$d/.claude/skills/atlassian/scripts" && break; d=$(dirname "$d"); done)
$SKILL_DIR/atlassian_api.sh <method> <path> [json-body]
```

- `method`: GET, POST, PUT, PATCH, DELETE
- `path`: API path after the base URL (e.g. `/rest/api/3/issue/CODE-123`)
- `json-body`: optional JSON string for POST/PUT/PATCH requests

The script handles auth, headers, error reporting, and `.env` loading automatically.
It prints raw JSON to stdout — use the helper scripts below to get concise output.

The `SKILL_DIR` command walks up from the current directory until it finds `.claude/skills/atlassian/scripts/`, so it works from any subdirectory of the maestro repo (e.g. `repositories/some-repo/`).

## Helper Scripts

### Parse ADF to Text

Jira descriptions and comments come back as verbose ADF JSON. Convert to readable text:

```bash
$SKILL_DIR/atlassian_api.sh GET '/rest/api/3/issue/CODE-123' | python3 $SKILL_DIR/parse_adf.py
# For a specific field:
$SKILL_DIR/atlassian_api.sh GET '/rest/api/3/issue/CODE-123' | python3 $SKILL_DIR/parse_adf.py --field description
# For all comments on an issue:
$SKILL_DIR/atlassian_api.sh GET '/rest/api/3/issue/CODE-123' | python3 $SKILL_DIR/parse_adf.py --field comment
```

### Format Responses

Reduce verbose JSON to essential fields. Choose the formatter that matches your API call:

| Formatter           | Use with                                    |
| ------------------- | ------------------------------------------- |
| `issue`             | Single issue GET (`/rest/api/3/issue/KEY`)  |
| `search`            | JQL search results, sprint issues, backlogs |
| `projects`          | Project list (`/rest/api/3/project/search`) |
| `transitions`       | Issue transitions                           |
| `users`             | User search results                         |
| `confluence-search` | Confluence CQL search results               |
| `confluence-page`   | Single Confluence page GET (with body)      |
| `spaces`            | Confluence spaces list                      |
| `boards`            | Agile board list                            |
| `alerts`            | JSM Ops alert search results                |
| `schedules`         | JSM Ops schedule list                       |
| `teams`             | JSM Ops team list                           |

```bash
# Issue details
$SKILL_DIR/atlassian_api.sh GET '/rest/api/3/issue/CODE-123' | python3 $SKILL_DIR/format_response.py issue

# Search results
$SKILL_DIR/atlassian_api.sh GET '/rest/api/3/search/jql?jql=...' | python3 $SKILL_DIR/format_response.py search

# Confluence page
$SKILL_DIR/atlassian_api.sh GET '/wiki/api/v2/pages/12345?body-format=storage' | python3 $SKILL_DIR/format_response.py confluence-page
```

## Creating Issues: Discover Required Fields First

Projects often have custom required fields that cause creation to fail with 400 errors.
Always check what fields are required before creating:

```bash
# Step 1: Get available issue types for the project
$SKILL_DIR/atlassian_api.sh GET '/rest/api/3/issue/createmeta/CODE/issuetypes'

# Step 2: Get required fields for a specific issue type (use the ID from step 1)
$SKILL_DIR/atlassian_api.sh GET '/rest/api/3/issue/createmeta/CODE/issuetypes/10001'

# Step 3: Create with all required fields populated
$SKILL_DIR/atlassian_api.sh POST '/rest/api/3/issue' '{"fields":{...all required fields...}}'
```

This two-step discovery is essential — skipping it is the most common cause of creation failures.

## Quick Reference: Common Operations

### Jira

| Operation           | Command                                                                                                                                                                                                           |
| ------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Get issue           | `$SKILL_DIR/atlassian_api.sh GET '/rest/api/3/issue/CODE-123'`                                                                                                                                                    |
| Search (JQL)        | `$SKILL_DIR/atlassian_api.sh GET '/rest/api/3/search/jql?jql=assignee=currentUser()+ORDER+BY+updated+DESC&maxResults=10'`                                                                                         |
| Create issue        | `$SKILL_DIR/atlassian_api.sh POST '/rest/api/3/issue' '{"fields":{"project":{"key":"CODE"},"summary":"Title","issuetype":{"name":"Task"}}}'`                                                                      |
| Edit issue          | `$SKILL_DIR/atlassian_api.sh PUT '/rest/api/3/issue/CODE-123' '{"fields":{"summary":"New title"}}'`                                                                                                               |
| Add comment         | `$SKILL_DIR/atlassian_api.sh POST '/rest/api/3/issue/CODE-123/comment' '{"body":{"type":"doc","version":1,"content":[{"type":"paragraph","content":[{"type":"text","text":"Comment text"}]}]}}'`                  |
| Transition issue    | First get transitions: `$SKILL_DIR/atlassian_api.sh GET '/rest/api/3/issue/CODE-123/transitions'`, then: `$SKILL_DIR/atlassian_api.sh POST '/rest/api/3/issue/CODE-123/transitions' '{"transition":{"id":"31"}}'` |
| Add worklog         | `$SKILL_DIR/atlassian_api.sh POST '/rest/api/3/issue/CODE-123/worklog' '{"timeSpentSeconds":3600,"started":"2026-04-03T09:00:00.000+0000"}'`                                                                      |
| List projects       | `$SKILL_DIR/atlassian_api.sh GET '/rest/api/3/project/search'`                                                                                                                                                    |
| Issue type metadata | `$SKILL_DIR/atlassian_api.sh GET '/rest/api/3/issue/createmeta/CODE/issuetypes'`                                                                                                                                  |
| Issue type fields   | `$SKILL_DIR/atlassian_api.sh GET '/rest/api/3/issue/createmeta/CODE/issuetypes/10001'`                                                                                                                            |
| Lookup user         | `$SKILL_DIR/atlassian_api.sh GET '/rest/api/3/user/search?query=john.doe'`                                                                                                                                        |
| Remote links        | `$SKILL_DIR/atlassian_api.sh GET '/rest/api/3/issue/CODE-123/remotelink'`                                                                                                                                         |
| Link issues         | `$SKILL_DIR/atlassian_api.sh POST '/rest/api/3/issueLink' '{"type":{"name":"Blocks"},"inwardIssue":{"key":"CODE-124"},"outwardIssue":{"key":"CODE-123"}}'`                                                        |
| Issue link types    | `$SKILL_DIR/atlassian_api.sh GET '/rest/api/3/issueLinkType'`                                                                                                                                                     |
| Add attachment      | `$SKILL_DIR/atlassian_api.sh --file /path/to/file POST '/rest/api/3/issue/CODE-123/attachments'`                                                                                                                  |
| Bulk create         | `$SKILL_DIR/atlassian_api.sh POST '/rest/api/3/issue/bulk' '{"issueUpdates":[{"fields":{...}},{"fields":{...}}]}'`                                                                                                |

### Jira Agile (Sprints & Boards)

| Operation      | Command                                                                                                                                       |
| -------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| List boards    | `$SKILL_DIR/atlassian_api.sh GET '/rest/agile/1.0/board?projectKeyOrId=CODE&type=scrum'`                                                      |
| Active sprints | `$SKILL_DIR/atlassian_api.sh GET '/rest/agile/1.0/board/42/sprint?state=active'`                                                              |
| Sprint issues  | `$SKILL_DIR/atlassian_api.sh GET '/rest/agile/1.0/sprint/123/issue?fields=summary,status,assignee'`                                           |
| Backlog issues | `$SKILL_DIR/atlassian_api.sh GET '/rest/agile/1.0/board/42/backlog?fields=summary,status'`                                                    |
| Move to sprint | `$SKILL_DIR/atlassian_api.sh POST '/rest/agile/1.0/sprint/123/issue' '{"issues":["CODE-101","CODE-102"]}'`                                    |
| Epic issues    | `$SKILL_DIR/atlassian_api.sh GET '/rest/agile/1.0/epic/CODE-50/issue?fields=summary,status'`                                                  |
| Sprint report  | `$SKILL_DIR/atlassian_api.sh GET '/rest/agile/1.0/board/42/sprint/123/report'` (pipe through `python3 -m json.tool` — no formatter available) |

### Confluence

**Note:** All Confluence paths require the `/wiki` prefix (unlike Jira which sits at the domain root).
Endpoints that take a `spaceId` need the numeric ID — get it from "List spaces" first.

| Operation             | Command                                                                                                                                                                                                          |
| --------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Get page (by ID)      | `$SKILL_DIR/atlassian_api.sh GET '/wiki/api/v2/pages/12345?body-format=storage'`                                                                                                                                 |
| List spaces           | `$SKILL_DIR/atlassian_api.sh GET '/wiki/api/v2/spaces?limit=25'`                                                                                                                                                 |
| Pages in space        | `$SKILL_DIR/atlassian_api.sh GET '/wiki/api/v2/spaces/123456/pages?limit=25'`                                                                                                                                    |
| Search (CQL)          | `$SKILL_DIR/atlassian_api.sh GET '/wiki/rest/api/content/search?cql=type=page+AND+space=PD+AND+title~"search+term"&limit=10'`                                                                                    |
| Create page           | `$SKILL_DIR/atlassian_api.sh POST '/wiki/api/v2/pages' '{"spaceId":"123456","status":"current","title":"Page Title","parentId":"789","body":{"representation":"storage","value":"<p>Content here</p>"}}'`        |
| Update page           | `$SKILL_DIR/atlassian_api.sh PUT '/wiki/api/v2/pages/12345' '{"id":"12345","status":"current","title":"Updated Title","body":{"representation":"storage","value":"<p>New content</p>"},"version":{"number":2}}'` |
| Page descendants      | `$SKILL_DIR/atlassian_api.sh GET '/wiki/api/v2/pages/12345/children?limit=25'`                                                                                                                                   |
| Footer comments       | `$SKILL_DIR/atlassian_api.sh GET '/wiki/api/v2/pages/12345/footer-comments?limit=25'`                                                                                                                            |
| Create footer comment | `$SKILL_DIR/atlassian_api.sh POST '/wiki/api/v2/pages/12345/footer-comments' '{"body":{"representation":"storage","value":"<p>Comment</p>"}}'`                                                                   |
| Inline comments       | `$SKILL_DIR/atlassian_api.sh GET '/wiki/api/v2/pages/12345/inline-comments?limit=25'`                                                                                                                            |
| Create inline comment | `$SKILL_DIR/atlassian_api.sh POST '/wiki/api/v2/pages/12345/inline-comments' '{"body":{"representation":"storage","value":"<p>Note</p>"},"inlineCommentProperties":{"textSelection":"selected text"}}'`          |
| Comment children      | `$SKILL_DIR/atlassian_api.sh GET '/wiki/api/v2/footer-comments/COMMENT-ID/children?limit=25'`                                                                                                                    |

### JSM Ops (Jira Service Management)

| Operation              | Command                                                                                                                               |
| ---------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| Get alert by ID        | `$SKILL_DIR/atlassian_api.sh GET '/jsm/ops/api/v1/alerts/ALERT-ID'`                                                                   |
| Search alerts          | `$SKILL_DIR/atlassian_api.sh GET '/jsm/ops/api/v1/alerts?query=status:open&limit=10' \| python3 $SKILL_DIR/format_response.py alerts` |
| Acknowledge alert      | `$SKILL_DIR/atlassian_api.sh POST '/jsm/ops/api/v1/alerts/ALERT-ID/acknowledge' '{}'`                                                 |
| Close alert            | `$SKILL_DIR/atlassian_api.sh POST '/jsm/ops/api/v1/alerts/ALERT-ID/close' '{}'`                                                       |
| List on-call schedules | `$SKILL_DIR/atlassian_api.sh GET '/jsm/ops/api/v1/schedules' \| python3 $SKILL_DIR/format_response.py schedules`                      |
| Who's on call          | `$SKILL_DIR/atlassian_api.sh GET '/jsm/ops/api/v1/schedules/SCHEDULE-ID/on-calls'`                                                    |
| List teams             | `$SKILL_DIR/atlassian_api.sh GET '/jsm/ops/api/v1/teams' \| python3 $SKILL_DIR/format_response.py teams`                              |
| Get team details       | `$SKILL_DIR/atlassian_api.sh GET '/jsm/ops/api/v1/teams/TEAM-ID'`                                                                     |

### Compass (GraphQL)

Compass uses GraphQL via `POST /gateway/api/graphql`. You need the `cloudId` first:

```bash
$SKILL_DIR/atlassian_api.sh GET '/_edge/tenant_info'
# Returns: {"cloudId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx", ...}
```

Then query components:

```bash
$SKILL_DIR/atlassian_api.sh POST '/gateway/api/graphql' '{
  "query": "query { compass { searchComponents(cloudId: \"YOUR-CLOUD-ID\", query: { query: \"search term\", first: 25 }) { nodes { id name type description } } } }"
}'
```

For the full set of Compass queries (components, relationships, custom fields, events), read `references/compass.md`.

### Platform / User Info

| Operation    | Command                                                    |
| ------------ | ---------------------------------------------------------- |
| Current user | `$SKILL_DIR/atlassian_api.sh GET '/rest/api/3/myself'`     |
| Server info  | `$SKILL_DIR/atlassian_api.sh GET '/rest/api/3/serverInfo'` |

## Important Patterns

### JQL Encoding

Always use Python to URL-encode JQL queries — manual encoding is error-prone:

```bash
JQL=$(python3 -c "import urllib.parse; print(urllib.parse.quote('assignee = currentUser() AND status != Done ORDER BY updated DESC'))")
$SKILL_DIR/atlassian_api.sh GET "/rest/api/3/search/jql?jql=$JQL&maxResults=20"
```

### CQL Encoding

Same approach for Confluence CQL:

```bash
CQL=$(python3 -c "import urllib.parse; print(urllib.parse.quote('type=page AND space=PD AND title~\"release plan\"'))")
$SKILL_DIR/atlassian_api.sh GET "/wiki/rest/api/content/search?cql=$CQL&limit=10"
```

### Pagination

Most endpoints support `startAt` (Jira) or `cursor` (Confluence v2) for pagination:

- Jira: `?startAt=0&maxResults=50` — check `total` in response
- Confluence v2: check `_links.next` in response for the next page URL

### Atlassian Document Format (ADF)

Jira uses ADF for rich text fields (description, comments). Minimal example:

```json
{
  "type": "doc",
  "version": 1,
  "content": [
    {
      "type": "paragraph",
      "content": [{ "type": "text", "text": "Hello world" }]
    }
  ]
}
```

For details on ADF nodes (headings, lists, code blocks, mentions, etc.), see `references/jira.md`.

### Confluence Storage Format

Confluence pages use XHTML storage format:

```html
<p>Paragraph text</p>
<h2>Heading</h2>
<ul>
  <li>List item</li>
</ul>
<ac:structured-macro ac:name="code"
  ><ac:plain-text-body
    ><![CDATA[code here]]></ac:plain-text-body
  ></ac:structured-macro
>
```

For the full storage format reference, see `references/confluence.md`.

### Custom Fields

Story points use `customfield_10016` in most Jira Cloud instances, but this ID varies by instance.
If story points don't appear in responses, discover the correct field ID:

```bash
$SKILL_DIR/atlassian_api.sh GET '/rest/api/3/field' | python3 -c "
import sys, json
fields = json.load(sys.stdin)
for f in fields:
    if 'story' in f.get('name','').lower() or 'point' in f.get('name','').lower():
        print(f\"{f['id']:30s} {f['name']}\")
"
```

## Response Handling

The API script outputs raw JSON. For large responses, pipe through formatting:

```bash
# Pretty print
$SKILL_DIR/atlassian_api.sh GET '/rest/api/3/issue/CODE-123' | python3 -m json.tool

# Extract specific fields with Python
$SKILL_DIR/atlassian_api.sh GET '/rest/api/3/search/jql?jql=project=CODE&maxResults=5' | \
  python3 -c "import sys,json; data=json.load(sys.stdin); [print(f\"{i['key']}: {i['fields']['summary']}\") for i in data['issues']]"
```

## Error Handling

The script exits non-zero on failure and prints the HTTP status + response body to stderr.
Common errors:

| Status | Meaning         | Fix                                                         |
| ------ | --------------- | ----------------------------------------------------------- |
| 401    | Bad credentials | Check `ATLASSIAN_EMAIL` and `ATLASSIAN_API_TOKEN` in `.env` |
| 403    | No permission   | Your token lacks access to this resource                    |
| 404    | Not found       | Check the issue key, page ID, or API path                   |
| 429    | Rate limited    | Wait 5–10 seconds and retry; Jira allows ~100 req/min       |

For bulk operations (loops over many issues), add a short delay between requests to avoid 429s:

```bash
for KEY in CODE-101 CODE-102 CODE-103; do
  $SKILL_DIR/atlassian_api.sh PUT "/rest/api/3/issue/$KEY" '{"fields":{"labels":["reviewed"]}}'
  sleep 1
done
```

## When to Read Reference Files

The quick-reference tables above cover the most common operations. Read a reference file when you
need something not covered inline — advanced options, full response schemas, or uncommon operations:

| Read this…                 | When you need…                                                           |
| -------------------------- | ------------------------------------------------------------------------ |
| `references/jira.md`       | ADF node details, issue links, attachments, bulk ops, custom fields      |
| `references/agile.md`      | Sprint create/close, ranking, epic management, velocity reports          |
| `references/confluence.md` | Storage format macros, inline comments, CQL patterns, pagination details |
| `references/jsm-ops.md`    | Alert escalation, schedule rotations, team routing rules                 |
| `references/compass.md`    | Full GraphQL queries, relationships, custom field definitions, events    |

For straightforward operations (get issue, search, create, transition), the inline tables are sufficient — don't read the references unless the task requires deeper detail.
