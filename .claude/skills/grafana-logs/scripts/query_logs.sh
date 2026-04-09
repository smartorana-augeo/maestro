#!/usr/bin/env bash
# query_logs.sh — Query Grafana Cloud Loki logs via datasource proxy
#
# Usage:
#   ./query_logs.sh --service ambassador --env STAGING --level error --since 5m
#   ./query_logs.sh --env PROD --since 1h --limit 25
#   ./query_logs.sh --service nextweb --env STAGING --since 15m --filter "timeout"
#   ./query_logs.sh --service ambassador --env PROD --level error --since 5m --count
#   ./query_logs.sh --query '{service_name="ambassador", environment="PROD"} |= "error"' --since 30m
#   ./query_logs.sh --service ambassador --env STAGING --since 15m --fields msg,level,status --max-width 200
#   ./query_logs.sh --service ambassador --env STAGING --since 5m --exclude healthcheck --exclude ECONNRESET
#   ./query_logs.sh --service ambassador --env STAGING --json-filter "status >= 500"
#   ./query_logs.sh --service ambassador --env STAGING --from 2024-01-15T10:30:00 --to 2024-01-15T11:00:00
#   ./query_logs.sh --service ambassador --env STAGING --regex "(?i)unauthorized"
#   ./query_logs.sh --service ambassador --env STAGING --json --dedup
#   ./query_logs.sh --labels
#   ./query_logs.sh --label-values service_name
#
# Requires: GRAFANA_TOKEN in project .env or environment (glsa_* service account token)
#           python3 >= 3.6, curl

set -Eeuo pipefail
trap 'printf "Error at %s:%d (exit %d)\n" "${BASH_SOURCE[0]}" "$LINENO" "$?" >&2' ERR

# Load .env from project root if available — export only GRAFANA_TOKEN
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/../../../.." && pwd -P)"
if [[ -f "$PROJECT_ROOT/.env" ]]; then
  # shellcheck source=/dev/null
  source "$PROJECT_ROOT/.env"
fi

# ── Defaults ────────────────────────────────────────────────────────
SERVICE=""
ENV=""
LEVEL=""
SINCE="5m"
LIMIT=25
FILTER=""
REGEX_FILTER=""
COUNT_ONLY=false
DATASOURCE_ID=7
GRAFANA_HOST="https://augeomarketing.grafana.net"
FIELDS=""
MAX_WIDTH=0
RAW_QUERY=""
START_TS=""
SHOW_TIMESTAMPS=1
SORT_ORDER="desc"
FROM_TS=""
TO_TS=""
DISCOVER_LABELS=false
DISCOVER_LABEL_VALUES=""
EXCLUDES=()
JSON_FILTERS=()
JSON_OUTPUT=0
DEDUP=0
SHOW_LABELS=0

