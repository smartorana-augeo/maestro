---
name: grafana-logs
description: Query application logs from Grafana Cloud Loki via the datasource proxy API. Use this skill proactively whenever the user mentions checking logs, investigating errors, debugging production issues, tracing requests across services, or asking "why is the API failing" / "what's happening in PROD" / "are there any errors in staging". Also use when diagnosing 5xx responses, timeouts, or service outages for ambassador, nextweb, or any Structural project service.
---

# Grafana Logs

Query application logs from Grafana Cloud Loki via `query_logs.sh`. Use the script for all queries — do not construct manual curl commands.

## Execution Behavior

Read-only. **Execute all queries immediately without asking for confirmation.** Bash permissions are pre-configured in `settings.local.json`.

## Authentication

All requests use a Grafana service account token from `GRAFANA_TOKEN` (retrieve from 1Password: "Grafana claude-code-integration-readonly API Key").

**Setup** — add to the project `.env` file:

```bash
GRAFANA_TOKEN=<token from 1Password>
```

## Datasource Defaults

Primary: `grafanacloud-augeomarketing-logs` (ID: `7`). Pass `--ds <id>` to use another.

| ID  | Name                                           |
| --- | ---------------------------------------------- |
| 7   | grafanacloud-augeomarketing-logs               |
| 33  | awe-grafanacloud-augeomarketing-logs           |
| 45  | augeomarketing-xoom-lo                         |
| 29  | Cloud Logs: stack-1034310-hl-read-o11y-dev-poc |

## Available Labels

**Environments:** `DEV0`, `STAGING`, `SANDBOX`, `PROD`

**Levels:** `debug`, `info`, `warn`, `error`

> **Note:** `level` is not indexed in PROD. If no results, use `--json-filter 'log_level="error"'` or raw LogQL via `--query`: `{service_name="ambassador", environment="PROD"} | json | log_level="error"`

**Services:** `ambassador`, `ambassador-auth`, `nextweb`, `badges`, `atlas-replicator`, `pagebuilder`, `reporting-api-dev`, `reporting-api-stg`, `reporting-api-uat`

> This list may not be exhaustive. Run `--label-values service_name` to discover current services.

## Script Usage

```bash
bash .claude/skills/grafana-logs/scripts/query_logs.sh [OPTIONS]
```

| Flag                | Description                                                | Default |
| ------------------- | ---------------------------------------------------------- | ------- |
| `--service, -s`     | Service name                                               |         |
| `--env, -e`         | Environment                                                |         |
| `--level, -l`       | Log level                                                  |         |
| `--since, -t`       | Time range (`5m`, `1h`, `1d`)                              | `5m`    |
| `--limit, -n`       | Max log lines                                              | `25`    |
| `--filter, -f`      | Substring filter on log lines (`\|= "text"`)               |         |
| `--regex, -r`       | Regex filter on log lines (`\|~ "pattern"`)                |         |
| `--exclude, -x`     | Exclude lines containing text (repeatable)                 |         |
| `--json-filter, -j` | JSON field filter, e.g. `"status >= 500"` (repeatable)     |         |
| `--fields, -F`      | Comma-separated JSON fields to extract                     |         |
| `--max-width, -w`   | Truncate each output line to N chars                       |         |
| `--query, -q`       | Raw LogQL (bypasses `--service`/`--env`/`--level`)         |         |
| `--count, -c`       | Return count instead of lines                              |         |
| `--timestamps, -T`  | Show ISO 8601 timestamps on each line                      | on      |
| `--no-timestamps`   | Hide timestamps from output                                |         |
| `--json`            | Output results as a JSON array (for scripting/piping)      |         |
| `--dedup`           | Collapse consecutive duplicate log lines                   |         |
| `--show-labels`     | Prefix each line with stream labels                        |         |
| `--sort`            | Sort order: `asc` (oldest first) or `desc`                 | `desc`  |
| `--from`            | Absolute start time (ISO 8601, e.g. `2024-01-15T10:30:00`) |         |
| `--to`              | Absolute end time (ISO 8601); defaults to now              |         |
| `--labels`          | List all available Loki labels                             |         |
| `--label-values`    | List values for a label (e.g. `service_name`)              |         |
| `--ds`              | Datasource ID                                              | `7`     |

**Examples:**

```bash
# Errors in STAGING, last 5 minutes
bash .claude/skills/grafana-logs/scripts/query_logs.sh --service ambassador --env STAGING --level error --since 5m

# Count errors in PROD over last hour
bash .claude/skills/grafana-logs/scripts/query_logs.sh --service ambassador --env PROD --level error --since 1h --count

# Extract specific JSON fields only (reduces output tokens significantly)
bash .claude/skills/grafana-logs/scripts/query_logs.sh --service ambassador --env STAGING --since 15m --fields msg,level,status --max-width 200

# Exclude noisy lines (repeatable)
bash .claude/skills/grafana-logs/scripts/query_logs.sh --service ambassador --env PROD --level error --since 1h --exclude healthcheck --exclude ECONNRESET

# Filter on parsed JSON fields (e.g. HTTP 5xx responses)
bash .claude/skills/grafana-logs/scripts/query_logs.sh --service ambassador --env STAGING --since 15m --json-filter "status >= 500"

# Absolute time range for a specific incident window
bash .claude/skills/grafana-logs/scripts/query_logs.sh --service ambassador --env PROD --from 2024-01-15T10:30:00 --to 2024-01-15T11:00:00

# Discover available services
bash .claude/skills/grafana-logs/scripts/query_logs.sh --label-values service_name
```

## Error Context Extraction

When querying error-level logs without `--fields`, the formatter automatically extracts and displays structured error context below each log line:

