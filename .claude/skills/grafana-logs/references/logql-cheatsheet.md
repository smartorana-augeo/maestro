# LogQL Quick Reference

LogQL is Loki's query language, similar to PromQL but for logs.

## Stream Selectors

Select log streams by label matchers inside `{}`:

```
{service_name="ambassador"}
{service_name="ambassador", environment="STAGING"}
{service_name="ambassador", environment="STAGING", level="error"}
```

Label match operators:

| Operator | Description     |
| -------- | --------------- |
| `=`      | Equals          |
| `!=`     | Not equals      |
| `=~`     | Regex match     |
| `!~`     | Regex not match |

```
{service_name=~"ambassador|nextweb"}
{environment!="PROD"}
```

## Line Filters

Filter log lines after stream selection:

| Operator      | Description          | Example             |
| ------------- | -------------------- | ------------------- |
| `\|= "text"`  | Contains substring   | `\|= "error"`       |
| `!= "text"`   | Does NOT contain     | `!= "healthcheck"`  |
| `\|~ "regex"` | Matches regex        | `\|~ "(?i)timeout"` |
| `!~ "regex"`  | Does NOT match regex | `!~ "GET /health"`  |

Chain multiple filters:

```
{service_name="ambassador"} |= "error" != "healthcheck" != "ECONNRESET"
```

## JSON Parsing

Parse JSON log lines and filter on extracted fields:

```
{service_name="ambassador"} | json
{service_name="ambassador"} | json | status >= 500
{service_name="ambassador"} | json | method="POST"
{service_name="ambassador"} | json | duration > 5000
```

Extract specific fields from nested JSON:

```
{service_name="ambassador"} | json | json error_details="error.details"
```

Format output from parsed fields:

```
{service_name="ambassador"} | json | line_format "{{.ts}} {{.level}} {{.msg}}"
```

## Label Extraction

Extract labels from log content:

```
# Extract from regex capture groups
{service_name="ambassador"} | regexp `status=(?P<status>\d+)`

# Extract from logfmt-formatted lines
{service_name="ambassador"} | logfmt

# Extract from JSON, then use as labels
{service_name="ambassador"} | json | label_format status_code=status
```

## Metric Queries

Aggregate log data into numeric values:

```
# Count lines over time window
count_over_time({service_name="ambassador", level="error"} [5m])

# Rate of lines per second
rate({service_name="ambassador", level="error"} [5m])

# Bytes rate
bytes_rate({service_name="ambassador"} [5m])

# Sum by label
sum by (level) (count_over_time({service_name="ambassador"} [1h]))

# Top services by error count
topk(5, sum by (service_name) (count_over_time({level="error"} [1h])))

# Error rate as percentage
sum(rate({service_name="ambassador", level="error"} [5m]))
  /
sum(rate({service_name="ambassador"} [5m]))
  * 100
```

## Unwrap (Numeric Extraction)

Extract numeric values from log lines for aggregation:

```
# Average response time from JSON logs
avg_over_time({service_name="ambassador"} | json | unwrap duration [5m])

# 95th percentile response time
quantile_over_time(0.95, {service_name="ambassador"} | json | unwrap duration [5m])

# Max response time by service
max_over_time({service_name="ambassador"} | json | unwrap duration [5m]) by (service_name)
```

## Useful Patterns

### Errors excluding noise

```
{service_name="ambassador", environment="PROD", level="error"} != "ECONNRESET" != "healthcheck"
```

### HTTP 5xx responses

```
{service_name="ambassador", environment="STAGING"} | json | status >= 500
```

### Slow requests (>5s)

```
{service_name="ambassador"} | json | duration > 5000
```

### Case-insensitive search

```
{service_name="ambassador"} |~ "(?i)unauthorized"
```

### Multiple services

```
{service_name=~"ambassador|nextweb", environment="STAGING", level="error"}
```

### POST requests only

```
{service_name="ambassador"} | json | method="POST"
```

### Specific URL path pattern

```
{service_name="ambassador"} | json | path=~"/api/v[12]/users.*"
```

### Errors with stack traces

```
{service_name="ambassador", level="error"} |= "stack" |= "Error"
```

### High-volume endpoint detection

```
topk(10, sum by (path) (count_over_time(
  {service_name="ambassador", environment="PROD"} | json [1h]
)))
```

### Error spike detection (compare to baseline)

```
# Errors in last 5 minutes
count_over_time({service_name="ambassador", level="error"} [5m])

# Compare: errors in previous 5-minute window
count_over_time({service_name="ambassador", level="error"} [5m] offset 5m)
```

### PROD errors via JSON pipeline (level not indexed)

```
{service_name="ambassador", environment="PROD"} | json | log_level="error"
{service_name="ambassador", environment="PROD"} | json | log_level=~"error|fatal|critical"
```

### Request correlation by ID

```
{environment="PROD"} |= "request-id-abc-123" | json | line_format "{{.service_name}} {{.ts}} {{.msg}}"
```

### Exclude health checks and monitoring

```
{service_name="ambassador"} != "healthcheck" != "/health" != "/ready" != "/metrics" !~ "ELB-HealthChecker"
```
