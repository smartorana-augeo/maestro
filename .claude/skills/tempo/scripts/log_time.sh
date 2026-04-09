#!/usr/bin/env bash
# log_time.sh — Log time entries to Tempo via REST API
#
# Usage:
#   ./log_time.sh [--date YYYY-MM-DD] [--dry-run] < /tmp/time_entries.txt
#   ./log_time.sh --dry-run < /tmp/time_entries.txt      # preview only, no API calls
#   ./log_time.sh --date 2026-03-15 < /tmp/time_entries.txt
#
# Input format (one entry per line):
#   - 9:00 - 10:15 CODE-7605
#   - 10:15 - 10:30 TEMPO-371 (AWE Daily Standup)
#   - 1:00 - 3:30 CODE-7605
#
# Time rules: hours 1-6 = PM (13-18), 7-11 = AM, 12 = PM (noon)
#
# Requires env vars:
#   TEMPO_API_TOKEN      — Tempo REST API Bearer token
#   ATLASSIAN_API_TOKEN  — Jira Basic Auth password
#   ATLASSIAN_EMAIL      — Jira Basic Auth username
#   ATLASSIAN_DOMAIN     — e.g. augeomarketing.atlassian.net

set -euo pipefail
shopt -s inherit_errexit 2>/dev/null || true
trap 'printf "Error at %s:%d (exit %d)\n" "${BASH_SOURCE[0]}" "$LINENO" "$?" >&2' ERR

# ── Secure temp directory (cleaned up on exit) ───────────────────────
TMPDIR_WORK="$(mktemp -d)"
trap 'rm -rf -- "$TMPDIR_WORK"' EXIT

# ── Dependency check ─────────────────────────────────────────────────
for _cmd in curl python3; do
  if ! command -v "$_cmd" &>/dev/null; then
    printf "Error: Required command '%s' not found.\n" "$_cmd" >&2
    exit 1
  fi
done

