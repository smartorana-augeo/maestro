#!/usr/bin/env bash
# testrail.sh — Browse and manage TestRail projects, suites, sections, and cases
#
# Usage:
#   testrail.sh <subcommand> [OPTIONS]
#   testrail.sh projects
#   testrail.sh suites --project ID
#   testrail.sh sections --project ID --suite ID
#   testrail.sh cases --project ID --suite ID [--section ID] [--limit N] [--offset N]
#   testrail.sh get-case --case ID
#   testrail.sh get-section --section ID
#   testrail.sh add-case --section ID --title "Title" [--refs TICKET-123] [--json PAYLOAD_FILE]
#   testrail.sh add-section --project ID --suite ID --name "Name" [--parent ID]
#   testrail.sh add-suite --project ID --name "Name"
#   testrail.sh update-case --case ID --json PAYLOAD_FILE
#   testrail.sh update-section --section ID --name "Name"
#   testrail.sh delete-case --case ID --confirm
#   testrail.sh delete-section --section ID --confirm
#
# Requires: TESTRAIL_EMAIL, TESTRAIL_API_KEY, TESTRAIL_DOMAIN in .env or environment

set -Eeuo pipefail
trap 'echo "Error on line $LINENO (exit $?)" >&2' ERR

# ── Dependency check ─────────────────────────────────────────────────
for _cmd in curl python3; do
  if ! command -v "$_cmd" &>/dev/null; then
    printf "Error: Required command '%s' not found.\n" "$_cmd" >&2
    exit 1
  fi
done

# ── Early --help check (before credential validation) ──────────────
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" || -z "${1:-}" ]]; then
  echo "Usage: testrail.sh <subcommand> [OPTIONS]"
  echo ""
  echo "Subcommands (read-only):"
  echo "  projects                            List all projects"
  echo "  suites       --project ID           List suites in a project"
  echo "  sections     --project ID --suite ID  List sections in a suite"
  echo "  cases        --project ID --suite ID  List cases (--section, --limit, --offset)"
  echo "  get-case     --case ID              Get a single case"
  echo "  get-section  --section ID           Get a single section"
  echo ""
  echo "Subcommands (mutations):"
  echo "  add-case       --section ID --title \"Title\" [--refs TICKET] [--json FILE]"
  echo "  add-section    --project ID --suite ID --name \"Name\" [--parent ID]"
  echo "  add-suite      --project ID --name \"Name\""
  echo "  update-case    --case ID --json PAYLOAD_FILE"
  echo "  update-section --section ID --name \"Name\""
  echo "  delete-case    --case ID --confirm"
  echo "  delete-section --section ID --confirm"
  echo ""
  echo "Environment: TESTRAIL_EMAIL, TESTRAIL_API_KEY, TESTRAIL_DOMAIN"
  exit 0
fi

