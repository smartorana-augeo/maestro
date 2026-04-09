#!/usr/bin/env bash
# atlassian_api.sh — Generic Atlassian REST API caller
#
# Usage:
#   ./atlassian_api.sh [--file PATH] <METHOD> <PATH> [JSON_BODY]
#
# Examples:
#   ./atlassian_api.sh GET '/rest/api/3/issue/CODE-123'
#   ./atlassian_api.sh POST '/rest/api/3/issue' '{"fields":{...}}'
#   ./atlassian_api.sh PUT '/rest/api/3/issue/CODE-123' '{"fields":{...}}'
#   ./atlassian_api.sh DELETE '/rest/api/3/issue/CODE-123'
#   ./atlassian_api.sh --file /path/to/doc.pdf POST '/rest/api/3/issue/CODE-123/attachments'
#
# Requires env vars (or .env file in project root):
#   ATLASSIAN_EMAIL    — Atlassian account email
#   ATLASSIAN_API_TOKEN — API token from id.atlassian.com
#   ATLASSIAN_DOMAIN   — e.g. yourcompany.atlassian.net

set -Eeuo pipefail

# ── Load .env from project root if available ─────────────────────────
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/../../../.." && pwd -P)"
if [[ -f "$PROJECT_ROOT/.env" ]]; then
  while IFS='=' read -r _key _value || [[ -n "${_key:-}" ]]; do
    [[ "$_key" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${_key// }" ]] && continue
    [[ ! "$_key" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] && continue
    _value="${_value%%#*}"
    _value="${_value#"${_value%%[![:space:]]*}"}"
    _value="${_value%"${_value##*[![:space:]]}"}"
    # Strip surrounding quotes
    if [[ "$_value" =~ ^\"(.*)\"$ ]] || [[ "$_value" =~ ^\'(.*)\'$ ]]; then
      _value="${BASH_REMATCH[1]}"
    fi
    # Only export if not already set in environment
    if [[ -z "${!_key:-}" ]]; then
      export "$_key=$_value"
    fi
  done < "$PROJECT_ROOT/.env"
fi

# ── Validate required env vars ───────────────────────────────────────
missing=()
[[ -z "${ATLASSIAN_EMAIL:-}" ]] && missing+=(ATLASSIAN_EMAIL)
[[ -z "${ATLASSIAN_API_TOKEN:-}" ]] && missing+=(ATLASSIAN_API_TOKEN)
[[ -z "${ATLASSIAN_DOMAIN:-}" ]] && missing+=(ATLASSIAN_DOMAIN)

if [[ ${#missing[@]} -gt 0 ]]; then
  printf "Error: Missing required environment variables: %s\n" "${missing[*]}" >&2
  printf "Set them in your .env file or export them.\n" >&2
  printf "Generate API tokens at: https://id.atlassian.com/manage-profile/security/api-tokens\n" >&2
  exit 1
fi

# ── Parse arguments ──────────────────────────────────────────────────
FILE_UPLOAD=""
POSITIONAL=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      printf "Usage: %s [--file PATH] <METHOD> <PATH> [JSON_BODY]\n" "$(basename "$0")"
      printf "  --file PATH: upload a file as multipart/form-data (for attachments)\n"
      printf "  METHOD: GET, POST, PUT, PATCH, DELETE\n"
      printf "  PATH: API path, e.g. /rest/api/3/issue/CODE-123\n"
      printf "  JSON_BODY: optional JSON payload for POST/PUT/PATCH\n"
      exit 0
      ;;
    -f|--file)
      if [[ -z "${2:-}" ]]; then
        printf "Error: --file requires a path argument\n" >&2
        exit 1
      fi
      FILE_UPLOAD="$2"
      shift 2
      ;;
    *)
      POSITIONAL+=("$1")
      shift
      ;;
  esac
done

# Restore positional parameters
set -- "${POSITIONAL[@]+"${POSITIONAL[@]}"}"

if [[ $# -lt 2 ]]; then
  printf "Usage: %s [--file PATH] <METHOD> <PATH> [JSON_BODY]\n" "$(basename "$0")" >&2
  printf "  METHOD: GET, POST, PUT, PATCH, DELETE\n" >&2
  printf "  PATH: API path, e.g. /rest/api/3/issue/CODE-123\n" >&2
  printf "  JSON_BODY: optional JSON payload for POST/PUT/PATCH\n" >&2
  exit 1
fi

METHOD="$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]')"
PATH_ARG="$2"
BODY="${3:-}"

# ── Build URL ────────────────────────────────────────────────────────
BASE_URL="https://${ATLASSIAN_DOMAIN}"
FULL_URL="${BASE_URL}${PATH_ARG}"

# ── Build auth header ────────────────────────────────────────────────
AUTH_HEADER="$(printf '%s:%s' "$ATLASSIAN_EMAIL" "$ATLASSIAN_API_TOKEN" | base64 | tr -d '\n')"

# ── Build curl command ───────────────────────────────────────────────
if [[ -n "$FILE_UPLOAD" ]]; then
  # Multipart mode for file uploads (e.g. attachments)
  if [[ ! -f "$FILE_UPLOAD" ]]; then
    printf "Error: File not found: %s\n" "$FILE_UPLOAD" >&2
    exit 1
  fi
  CURL_ARGS=(
    --silent
    --show-error
    --max-time 30
    -X "$METHOD"
    -H "Authorization: Basic ${AUTH_HEADER}"
    -H "X-Atlassian-Token: no-check"
    -F "file=@${FILE_UPLOAD}"
  )
else
  # Standard JSON mode
  CURL_ARGS=(
    --silent
    --show-error
    --max-time 30
    -X "$METHOD"
    -H "Authorization: Basic ${AUTH_HEADER}"
    -H "Accept: application/json"
    -H "Content-Type: application/json"
  )
  if [[ -n "$BODY" ]] && [[ "$METHOD" =~ ^(POST|PUT|PATCH)$ ]]; then
    CURL_ARGS+=(-d "$BODY")
  fi
fi

# ── Execute request ──────────────────────────────────────────────────
HTTP_RESPONSE=$(mktemp)
trap 'rm -f "$HTTP_RESPONSE"' EXIT
HTTP_CODE=$(curl "${CURL_ARGS[@]}" -w "%{http_code}" -o "$HTTP_RESPONSE" "$FULL_URL" 2>/dev/null) || true

RESPONSE_BODY=$(<"$HTTP_RESPONSE")

# ── Handle response ──────────────────────────────────────────────────
if [[ -z "$HTTP_CODE" ]]; then
  printf "Connection failed for %s %s (no HTTP response)\n" "$METHOD" "$FULL_URL" >&2
  exit 1
fi

if [[ "$HTTP_CODE" -ge 200 ]] && [[ "$HTTP_CODE" -lt 300 ]]; then
  # Success — print response body (may be empty for 204)
  if [[ -n "$RESPONSE_BODY" ]]; then
    printf '%s\n' "$RESPONSE_BODY"
  fi
  exit 0
else
  printf "HTTP %s error for %s %s\n" "$HTTP_CODE" "$METHOD" "$PATH_ARG" >&2
  if [[ -n "$RESPONSE_BODY" ]]; then
    printf '%s\n' "$RESPONSE_BODY" >&2
  fi
  exit 1
fi