# ── Parse arguments ─────────────────────────────────────────────────
require_value() {
  local opt="$1"
  if [[ $# -lt 2 || -z "${2:-}" || "${2:0:1}" == "-" ]]; then
    printf 'Error: %s requires a value.\n' "$opt" >&2
    exit 1
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --service|-s)   require_value "$1" "${2-}"; SERVICE="$2"; shift 2 ;;
    --env|-e)       require_value "$1" "${2-}"; ENV="$2"; shift 2 ;;
    --level|-l)     require_value "$1" "${2-}"; LEVEL="$2"; shift 2 ;;
    --since|-t)     require_value "$1" "${2-}"; SINCE="$2"; shift 2 ;;
    --limit|-n)
      require_value "$1" "${2-}"
      [[ "$2" =~ ^[1-9][0-9]*$ ]] || { printf 'Error: --limit must be a positive integer.\n' >&2; exit 1; }
      LIMIT="$2"; shift 2 ;;
    --filter|-f)    require_value "$1" "${2-}"; FILTER="$2"; shift 2 ;;
    --regex|-r)     require_value "$1" "${2-}"; REGEX_FILTER="$2"; shift 2 ;;
    --exclude|-x)   require_value "$1" "${2-}"; EXCLUDES+=("$2"); shift 2 ;;
    --json-filter|-j) require_value "$1" "${2-}"; JSON_FILTERS+=("$2"); shift 2 ;;
    --fields|-F)    require_value "$1" "${2-}"; FIELDS="$2"; shift 2 ;;
    --max-width|-w)
      require_value "$1" "${2-}"
      [[ "$2" =~ ^[0-9]+$ ]] || { printf 'Error: --max-width must be a non-negative integer.\n' >&2; exit 1; }
      MAX_WIDTH="$2"; shift 2 ;;
    --query|-q)     require_value "$1" "${2-}"; RAW_QUERY="$2"; shift 2 ;;
    --count|-c)     COUNT_ONLY=true; shift ;;
    --timestamps|-T) SHOW_TIMESTAMPS=1; shift ;;
    --no-timestamps) SHOW_TIMESTAMPS=0; shift ;;
    --json)         JSON_OUTPUT=1; shift ;;
    --dedup)        DEDUP=1; shift ;;
    --show-labels)  SHOW_LABELS=1; shift ;;
    --sort)
      require_value "$1" "${2-}"
      case "$2" in asc|desc) ;; *) printf 'Error: --sort must be "asc" or "desc".\n' >&2; exit 1 ;; esac
      SORT_ORDER="$2"; shift 2 ;;
    --from)         require_value "$1" "${2-}"; FROM_TS="$2"; shift 2 ;;
    --to)           require_value "$1" "${2-}"; TO_TS="$2"; shift 2 ;;
    --labels)       DISCOVER_LABELS=true; shift ;;
    --label-values) require_value "$1" "${2-}"; DISCOVER_LABEL_VALUES="$2"; shift 2 ;;
    --ds)
      require_value "$1" "${2-}"
      [[ "$2" =~ ^[1-9][0-9]*$ ]] || { printf 'Error: --ds must be a positive integer.\n' >&2; exit 1; }
      DATASOURCE_ID="$2"; shift 2 ;;
    --help|-h)
      printf 'Usage: query_logs.sh [OPTIONS]\n'
      printf '\n'
      printf 'Options:\n'
      printf '  --service, -s       Service name (e.g., ambassador, nextweb, badges)\n'
      printf '  --env, -e           Environment (DEV0, STAGING, SANDBOX, PROD)\n'
      printf '  --level, -l         Log level (debug, info, warn, error)\n'
      printf '  --since, -t         Time range (e.g., 5m, 15m, 1h, 4h, 1d) [default: 5m]\n'
      printf '  --limit, -n         Max log lines to return [default: 25]\n'
      printf '  --filter, -f        Substring filter on log lines (|= "text")\n'
      printf '  --regex, -r         Regex filter on log lines (|~ "pattern")\n'
      printf '  --exclude, -x       Exclude lines containing text (repeatable, != "text")\n'
      printf '  --json-filter, -j   JSON field filter via | json pipeline (e.g., "status >= 500") (repeatable)\n'
      printf '  --fields, -F        Comma-separated JSON fields to extract (e.g., msg,level,status)\n'
      printf '  --max-width, -w     Truncate each output line to N characters\n'
      printf '  --query, -q         Raw LogQL query (bypasses --service/--env/--level)\n'
      printf '  --count, -c         Return count of matching lines instead of lines\n'
      printf '  --timestamps, -T    Show timestamps on each line [default: on]\n'
      printf '  --no-timestamps     Hide timestamps from output\n'
      printf '  --json              Output results as a JSON array (for piping/scripting)\n'
      printf '  --dedup             Collapse consecutive duplicate log lines\n'
      printf '  --show-labels       Prefix each line with stream labels\n'
      printf '  --sort              Sort order: "asc" (oldest first) or "desc" (newest first) [default: desc]\n'
      printf '  --from              Absolute start time (ISO 8601, e.g., 2024-01-15T10:30:00)\n'
      printf '  --to                Absolute end time (ISO 8601, e.g., 2024-01-15T11:00:00)\n'
      printf '  --labels            List all available Loki labels\n'
      printf '  --label-values NAME List values for a specific label\n'
      printf '  --ds                Loki datasource ID [default: 7]\n'
      printf '  --help, -h          Show this help\n'
      printf '\n'
      printf 'Examples:\n'
      printf '  query_logs.sh --service ambassador --env STAGING --level error --since 5m\n'
      printf '  query_logs.sh --env PROD --since 1h --limit 25\n'
      printf '  query_logs.sh --service ambassador --env STAGING --exclude healthcheck --exclude ECONNRESET\n'
      printf '  query_logs.sh --service ambassador --env STAGING --regex "(?i)timeout"\n'
      printf '  query_logs.sh --service ambassador --env STAGING --json-filter "status >= 500"\n'
      printf '  query_logs.sh --service ambassador --env STAGING --from 2024-01-15T10:00:00 --to 2024-01-15T11:00:00\n'
      printf '  query_logs.sh --service ambassador --env STAGING --sort asc --no-timestamps\n'
      printf '  query_logs.sh --service ambassador --env STAGING --json --dedup\n'
      printf '  query_logs.sh --labels\n'
      printf '  query_logs.sh --label-values service_name\n'
      exit 0
      ;;
    --) shift; break ;;
    *) printf 'Unknown option: %s\n' "$1" >&2; exit 1 ;;
  esac
