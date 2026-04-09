---
name: circle-ci
description: Investigate and manage CircleCI pipelines, workflows, and jobs via the CircleCI API v2. Use this skill proactively whenever the user mentions CI failures, build errors, pipeline status, or asks "why did the build fail" / "is CI passing" / "rerun the tests" / "check the pipeline". Also use when fetching test results, job artifacts, or flaky test reports for ambassador, nextweb, or any Structural project.
---

# CircleCI

Investigate and manage CircleCI pipelines, workflows, and jobs via `circleci.sh`. Use the script for all operations — do not construct manual curl commands.

## Execution Behavior

Read-only subcommands (`failed`, `jobs`, `tests`, `artifacts`, `pipelines`, `workflows`, `flaky`) execute immediately without confirmation. Mutation subcommands (`rerun`, `cancel`) affect live CI state — confirm intent with the user before running.

## Authentication

All requests require a CircleCI personal API token. Always create tokens with an expiration date.

**Token sources (priority order):**

1. `CIRCLECI_TOKEN` environment variable
2. Project `.env` file — auto-loaded by the script
3. `~/.circleci/cli.yml` — stored by the `circleci setup` CLI command

**Setup** — add to the project `.env` file:

```bash
CIRCLECI_TOKEN=<your token>
```

Generate at: https://app.circleci.com/settings/user/tokens → Create New Token (with expiration).

## Project Defaults

Default project slug: `gh/Structuralapp/ambassador`

Pass `--project SLUG` to any subcommand to target a different project.

## Script Usage

```bash
bash .claude/skills/circle-ci/scripts/circleci.sh <subcommand> [OPTIONS]
```

| Subcommand  | Description                          | Key Flags                                                   |
| ----------- | ------------------------------------ | ----------------------------------------------------------- |
| `failed`    | Find most recent failed workflow     | `[--project SLUG] [--branch NAME] [--details]`              |
| `workflows` | List workflows for a pipeline        | `--pipeline ID`                                             |
| `jobs`      | List jobs in a workflow              | `--workflow ID [--failed-only]`                             |
| `tests`     | Get test results for a job           | `--job NUMBER [--project SLUG] [--failed-only]`             |
| `artifacts` | Get job artifacts                    | `--job NUMBER [--project SLUG] [--download URL] [--output]` |
| `rerun`     | Rerun a workflow ⚠ mutation          | `--workflow ID [--from-failed]`                             |
| `cancel`    | Cancel a running workflow ⚠ mutation | `--workflow ID`                                             |
| `pipelines` | List recent pipelines                | `[--project SLUG] [--branch NAME] [--limit N]`              |
| `flaky`     | Get flaky tests                      | `[--project SLUG]`                                          |

Run `circleci.sh <subcommand> --help` for full flag details.

## Examples

```bash
# Find most recent failure (auto-detects current branch)
bash .claude/skills/circle-ci/scripts/circleci.sh failed

# Find failure on a specific branch with job details
bash .claude/skills/circle-ci/scripts/circleci.sh failed --branch main --details

# List workflows for a pipeline (pipeline → workflow IDs)
bash .claude/skills/circle-ci/scripts/circleci.sh workflows --pipeline <pipeline-id>

# List all jobs in a workflow
bash .claude/skills/circle-ci/scripts/circleci.sh jobs --workflow <workflow-id>

# List only failed jobs in a workflow
bash .claude/skills/circle-ci/scripts/circleci.sh jobs --workflow <workflow-id> --failed-only

# Get test results for a failed job (shows failure messages)
bash .claude/skills/circle-ci/scripts/circleci.sh tests --job <job-number> --failed-only

# Get artifacts for a job
bash .claude/skills/circle-ci/scripts/circleci.sh artifacts --job <job-number>

# Rerun a workflow from failed jobs only (confirm with user first)
bash .claude/skills/circle-ci/scripts/circleci.sh rerun --workflow <workflow-id> --from-failed

# List pipelines on current branch (auto-detected)
bash .claude/skills/circle-ci/scripts/circleci.sh pipelines

# Check for flaky tests
bash .claude/skills/circle-ci/scripts/circleci.sh flaky
```

## Investigation Strategy

Work progressively to keep context usage low:

1. **Find failure** — `failed --details` gets pipeline, workflow ID, and failed job names in one call
2. **Get test results** — `tests --job <num> --failed-only` shows exactly which tests failed and why
3. **Check a specific branch** — `pipelines --branch <name>` → `workflows --pipeline <id>` → `jobs --workflow <id>`
4. **Get artifacts** — `artifacts --job <num>` lists test reports and logs
5. **Rerun** — `rerun --workflow <id> --from-failed` to retry only failed jobs (confirm first)

## Discovery

For full endpoint documentation and response schemas, see `references/circleci-api-v2-endpoints.md`.

## Troubleshooting

**401 Unauthorized**
Token expired or invalid. Generate a new one at https://app.circleci.com/settings/user/tokens (always set an expiration). Update `CIRCLECI_TOKEN` in the project `.env` file.

**404 Not Found**
Wrong project slug format. Must be `gh/org/repo` (e.g., `gh/Structuralapp/ambassador`). Verify the org and repo name match exactly.

**429 Rate Limited**
Too many API requests. Wait 30-60 seconds and retry. When iterating over many pipelines/workflows, add delays between calls.

**Empty results from `failed`**
Recent pipelines on the current branch may all be passing. Try `failed --branch main` to check the default branch, or `pipelines` to see recent pipeline statuses.

**Connection timeout**
The script uses a 30-second timeout on all API calls. If CircleCI is slow, retry the command. For persistent timeouts, check https://status.circleci.com/.

## Exit Codes

| Code | Meaning                                             |
| ---- | --------------------------------------------------- |
| `0`  | Success                                             |
| `1`  | Error (API failure, missing args, or invalid input) |

## Permissions

Entries in `.claude/settings.local.json` that allow this skill to run without approval:

```json
"Bash(bash .claude/skills/circle-ci/*)",
"Bash(curl *circleci.com*)"
```