# ── Load .env from project root if available ─────────────────────────
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/../../../.." && pwd -P)"
if [[ -f "$PROJECT_ROOT/.env" ]]; then
  while IFS='=' read -r _key _value || [[ -n "${_key:-}" ]]; do
    # Skip comments, blank lines, and invalid var names
    [[ "$_key" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${_key// }" ]] && continue
    [[ ! "$_key" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] && continue
    # Strip trailing inline comment and surrounding whitespace
    _value="${_value%%#*}"
    _value="${_value#"${_value%%[![:space:]]*}"}"
    _value="${_value%"${_value##*[![:space:]]}"}"
    # Strip optional surrounding quotes
    _value="${_value#\"}" ; _value="${_value%\"}"
    _value="${_value#\'}" ; _value="${_value%\'}"
    export "$_key=$_value"
  done < "$PROJECT_ROOT/.env"
fi

# ── Defaults ────────────────────────────────────────────────────────
DATE="$(date +%Y-%m-%d)"
TEMPO_BASE="https://api.us.tempo.io/4"
DRY_RUN=false

# ── Parse arguments ─────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --date|-d)
      if [[ $# -lt 2 || -z "${2:-}" ]]; then
        echo "Error: --date requires a value (YYYY-MM-DD)." >&2
        exit 1
      fi
      DATE="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=true
      shift
      ;;
    --help|-h)
      echo "Usage: log_time.sh [--date YYYY-MM-DD] [--dry-run] < time_entries.txt"
      echo ""
      echo "Options:"
      echo "  --date, -d   Date for all entries (default: today)"
      echo "  --dry-run    Preview parsed entries without posting to Tempo"
      echo "  --help, -h   Show this help"
      echo ""
      echo "Input format (stdin, one entry per line):"
      echo "  - 9:00 - 10:15 CODE-7605"
      echo "  - 10:15 - 10:30 TEMPO-371 (AWE Daily Standup)"
      echo ""
      echo "Time rules: 1-6 = PM, 7-11 = AM, 12 = PM"
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

# ── Validate date format ─────────────────────────────────────────────
if [[ ! "$DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
  echo "Error: --date must be in YYYY-MM-DD format (got: $DATE)." >&2
  exit 1
fi

# ── Detect missing stdin ─────────────────────────────────────────────
if [[ -t 0 ]]; then
  echo "Error: No input on stdin. Pipe time entries or redirect a file." >&2
  echo "Usage: log_time.sh [--date YYYY-MM-DD] [--dry-run] < time_entries.txt" >&2
  exit 1
fi

# ── Validate env (skip in dry-run) ──────────────────────────────────
if [[ "$DRY_RUN" == false ]]; then
  for var in TEMPO_API_TOKEN ATLASSIAN_API_TOKEN ATLASSIAN_EMAIL ATLASSIAN_DOMAIN; do
    if [[ -z "${!var:-}" ]]; then
      echo "Error: ${var} environment variable is not set." >&2
      echo "See .claude/skills/tempo/SKILL.md for setup instructions." >&2
      exit 1
    fi
  done

  # Validate ATLASSIAN_DOMAIN to prevent URL injection
  if [[ ! "$ATLASSIAN_DOMAIN" =~ ^[a-zA-Z0-9._-]+\.atlassian\.(net|com)$ ]]; then
    printf "Error: ATLASSIAN_DOMAIN looks invalid: %s\n" "$ATLASSIAN_DOMAIN" >&2
    exit 1
  fi

  # Write curl credential configs — keeps secrets out of the process list
  ATLASSIAN_CRED_FILE="${TMPDIR_WORK}/atlassian_cred"
  printf 'user = "%s:%s"\n' "$ATLASSIAN_EMAIL" "$ATLASSIAN_API_TOKEN" > "$ATLASSIAN_CRED_FILE"
  chmod 600 "$ATLASSIAN_CRED_FILE"

  TEMPO_CRED_FILE="${TMPDIR_WORK}/tempo_cred"
  printf 'header = "Authorization: Bearer %s"\n' "$TEMPO_API_TOKEN" > "$TEMPO_CRED_FILE"
  chmod 600 "$TEMPO_CRED_FILE"
fi

# ── Get Atlassian account ID (skip in dry-run) ───────────────────────
ACCOUNT_ID=""
if [[ "$DRY_RUN" == false ]]; then
  echo "Fetching Atlassian account ID..."
  _curl_err="${TMPDIR_WORK}/curl_err_account"
  ACCOUNT_RESP=$(curl -sSf --max-time 30 \
    --config "$ATLASSIAN_CRED_FILE" \
    "https://${ATLASSIAN_DOMAIN}/rest/api/3/myself" \
    2>"$_curl_err") || {
    echo "Error: Failed to fetch Atlassian account info." >&2
    [[ -s "$_curl_err" ]] && echo "curl error: $(cat -- "$_curl_err")" >&2
    exit 1
  }

  ACCOUNT_ID=$(python3 -c '
import json, sys
data = json.load(sys.stdin)
aid = data.get("accountId", "")
if not aid:
    print("ERROR: no accountId in response", file=sys.stderr)
    sys.exit(1)
print(aid)
' <<< "$ACCOUNT_RESP") || {
    echo "Error: Could not parse account ID from Jira response." >&2
    echo "Response: $ACCOUNT_RESP" >&2
    exit 1
  }
fi

# ── Time conversion helper ───────────────────────────────────────────
# Convert H:MM or HH:MM to total minutes (applying AM/PM logic)
# Hours 1-6 → PM (+12), 7-11 → AM, 12 → PM (noon)
time_to_minutes() {
  local t="$1"
  local h m
  h="${t%%:*}"
  m="${t##*:}"
  # Strip leading zeros to avoid octal interpretation
  h="${h#0}"
  m="${m#0}"
  # Default 0 if empty after stripping
  h="${h:-0}"
  m="${m:-0}"
  # AM/PM conversion
  if [[ "$h" -ge 1 && "$h" -le 6 ]]; then
    h=$((h + 12))
  fi
  echo $(( h * 60 + m ))
}

# Return 24h hour for a given raw H:MM string
to_24h_hour() {
  local t="$1"
  local h
  h="${t%%:*}"
  h="${h#0}"
  h="${h:-0}"
  if [[ "$h" -ge 1 && "$h" -le 6 ]]; then
    h=$((h + 12))
  fi
  echo "$h"
}

# ── Issue ID lookup ──────────────────────────────────────────────────
# Pre-known TEMPO-* IDs (no API call needed). Dynamic lookups cached for
# the script's lifetime in TMPDIR_WORK to avoid repeat API calls.
# Last verified: 2026-03-26

tempo_static_id() {
  case "$1" in
    TEMPO-370) echo "715682" ;;
    TEMPO-371) echo "715686" ;;
    TEMPO-372) echo "715687" ;;
    TEMPO-373) echo "715688" ;;
    TEMPO-374) echo "715689" ;;
    TEMPO-375) echo "715690" ;;
    TEMPO-401) echo "774429" ;;
    TEMPO-402) echo "774430" ;;
    TEMPO-403) echo "774431" ;;
    *) echo "" ;;
  esac
}