# ── Load .env from project root if available ────────────────────────
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/../../../.." && pwd -P)"
if [[ -f "$PROJECT_ROOT/.env" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "$PROJECT_ROOT/.env"
  set +a
fi

# ── Validate credentials ───────────────────────────────────────────
if [[ -z "${TESTRAIL_EMAIL:-}" || -z "${TESTRAIL_API_KEY:-}" || -z "${TESTRAIL_DOMAIN:-}" ]]; then
  echo "Error: TESTRAIL_EMAIL, TESTRAIL_API_KEY, and TESTRAIL_DOMAIN must be set." >&2
  echo "Add them to the project .env file. See .claude/skills/testrail/SKILL.md." >&2
  exit 1
fi

# ── Constants ───────────────────────────────────────────────────────
if [[ ! "$TESTRAIL_DOMAIN" =~ ^[a-zA-Z0-9._-]+\.[a-zA-Z]{2,}$ ]]; then
  echo "Error: TESTRAIL_DOMAIN looks invalid: $TESTRAIL_DOMAIN" >&2; exit 1
fi
# Note: BASE URL contains "?" (from index.php?/api/v2), so endpoint paths
# use "&" for additional query parameters (e.g. get_sections/ID&suite_id=X).
BASE="https://${TESTRAIL_DOMAIN}/index.php?/api/v2"

# ── Helpers ─────────────────────────────────────────────────────────
require_value() {
  local opt="$1"
  if [[ $# -lt 2 || -z "${2:-}" || "${2:0:1}" == "-" ]]; then
    echo "Error: ${opt} requires a value." >&2
    exit 1
  fi
}

validate_id() {
  local name="$1" val="$2"
  if [[ ! "$val" =~ ^[0-9]+$ ]]; then
    echo "Error: $name must be a positive integer, got: $val" >&2; exit 1
  fi
}

# Make an API call and handle errors
api_call() {
  local method="$1"
  local endpoint="$2"
  local data="${3:-}"

  local url="${BASE}/${endpoint}"

  # Write credentials to a temp netrc file (mode 600) to keep them off the
  # process list that would expose them via -u user:pass in curl args.
  local cred_file tmp_body
  cred_file="$(mktemp)"
  tmp_body="$(mktemp)"
  chmod 600 "$cred_file"
  # shellcheck disable=SC2064
  trap "rm -f -- '$cred_file' '$tmp_body'" RETURN EXIT
  printf 'machine %s login %s password %s\n' \
    "$TESTRAIL_DOMAIN" "$TESTRAIL_EMAIL" "$TESTRAIL_API_KEY" > "$cred_file"

  # Write response body to a temp file so we can capture only the HTTP status
  # code from -w without mixing it into the body stream.

  local args=(-s --max-time 30 -H "Content-Type: application/json" --netrc-file "$cred_file")

  if [[ "$method" == "POST" ]]; then
    args+=(-X POST)
    if [[ -n "$data" ]]; then
      args+=(-d "$data")
    fi
  fi

  local http_code body
  http_code=$(curl "${args[@]}" -o "$tmp_body" -w "%{http_code}" "$url") || {
    rm -f -- "$cred_file" "$tmp_body"
    echo "Error: curl request failed (network error or timeout)." >&2
    exit 1
  }
  body="$(cat -- "$tmp_body")"
  rm -f -- "$cred_file" "$tmp_body"

  if [[ "$http_code" -ge 200 && "$http_code" -lt 300 ]]; then
    echo "$body"
  else
    echo "Error: HTTP ${http_code}" >&2
    case "$http_code" in
      401) echo "Authentication failed. Check TESTRAIL_EMAIL and TESTRAIL_API_KEY." >&2 ;;
      403) echo "Permission denied. Your API key may lack access to this resource." >&2 ;;
      404) echo "Resource not found. Verify the ID is correct." >&2 ;;
      429) echo "Rate limited. Wait a moment and retry." >&2 ;;
      400) echo "Bad request. Check your JSON payload format." >&2 ;;
    esac
    # Show error body if present
    if [[ -n "$body" ]] && echo "$body" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('error',''))" 2>/dev/null | grep -q .; then
      echo "Detail: $(echo "$body" | python3 -c "import json,sys; print(json.load(sys.stdin).get('error',''))")" >&2
    fi
    exit 1
  fi
}

