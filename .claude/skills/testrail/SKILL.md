---
name: testrail
description: >-
  Interact with the TestRail API to browse projects, test suites, sections, and
  test cases, and to create new suites, sections, and cases. Use this skill
  proactively whenever the user mentions TestRail, test suites, test cases,
  test sections, regression testing, or wants to browse or create testing
  content. Also trigger when the user references specific projects (Heaps, V5,
  V10, Encore, Intride, Incentives Platform, AWE), asks "how many tests are in
  X", "find test cases for Y", "create a test suite", or needs to organize
  testing content — even if they don't explicitly say "TestRail".
---

# TestRail

Browse and manage TestRail projects, suites, sections, and test cases via `testrail.sh`.

## Execution Behavior

Read-only subcommands (`projects`, `suites`, `sections`, `cases`, `get-case`, `get-section`) execute immediately.

Mutations follow these rules:

- **NEVER execute:** `delete_project`, `delete_suite` — not permitted regardless of user instruction.
- **Require explicit confirmation:** `delete-section` (also deletes all child cases), `delete-case` — both require the `--confirm` flag. State what will be permanently deleted and that it cannot be undone.
- **Soft warning:** `update-case`, `update-section`, `add-suite` — confirm the target resource ID before executing.

## Authentication

Three env vars required — add to the project `.env` file:

```bash
TESTRAIL_EMAIL=<your email>
TESTRAIL_API_KEY=<API token from TestRail>
TESTRAIL_DOMAIN=augeo.testrail.io
```

## Script Usage

```bash
.claude/skills/testrail/scripts/testrail.sh <subcommand> [OPTIONS]
```

| Subcommand       | Options                                                           | Type      |
| ---------------- | ----------------------------------------------------------------- | --------- |
| `projects`       |                                                                   | read-only |
| `suites`         | `--project ID`                                                    | read-only |
| `sections`       | `--project ID --suite ID`                                         | read-only |
| `cases`          | `--project ID --suite ID [--section ID] [--limit N] [--offset N]` | read-only |
| `get-case`       | `--case ID`                                                       | read-only |
| `get-section`    | `--section ID`                                                    | read-only |
| `add-case`       | `--section ID --title "Title" [--refs TICKET-123] [--json FILE]`  | mutation  |
| `add-section`    | `--project ID --suite ID --name "Name" [--parent ID]`             | mutation  |
| `add-suite`      | `--project ID --name "Name"`                                      | mutation  |
| `update-case`    | `--case ID --json PAYLOAD_FILE`                                   | mutation  |
| `update-section` | `--section ID --name "Name"`                                      | mutation  |
| `delete-case`    | `--case ID --confirm`                                             | mutation  |
| `delete-section` | `--section ID --confirm`                                          | mutation  |

## Known Projects

| ID  | Name                |
| --- | ------------------- |
| 1   | Heaps               |
| 2   | V5                  |
| 3   | V10                 |
| 4   | Encore              |
| 5   | Intride             |
| 6   | Incentives Platform |
| 7   | AWE                 |

## Hierarchy

**Project → Suite → Section → Test Case**

## Investigation Strategy

Work progressively from broad to specific:

1. **List projects** — `projects` (or use Known Projects table above)
2. **Get suites** — `suites --project 7` to find the suite ID
3. **Get sections** — `sections --project 7 --suite <ID>` to find the section
4. **List cases** — `cases --project 7 --suite <ID>` (add `--section <ID>` to narrow)
5. **Inspect a case** — `get-case --case <ID>` for full details including steps and refs
6. **Create/update** — use mutation subcommands after confirming target IDs

### Token-Saving Tips

- Use `--limit 50` to reduce response size when browsing large suites
- Use `--section` to scope case listing to a specific section
- For bulk case creation, prepare a JSON file with full payload and use `--json FILE`

## Examples

```bash
# List all projects
.claude/skills/testrail/scripts/testrail.sh projects

# List suites for AWE (project 7)
.claude/skills/testrail/scripts/testrail.sh suites --project 7

# List sections in a suite
.claude/skills/testrail/scripts/testrail.sh sections --project 7 --suite 4812

# List cases (first 50)
.claude/skills/testrail/scripts/testrail.sh cases --project 7 --suite 4812 --limit 50

# Get page 2 of cases
.claude/skills/testrail/scripts/testrail.sh cases --project 7 --suite 4812 --limit 250 --offset 250

# Create a simple case
.claude/skills/testrail/scripts/testrail.sh add-case --section 12345 --title "Verify login" --refs CODE-7707

# Create a case with full payload (steps, preconditions, etc.)
.claude/skills/testrail/scripts/testrail.sh add-case --section 12345 --json /tmp/case_payload.json

# Update a case
.claude/skills/testrail/scripts/testrail.sh update-case --case 99999 --json /tmp/update.json

# Delete a case (requires --confirm)
.claude/skills/testrail/scripts/testrail.sh delete-case --case 99999 --confirm
```

### JSON Payload Example

For `--json` flag, create a file like `/tmp/case_payload.json`:

```json
{
  "title": "Verify user login with valid credentials",
  "refs": "CODE-7707",
  "custom_preconds": "User has a valid account",
  "custom_steps_separated": [
    {
      "content": "Navigate to login page",
      "expected": "Login form is displayed"
    },
    {
      "content": "Enter valid credentials and submit",
      "expected": "User is redirected to dashboard"
    }
  ],
  "priority_id": 2
}
```

Note: Fields prefixed `custom_` are TestRail custom fields specific to our instance. Standard fields (`title`, `refs`, `priority_id`, `type_id`, `estimate`) are universal.

## Pagination

List endpoints return max 250 results per page. Use `--limit` and `--offset` to paginate:

- Page 1: `--limit 250 --offset 0` (default)
- Page 2: `--limit 250 --offset 250`
- Page 3: `--limit 250 --offset 500`

The script shows pagination info (e.g., "more available") when there are additional pages.

## Troubleshooting

- **`401 Unauthorized`** — check `.env` credentials; API token may have expired
- **`403 Forbidden`** — your API key lacks permissions for this operation (common with delete)
- **`404 Not Found`** — verify the project/suite/section/case ID is correct
- **`400 Bad Request`** — malformed JSON payload; check field names and types
- **`429 Too Many Requests`** — rate limited; wait a moment and retry
- **Network timeout** — API calls timeout after 30s; check connectivity or retry
- **Empty results** — verify the suite has cases; check `--project` and `--suite` IDs match

## Exit Codes

| Code | Meaning                                              |
| ---- | ---------------------------------------------------- |
| `0`  | Success                                              |
| `1`  | Error (API failure, missing args, or missing config) |

## Discovery

For the complete endpoint reference, payload field details, and response schemas, see `references/api.md`.

## Permissions

Entries in `.claude/settings.local.json` that allow this skill to run without approval:

```json
"Bash(bash .claude/skills/testrail/*)",
"Bash(.claude/skills/testrail/scripts/testrail.sh *)"
```