done

# ── Validate ────────────────────────────────────────────────────────
if [[ -z "${GRAFANA_TOKEN:-}" ]]; then
  printf 'Error: GRAFANA_TOKEN environment variable is not set.\n' >&2
  printf "Set it with: export GRAFANA_TOKEN='glsa_...'\n" >&2
  exit 1
fi

BASE="${GRAFANA_HOST}/api/datasources/proxy/${DATASOURCE_ID}/loki/api/v1"

# ── Label discovery ─────────────────────────────────────────────────
if [[ "$DISCOVER_LABELS" == true ]]; then
  curl -sSf --max-time 30 -H "Authorization: Bearer $GRAFANA_TOKEN" "$BASE/labels" \
    | python3 -c '
import json, sys
data = json.load(sys.stdin)
if data.get("status") != "success":
    print("Error: " + str(data.get("error", "unknown error")), file=sys.stderr)
    sys.exit(1)
for label in sorted(data.get("data", [])):
    print(label)
'
  exit 0
fi

if [[ -n "$DISCOVER_LABEL_VALUES" ]]; then
  if [[ ! "$DISCOVER_LABEL_VALUES" =~ ^[A-Za-z0-9_.-]+$ ]]; then
    printf 'Error: --label-values must be a valid label name (alphanumeric, dots, dashes, underscores only).\n' >&2; exit 1
  fi
  curl -sSf --max-time 30 -H "Authorization: Bearer $GRAFANA_TOKEN" \
    "$BASE/label/${DISCOVER_LABEL_VALUES}/values" \
    | python3 -c '
import json, sys
data = json.load(sys.stdin)
if data.get("status") != "success":
    print("Error: " + str(data.get("error", "unknown error")), file=sys.stderr)
    sys.exit(1)
for val in sorted(data.get("data", [])):
    print(val)
'
  exit 0
fi

# ── Build LogQL query ───────────────────────────────────────────────
if [[ -n "$RAW_QUERY" ]]; then
  QUERY="$RAW_QUERY"