resolve_issue_id() {
  local key="$1"

  # Check static TEMPO-* table first
  local static_id
  static_id=$(tempo_static_id "$key")
  if [[ -n "$static_id" ]]; then
    echo "$static_id"
    return
  fi

  # Check session cache
  local cache_file="${TMPDIR_WORK}/tempo_id_cache_${key}"
  if [[ -f "$cache_file" ]]; then
    cat -- "$cache_file"
    return
  fi

  # Resolve via Jira API
  local resp _curl_err
  _curl_err="${TMPDIR_WORK}/curl_err_issue"
  resp=$(curl -sSf --max-time 30 \
    --config "$ATLASSIAN_CRED_FILE" \
    "https://${ATLASSIAN_DOMAIN}/rest/api/3/issue/${key}?fields=id" \
    2>"$_curl_err") || {
    echo "ERROR_FETCH"
    return
  }

  local issue_id
  issue_id=$(python3 -c '
import json, sys
try:
    data = json.loads(sys.stdin.read())
    print(data["id"])
except Exception:
    print("ERROR_PARSE", file=sys.stderr)
    sys.exit(1)
' <<< "$resp" 2>/dev/null) || {
    echo "ERROR_PARSE"
    return
  }

  echo "$issue_id" > "$cache_file"
  echo "$issue_id"
}

duration_str() {
  local secs="$1"
  local h m
  h=$(( secs / 3600 ))
  m=$(( (secs % 3600) / 60 ))
  if [[ "$h" -gt 0 && "$m" -gt 0 ]]; then
    echo "${h}h ${m}m"
  elif [[ "$h" -gt 0 ]]; then
    echo "${h}h"
  else
    echo "${m}m"
  fi
}

# ── Parse entries ────────────────────────────────────────────────────
SUCCESS=0
FAILED=0
SKIPPED=0
TOTAL_SECS=0
ENTRY_NUM=0

if [[ "$DRY_RUN" == true ]]; then
  echo ""
  echo "DRY RUN — no worklogs will be posted. Review carefully:"
  echo ""
  printf "  %-3s  %-7s  %-7s  %-8s  %-12s  %s\n" "#" "Start" "End" "Duration" "Issue Key" "Description"
  echo "  ──────────────────────────────────────────────────────────────"
else
  echo ""
  echo "Logging entries for date: $DATE"
  echo "────────────────────────────────────────"
fi

# Regex: START - END KEY (optional trailing content with description)
_ENTRY_RE='^([0-9]{1,2}:[0-9]{2})[[:space:]]+-[[:space:]]+([0-9]{1,2}:[0-9]{2})[[:space:]]+([A-Z][A-Z0-9]+-[0-9]+)(.*)'