# Format JSON output for display
format_json() {
  python3 -c '
import json, sys

data = json.load(sys.stdin)
list_key = None

# Handle paginated responses (unwrap the list)
if isinstance(data, dict):
    # Find the list key (projects, suites, sections, cases, etc.)
    for k in data:
        if isinstance(data[k], list):
            list_key = k
            break
    if list_key:
        items = data[list_key]
        size = data.get("size", len(items))
        offset = data.get("offset", 0)
    else:
        # Single object
        items = [data]
        size = 1
        offset = 0
else:
    items = data if isinstance(data, list) else [data]
    size = len(items)
    offset = 0

if not items:
    print("No results found.", file=sys.stderr)
    sys.exit(0)

# Detect type and format accordingly
first = items[0]
if "title" in first and "id" in first:
    # Cases
    for item in items:
        refs = item.get("refs", "") or ""
        refs_str = f"  [{refs}]" if refs else ""
        section_id = item.get("section_id", "")
        print(f"  C{item[\"id\"]}  section={section_id}  {item.get(\"title\", \"\")}{refs_str}")
elif "name" in first and "suite_id" in first:
    # Sections
    for item in items:
        parent = item.get("parent_id") or ""
        parent_str = f"  parent={parent}" if parent else ""
        depth = item.get("depth", 0)
        indent = "  " * depth
        print(f"  S{item[\"id\"]}{parent_str}  {indent}{item.get(\"name\", \"\")}")
elif "name" in first and "id" in first and "url" in first:
    # Suites or Projects
    for item in items:
        desc = item.get("description", "") or ""
        desc_str = f"  — {desc[:60]}" if desc else ""
        print(f"  #{item[\"id\"]}  {item.get(\"name\", \"\")}{desc_str}")
else:
    # Fallback: pretty-print
    print(json.dumps(items, indent=2))

# Pagination info
if list_key and size > 0:
    shown = len(items)
    if data.get("_links", {}).get("next"):
        print(f"\n--- {shown} results (offset={offset}, more available) ---", file=sys.stderr)
    else:
        print(f"\n--- {shown} results ---", file=sys.stderr)
'
}

# ── Subcommands ─────────────────────────────────────────────────────

cmd_projects() {
  api_call GET "get_projects" | format_json
}

cmd_suites() {
  local project_id=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --project|-p) require_value "$1" "${2-}"; project_id="$2"; shift 2 ;;
      *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
  done
  if [[ -z "$project_id" ]]; then
    echo "Error: --project ID is required." >&2; exit 1
  fi
  validate_id "--project" "$project_id"
  api_call GET "get_suites/${project_id}" | format_json
}

cmd_sections() {
  local project_id="" suite_id=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --project|-p) require_value "$1" "${2-}"; project_id="$2"; shift 2 ;;
      --suite|-s)   require_value "$1" "${2-}"; suite_id="$2"; shift 2 ;;
      *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
  done
  if [[ -z "$project_id" || -z "$suite_id" ]]; then
    echo "Error: --project ID and --suite ID are required." >&2; exit 1
  fi
  validate_id "--project" "$project_id"
  validate_id "--suite" "$suite_id"
  api_call GET "get_sections/${project_id}&suite_id=${suite_id}" | format_json
}

cmd_cases() {
  local project_id="" suite_id="" section_id="" limit=250 offset=0
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --project|-p)  require_value "$1" "${2-}"; project_id="$2"; shift 2 ;;
      --suite|-s)    require_value "$1" "${2-}"; suite_id="$2"; shift 2 ;;
      --section)     require_value "$1" "${2-}"; section_id="$2"; shift 2 ;;
      --limit|-n)    require_value "$1" "${2-}"; limit="$2"; shift 2 ;;
      --offset|-o)   require_value "$1" "${2-}"; offset="$2"; shift 2 ;;
      *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
  done
  if [[ -z "$project_id" || -z "$suite_id" ]]; then
    echo "Error: --project ID and --suite ID are required." >&2; exit 1
  fi
  validate_id "--project" "$project_id"
  validate_id "--suite" "$suite_id"
  [[ -n "$section_id" ]] && validate_id "--section" "$section_id"
  if [[ ! "$limit" =~ ^[1-9][0-9]*$ ]]; then
    echo "Error: --limit must be a positive integer, got: $limit" >&2; exit 1
  fi
  if [[ ! "$offset" =~ ^[0-9]+$ ]]; then
    echo "Error: --offset must be a non-negative integer, got: $offset" >&2; exit 1
  fi
  local endpoint="get_cases/${project_id}&suite_id=${suite_id}&limit=${limit}&offset=${offset}"
  if [[ -n "$section_id" ]]; then
    endpoint="${endpoint}&section_id=${section_id}"
  fi
  api_call GET "$endpoint" | format_json
}