- **Error message:** Extracted from `err`, `error`, `error_message`, `errorMessage` fields
- **Stack trace:** First 5 lines from `stack`, `stackTrace`, `stack_trace` fields
- **Request context:** HTTP method, URL/path, status code, duration

This triggers automatically for lines with error-level indicators (`error`, `fatal`, `critical`) or 5xx status codes. No extra flags needed.

## Investigation Strategy

Always investigate progressively to minimize token usage:

1. **Count first** — assess volume before fetching lines: `--count --since 1h`
2. **Sample** — understand shape with a small set: `--limit 10 --fields msg,level,status`
3. **Narrow** — add filters to focus: `--exclude healthcheck --filter "timeout"`
4. **Expand** — only if needed: increase `--limit` or widen `--since`
5. **Correlate** — check related services at the same time range using `--from`/`--to`

### Token-Saving Tips

- Use `--fields` for JSON-structured logs (ambassador, nextweb). Use `--max-width 300` when full log lines aren't needed.
- Use `--count` before fetching lines to gauge volume.
- Use `--dedup` when you expect many repeated error messages.
- Use `--exclude` to filter out known noise patterns (healthchecks, connection resets).
- Start with `--limit 10`, increase only if you need more context.
- Use `--json` when you need to pipe results to another tool.

## Cross-Service Investigation

When debugging issues that span multiple services, correlate logs using request IDs or timestamps.

**Pattern: Follow a request across services**

1. Find the error in the originating service and identify a correlation ID (request ID, trace ID, or user ID):

   ```bash
   bash .claude/skills/grafana-logs/scripts/query_logs.sh --service ambassador --env PROD --level error --since 15m --fields msg,request_id,status --limit 10
   ```

2. Search for that correlation ID in downstream services:

   ```bash
   bash .claude/skills/grafana-logs/scripts/query_logs.sh --service nextweb --env PROD --since 15m --filter "abc-123-request-id"
   ```

3. Use a narrow absolute time window around the error for precise correlation:
   ```bash
   bash .claude/skills/grafana-logs/scripts/query_logs.sh --service nextweb --env PROD --from 2024-01-15T10:29:00 --to 2024-01-15T10:31:00 --filter "abc-123-request-id"
   ```

**Example workflow: Ambassador 502 errors**

```bash
# Step 1: Find 502 errors in ambassador
bash .claude/skills/grafana-logs/scripts/query_logs.sh --service ambassador --env PROD --since 30m --json-filter "status = 502" --fields msg,request_id,upstream_service --limit 10

# Step 2: Check the upstream service for the same timeframe
bash .claude/skills/grafana-logs/scripts/query_logs.sh --service nextweb --env PROD --since 30m --level error --fields msg,request_id,status --limit 20

# Step 3: Correlate using a specific request ID
bash .claude/skills/grafana-logs/scripts/query_logs.sh --env PROD --since 30m --filter "abc-123-request-id" --fields msg,service_name,status
```

## LogQL Filter Operators (for `--filter` and `--query`)

| Operator      | Description          |
| ------------- | -------------------- |
| `\|= "text"`  | Contains substring   |
| `\|~ "regex"` | Matches regex        |
| `!= "text"`   | Does NOT contain     |
| `!~ "regex"`  | Does NOT match regex |

## Discovery

Use the script's built-in discovery flags to explore available labels and their values:

```bash
# List all available labels
bash .claude/skills/grafana-logs/scripts/query_logs.sh --labels

# List all service names
bash .claude/skills/grafana-logs/scripts/query_logs.sh --label-values service_name

# List all environments
bash .claude/skills/grafana-logs/scripts/query_logs.sh --label-values environment
```

## Troubleshooting

**Token expired / 401 errors**
Refresh the token from 1Password ("Grafana claude-code-integration-readonly API Key") and update `GRAFANA_TOKEN` in the project `.env` file.

**No results in PROD with `--level`**
The `level` label is not indexed in PROD. Use JSON pipeline filtering instead:

```bash
# Using --json-filter flag
bash .claude/skills/grafana-logs/scripts/query_logs.sh --service ambassador --env PROD --since 15m --json-filter 'log_level="error"'

# Using raw LogQL
bash .claude/skills/grafana-logs/scripts/query_logs.sh --query '{service_name="ambassador", environment="PROD"} | json | log_level="error"' --since 15m
```

**Empty results**

- Check service name spelling: `bash .claude/skills/grafana-logs/scripts/query_logs.sh --label-values service_name`
- Check environment spelling: `bash .claude/skills/grafana-logs/scripts/query_logs.sh --label-values environment`
- Try a broader time range with `--since 1h` or `--since 1d`
- Remove filters temporarily to confirm the stream has data

**Timeout / 504 errors**
Reduce the time range or add filters to narrow the query. Loki has query complexity limits:

- Use `--since 15m` instead of `--since 1d`
- Add `--filter` or `--exclude` to reduce scan volume
- Use `--count` first to gauge volume before fetching lines

**Rate limiting (429 errors)**
Wait 30-60 seconds and retry. To avoid rate limits, narrow queries with more specific selectors or shorter time ranges.

## Exit Codes

| Code | Meaning                                                            |
| ---- | ------------------------------------------------------------------ |
| `0`  | Success (query returned results, or label discovery completed)     |
| `1`  | Error (missing config, invalid arguments, API failure, or timeout) |

## Permissions

Entries in `.claude/settings.local.json` that allow this skill to run without approval:

```json
"Bash(curl *augeomarketing.grafana.net*)",
"Bash(python3 *format_output.py*)",
"Bash(python3 -c *)",
"Bash(python3 -m json.tool*)",
"Bash(bash .claude/skills/grafana-logs/*)",
"Bash(date *)"
```