while IFS= read -r line || [[ -n "$line" ]]; do
  # Skip empty lines and comments
  [[ -z "${line// }" ]] && continue
  [[ "$line" =~ ^[[:space:]]*# ]] && continue

  # Strip leading "- " or "* " bullet
  entry="${line#"${line%%[![:space:]-\*]*}"}"
  entry="${entry#- }"
  entry="${entry#\* }"
  entry="${entry# }"

  # Parse with bash regex — eliminates echo|sed subshell forks
  if ! [[ "$entry" =~ $_ENTRY_RE ]]; then
    if [[ "$DRY_RUN" == true ]]; then
      echo "  SKIP: Could not parse: $line"
    else
      echo "SKIP: Could not parse line: $line"
    fi
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  START_TIME="${BASH_REMATCH[1]}"
  END_TIME="${BASH_REMATCH[2]}"
  ISSUE_KEY="${BASH_REMATCH[3]}"
  REST="${BASH_REMATCH[4]}"

  # Extract optional description from trailing parentheses
  DESCRIPTION=""
  if [[ "$REST" =~ \((.+)\)[[:space:]]*$ ]]; then
    DESCRIPTION="${BASH_REMATCH[1]}"
  fi

  # Calculate duration in seconds
  START_MINS=$(time_to_minutes "$START_TIME")
  END_MINS=$(time_to_minutes "$END_TIME")
  DURATION_SECS=$(( (END_MINS - START_MINS) * 60 ))

  if [[ "$DURATION_SECS" -le 0 ]]; then
    echo "  SKIP: Negative or zero duration — ${START_TIME} to ${END_TIME}"
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  ENTRY_NUM=$((ENTRY_NUM + 1))
  TOTAL_SECS=$((TOTAL_SECS + DURATION_SECS))
  DUR_STR=$(duration_str "$DURATION_SECS")

  # Build 24h display times for preview
  START_H=$(to_24h_hour "$START_TIME")
  START_M="${START_TIME##*:}"
  END_H=$(to_24h_hour "$END_TIME")
  END_M="${END_TIME##*:}"
  START_24=$(printf "%02d:%s" "$START_H" "$START_M")
  END_24=$(printf "%02d:%s" "$END_H" "$END_M")

  if [[ "$DRY_RUN" == true ]]; then
    printf "  %-3s  %-7s  %-7s  %-8s  %-12s  %s\n" \
      "$ENTRY_NUM" "$START_24" "$END_24" "$DUR_STR" "$ISSUE_KEY" "$DESCRIPTION"
    continue
  fi

  # ── Live mode: resolve ID and post ──────────────────────────────
  ISSUE_ID=$(resolve_issue_id "$ISSUE_KEY")
  if [[ "$ISSUE_ID" == ERROR* ]]; then
    echo "FAIL: Could not resolve issue key '$ISSUE_KEY'"
    FAILED=$((FAILED + 1))
    continue
  fi

  # Build JSON payload
  PAYLOAD=$(python3 - "$ISSUE_ID" "$DURATION_SECS" "$DATE" "${START_24}:00" "$ACCOUNT_ID" "$DESCRIPTION" <<'PY'
import json, sys
issue_id, duration_secs, start_date, start_time, account_id, description = sys.argv[1:7]
payload = {
    "issueId": int(issue_id),
    "timeSpentSeconds": int(duration_secs),
    "startDate": start_date,
    "startTime": start_time,
    "authorAccountId": account_id,
}
if description:
    payload["description"] = description
print(json.dumps(payload))
PY
)

  HTTP_CODE=$(curl -s --max-time 30 \
    --config "$TEMPO_CRED_FILE" \
    -o "${TMPDIR_WORK}/tempo_resp.json" \
    -w "%{http_code}" \
    -X POST \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD" \
    "${TEMPO_BASE}/worklogs")

  if [[ "$HTTP_CODE" -ge 200 && "$HTTP_CODE" -lt 300 ]]; then
    DESC_SUFFIX=""
    [[ -n "$DESCRIPTION" ]] && DESC_SUFFIX=" ($DESCRIPTION)"
    echo "OK:   ${START_24}-${END_24}  ${ISSUE_KEY}${DESC_SUFFIX}  [${DUR_STR}]"
    SUCCESS=$((SUCCESS + 1))
  else
    RESP_BODY=$(cat -- "${TMPDIR_WORK}/tempo_resp.json" 2>/dev/null || echo "(no response body)")
    echo "FAIL: ${ISSUE_KEY} ${START_24}-${END_24} — HTTP ${HTTP_CODE}"
    echo "      Response: $RESP_BODY"
    FAILED=$((FAILED + 1))
  fi

done

# ── Summary ──────────────────────────────────────────────────────────
TOTAL_STR=$(duration_str "$TOTAL_SECS")

if [[ "$DRY_RUN" == true ]]; then
  echo "  ──────────────────────────────────────────────────────────────"
  echo ""
  echo "  Total: ${TOTAL_STR} across ${ENTRY_NUM} entries  |  ${SKIPPED} skipped"
  echo ""
  echo "  Times shown in 24h (AM/PM rule: 1-6 → PM, 7-11 → AM, 12 → noon)."
  echo "  If anything looks wrong, correct the entries and rerun --dry-run."
  echo "  To post: rerun without --dry-run."
else
  echo "────────────────────────────────────────"
  echo "Done: ${SUCCESS} logged, ${FAILED} failed, ${SKIPPED} skipped  |  Total: ${TOTAL_STR}"
  if [[ "$FAILED" -gt 0 ]]; then
    exit 1
  fi
fi