cmd_get_case() {
  local case_id=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --case|-c) require_value "$1" "${2-}"; case_id="$2"; shift 2 ;;
      *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
  done
  if [[ -z "$case_id" ]]; then
    echo "Error: --case ID is required." >&2; exit 1
  fi
  validate_id "--case" "$case_id"
  api_call GET "get_case/${case_id}" | format_json
}

cmd_get_section() {
  local section_id=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --section|-s) require_value "$1" "${2-}"; section_id="$2"; shift 2 ;;
      *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
  done
  if [[ -z "$section_id" ]]; then
    echo "Error: --section ID is required." >&2; exit 1
  fi
  validate_id "--section" "$section_id"
  api_call GET "get_section/${section_id}" | format_json
}

cmd_add_case() {
  local section_id="" title="" refs="" json_file=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --section|-s) require_value "$1" "${2-}"; section_id="$2"; shift 2 ;;
      --title|-t)   require_value "$1" "${2-}"; title="$2"; shift 2 ;;
      --refs|-r)    require_value "$1" "${2-}"; refs="$2"; shift 2 ;;
      --json|-j)    require_value "$1" "${2-}"; json_file="$2"; shift 2 ;;
      *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
  done
  if [[ -z "$section_id" ]]; then
    echo "Error: --section ID is required." >&2; exit 1
  fi
  validate_id "--section" "$section_id"

  local payload
  if [[ -n "$json_file" ]]; then
    if [[ ! -f "$json_file" ]]; then
      echo "Error: JSON file not found: $json_file" >&2; exit 1
    fi
    payload=$(cat "$json_file")
  else
    if [[ -z "$title" ]]; then
      echo "Error: --title is required (or use --json for full payload)." >&2; exit 1
    fi
    payload=$(python3 -c "
import json, sys
d = {'title': sys.argv[1]}
if sys.argv[2]: d['refs'] = sys.argv[2]
print(json.dumps(d))
" "$title" "$refs")
  fi

  api_call POST "add_case/${section_id}" "$payload" | format_json
  echo "Case created successfully." >&2
}

cmd_add_section() {
  local project_id="" suite_id="" name="" parent_id=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --project|-p) require_value "$1" "${2-}"; project_id="$2"; shift 2 ;;
      --suite|-s)   require_value "$1" "${2-}"; suite_id="$2"; shift 2 ;;
      --name|-n)    require_value "$1" "${2-}"; name="$2"; shift 2 ;;
      --parent)     require_value "$1" "${2-}"; parent_id="$2"; shift 2 ;;
      *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
  done
  if [[ -z "$project_id" || -z "$suite_id" || -z "$name" ]]; then
    echo "Error: --project ID, --suite ID, and --name are required." >&2; exit 1
  fi
  validate_id "--project" "$project_id"
  validate_id "--suite" "$suite_id"
  [[ -n "$parent_id" ]] && validate_id "--parent" "$parent_id"

  local payload
  payload=$(python3 -c "
import json, sys
d = {'name': sys.argv[1], 'suite_id': int(sys.argv[2])}
if sys.argv[3]: d['parent_id'] = int(sys.argv[3])
print(json.dumps(d))
" "$name" "$suite_id" "$parent_id")

  api_call POST "add_section/${project_id}" "$payload" | format_json
  echo "Section created successfully." >&2
}

cmd_add_suite() {
  local project_id="" name=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --project|-p) require_value "$1" "${2-}"; project_id="$2"; shift 2 ;;
      --name|-n)    require_value "$1" "${2-}"; name="$2"; shift 2 ;;
      *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
  done
  if [[ -z "$project_id" || -z "$name" ]]; then
    echo "Error: --project ID and --name are required." >&2; exit 1
  fi
  validate_id "--project" "$project_id"

  local payload
  payload=$(python3 -c "import json,sys; print(json.dumps({'name': sys.argv[1]}))" "$name")

  api_call POST "add_suite/${project_id}" "$payload" | format_json
  echo "Suite created successfully." >&2
}