else
  escape_logql_string() {
    local s="${1//\\/\\\\}"
    s="${s//\"/\\\"}"
    printf '%s' "$s"
  }

  SELECTORS=()
  [[ -n "$SERVICE" ]] && SELECTORS+=("service_name=\"$(escape_logql_string "$SERVICE")\"")
  [[ -n "$ENV" ]]     && SELECTORS+=("environment=\"$(escape_logql_string "$ENV")\"")
  [[ -n "$LEVEL" ]]   && SELECTORS+=("level=\"$(escape_logql_string "$LEVEL")\"")

  if [[ ${#SELECTORS[@]} -eq 0 ]]; then
    printf 'Error: At least one selector required (--service, --env, --level, or --query)\n' >&2
    exit 1
  fi

  SELECTOR_STR=$(IFS=', '; printf '%s' "${SELECTORS[*]}")
  QUERY="{${SELECTOR_STR}}"

  # Substring include filter
  if [[ -n "$FILTER" ]]; then
    QUERY="${QUERY} |= \"$(escape_logql_string "$FILTER")\""
  fi

  # Regex include filter
  if [[ -n "$REGEX_FILTER" ]]; then
    QUERY="${QUERY} |~ \"$(escape_logql_string "$REGEX_FILTER")\""
  fi

  # Exclude filters (--exclude)
  for exc in "${EXCLUDES[@]+"${EXCLUDES[@]}"}"; do
    QUERY="${QUERY} != \"$(escape_logql_string "$exc")\""
  done

  # JSON field filters (--json-filter)
  if [[ ${#JSON_FILTERS[@]} -gt 0 ]]; then
    QUERY="${QUERY} | json"
    for jf in "${JSON_FILTERS[@]}"; do
      QUERY="${QUERY} | ${jf}"
    done
  fi
fi

# ── Compute time range ─────────────────────────────────────────────

# Helper: convert ISO 8601 timestamp to nanosecond epoch
iso_to_ns() {
  local iso="$1"
  local epoch_sec
  if date -j -f "%Y-%m-%dT%H:%M:%S" "$iso" +%s >/dev/null 2>&1; then
    # macOS (BSD date)
    epoch_sec=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$iso" +%s)
  else
    # Linux (GNU date)
    epoch_sec=$(date -d "$iso" +%s)
  fi
  printf '%s000000000' "$epoch_sec"
}

# Determine direction parameter for API
if [[ "$SORT_ORDER" == "asc" ]]; then
  DIRECTION="FORWARD"
else
  DIRECTION="BACKWARD"
fi

if [[ -n "$FROM_TS" ]]; then
  # ── Absolute time range ────────────────────────────────────────
  START_TS="$(iso_to_ns "$FROM_TS")"
  if [[ -n "$TO_TS" ]]; then
    END_TS="$(iso_to_ns "$TO_TS")"
  else
    END_TS="$(date +%s)000000000"
  fi

  # When --count is used with absolute time range, compute SINCE duration
  # so count_over_time covers the full window instead of the default 5m
  if [[ "$COUNT_ONLY" == true ]]; then
    start_sec="${START_TS%000000000}"
    end_sec="${END_TS%000000000}"
    duration_seconds=$(( end_sec - start_sec ))
    if [[ "$duration_seconds" -le 0 ]]; then
      printf 'Error: --from must be earlier than --to.\n' >&2
      exit 1
    fi
    SINCE="${duration_seconds}s"
  fi
else
  # ── Relative time range (--since) ─────────────────────────────
  END_TS="$(date +%s)000000000"

  # Validate --since format
  if ! [[ "$SINCE" =~ ^[1-9][0-9]*[mMhHdD]$ ]]; then
    printf 'Error: --since must be a positive duration like 5m, 1h, or 1d.\n' >&2
    exit 1
  fi

  SINCE_NUM="${SINCE%?}"
  SINCE_UNIT="$(printf '%s' "${SINCE: -1}" | tr '[:upper:]' '[:lower:]')"
  SINCE="${SINCE_NUM}${SINCE_UNIT}"

  if [[ "$COUNT_ONLY" != true ]]; then
    if date -v-1M +%s >/dev/null 2>&1; then
      # macOS (BSD date)
      case "$SINCE_UNIT" in
        m) DATE_FLAG="-v-${SINCE_NUM}M" ;;
        h) DATE_FLAG="-v-${SINCE_NUM}H" ;;
        d) DATE_FLAG="-v-${SINCE_NUM}d" ;;
        *) printf "Error: Unsupported time unit '%s'. Use m, h, or d.\n" "$SINCE_UNIT" >&2; exit 1 ;;
      esac
      START_TS="$(date "$DATE_FLAG" +%s)000000000"
    else
      # Linux (GNU date)
      case "$SINCE_UNIT" in
        m) DATE_ARG="${SINCE_NUM} minutes ago" ;;
        h) DATE_ARG="${SINCE_NUM} hours ago" ;;
        d) DATE_ARG="${SINCE_NUM} days ago" ;;
        *) printf "Error: Unsupported time unit '%s'. Use m, h, or d.\n" "$SINCE_UNIT" >&2; exit 1 ;;
      esac
      START_TS="$(date -d "$DATE_ARG" +%s)000000000"
    fi
  fi
fi

# ── Execute query ───────────────────────────────────────────────────
FORMATTER="${SCRIPT_DIR}/format_output.py"

if [[ "$COUNT_ONLY" == true ]]; then
  QUERY="count_over_time(${QUERY} [${SINCE}])"
  curl -sSf --max-time 30 -H "Authorization: Bearer $GRAFANA_TOKEN" \
    "$BASE/query" \
    --data-urlencode "query=${QUERY}" \
    --data-urlencode "time=${END_TS}" \
    | (unset GRAFANA_TOKEN; \
       MODE="count" \
       SINCE="$SINCE" \
       python3 "$FORMATTER")
else
  curl -sSf --max-time 30 -H "Authorization: Bearer $GRAFANA_TOKEN" \
    "$BASE/query_range" \
    --data-urlencode "query=${QUERY}" \
    --data-urlencode "start=${START_TS}" \
    --data-urlencode "end=${END_TS}" \
    --data-urlencode "limit=${LIMIT}" \
    --data-urlencode "direction=${DIRECTION}" \
    | (unset GRAFANA_TOKEN; \
       MODE="range" \
       FIELDS="$FIELDS" \
       MAX_WIDTH="$MAX_WIDTH" \
       SHOW_TIMESTAMPS="$SHOW_TIMESTAMPS" \
       SORT_ORDER="$SORT_ORDER" \
       SINCE="$SINCE" \
       JSON_OUTPUT="$JSON_OUTPUT" \
       DEDUP="$DEDUP" \
       SHOW_LABELS="$SHOW_LABELS" \
       python3 "$FORMATTER")
fi