cmd_update_case() {
  local case_id="" json_file=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --case|-c) require_value "$1" "${2-}"; case_id="$2"; shift 2 ;;
      --json|-j) require_value "$1" "${2-}"; json_file="$2"; shift 2 ;;
      *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
  done
  if [[ -z "$case_id" || -z "$json_file" ]]; then
    echo "Error: --case ID and --json PAYLOAD_FILE are required." >&2; exit 1
  fi
  validate_id "--case" "$case_id"
  if [[ ! -f "$json_file" ]]; then
    echo "Error: JSON file not found: $json_file" >&2; exit 1
  fi

  api_call POST "update_case/${case_id}" "$(cat "$json_file")" | format_json
  echo "Case C${case_id} updated." >&2
}

cmd_update_section() {
  local section_id="" name=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --section|-s) require_value "$1" "${2-}"; section_id="$2"; shift 2 ;;
      --name|-n)    require_value "$1" "${2-}"; name="$2"; shift 2 ;;
      *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
  done
  if [[ -z "$section_id" || -z "$name" ]]; then
    echo "Error: --section ID and --name are required." >&2; exit 1
  fi
  validate_id "--section" "$section_id"

  local payload
  payload=$(python3 -c "import json,sys; print(json.dumps({'name': sys.argv[1]}))" "$name")

  api_call POST "update_section/${section_id}" "$payload" | format_json
  echo "Section S${section_id} updated." >&2
}

cmd_delete_case() {
  local case_id="" confirmed=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --case|-c)  require_value "$1" "${2-}"; case_id="$2"; shift 2 ;;
      --confirm)  confirmed=true; shift ;;
      *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
  done
  if [[ -z "$case_id" ]]; then
    echo "Error: --case ID is required." >&2; exit 1
  fi
  validate_id "--case" "$case_id"
  if [[ "$confirmed" != true ]]; then
    echo "Error: --confirm flag required. This permanently deletes case C${case_id}." >&2
    exit 1
  fi

  api_call POST "delete_case/${case_id}" "{}"
  echo "Case C${case_id} deleted." >&2
}

cmd_delete_section() {
  local section_id="" confirmed=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --section|-s) require_value "$1" "${2-}"; section_id="$2"; shift 2 ;;
      --confirm)    confirmed=true; shift ;;
      *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
  done
  if [[ -z "$section_id" ]]; then
    echo "Error: --section ID is required." >&2; exit 1
  fi
  validate_id "--section" "$section_id"
  if [[ "$confirmed" != true ]]; then
    echo "Error: --confirm flag required. This permanently deletes section S${section_id} and ALL child cases." >&2
    exit 1
  fi

  api_call POST "delete_section/${section_id}" "{}"
  echo "Section S${section_id} deleted." >&2
}

# ── Dispatch ────────────────────────────────────────────────────────
CMD="${1:-}"
shift || true

case "$CMD" in
  projects)       cmd_projects "$@" ;;
  suites)         cmd_suites "$@" ;;
  sections)       cmd_sections "$@" ;;
  cases)          cmd_cases "$@" ;;
  get-case)       cmd_get_case "$@" ;;
  get-section)    cmd_get_section "$@" ;;
  add-case)       cmd_add_case "$@" ;;
  add-section)    cmd_add_section "$@" ;;
  add-suite)      cmd_add_suite "$@" ;;
  update-case)    cmd_update_case "$@" ;;
  update-section) cmd_update_section "$@" ;;
  delete-case)    cmd_delete_case "$@" ;;
  delete-section) cmd_delete_section "$@" ;;
  # --help handled at top of script before credential check
  --help|-h|"") ;;
  *)
    echo "Unknown subcommand: $CMD" >&2
    echo "Run 'testrail.sh --help' for usage." >&2
    exit 1
    ;;
esac
