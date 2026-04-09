#!/usr/bin/env bash
# circleci.sh — Investigate and manage CircleCI pipelines, workflows, and jobs
#
# Usage:
#   circleci.sh <subcommand> [OPTIONS]
#   circleci.sh failed [--project SLUG] [--branch NAME] [--details]
#   circleci.sh jobs --workflow ID [--failed-only]
#   circleci.sh artifacts --job NUMBER [--project SLUG] [--download URL] [--output FILE]
#   circleci.sh rerun --workflow ID [--from-failed]
#   circleci.sh cancel --workflow ID
#   circleci.sh pipelines [--project SLUG] [--branch NAME] [--limit N]
#   circleci.sh tests --job NUMBER [--project SLUG] [--failed-only]
#   circleci.sh flaky [--project SLUG]
#
# Requires: CIRCLECI_TOKEN in project .env, env var, or ~/.circleci/cli.yml — use expiring tokens

set -Eeuo pipefail
trap 'printf "Error at %s:%d (exit %d)\n" "${BASH_SOURCE[0]}" "$LINENO" "$?" >&2' ERR

# ── Load .env from project root if available ────────────────────────
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/../../../.." && pwd -P)"
if [[ -f "$PROJECT_ROOT/.env" ]]; then
  set -a
  # shellcheck source=/dev/null
  source "$PROJECT_ROOT/.env"
  set +a
fi

# ── Constants ────────────────────────────────────────────────────────
BASE="https://circleci.com/api/v2"
DEFAULT_SLUG="gh/Structuralapp/ambassador"

# ── Resolve token ────────────────────────────────────────────────────
if [[ -z "${CIRCLECI_TOKEN:-}" ]]; then
  if [[ -f "$HOME/.circleci/cli.yml" ]]; then
    CIRCLECI_TOKEN=$(grep -E '^\s*token:' "$HOME/.circleci/cli.yml" | head -1 | awk '{print $2}' | tr -d '"'"'")
  fi
fi
if [[ -z "${CIRCLECI_TOKEN:-}" ]]; then
  echo "Error: CIRCLECI_TOKEN not set. Add it to your .env file or set it as an environment variable." >&2
  exit 1
fi
AUTH="Circle-Token: $CIRCLECI_TOKEN"

# ── Helpers ──────────────────────────────────────────────────────────
validate_slug() {
  local slug="$1"
  if [[ ! "$slug" =~ ^gh/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]; then
    echo "Error: invalid project slug '$slug' (expected format: gh/org/repo)" >&2
    exit 1
  fi
}

require_value() {
  local opt="$1"
  if [[ $# -lt 2 || -z "${2:-}" || "${2:0:1}" == "-" ]]; then
    echo "Error: ${opt} requires a value." >&2
    exit 1
  fi
}

validate_uuid() {
  local id="$1"
  if [[ ! "$id" =~ ^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$ ]]; then
    echo "Error: invalid ID '$id' (expected hex UUID)" >&2; exit 1
  fi
}

validate_positive_int() {
  local name="$1" val="$2"
  if [[ ! "$val" =~ ^[0-9]+$ ]] || [[ "$val" -eq 0 ]]; then
    echo "Error: $name must be a positive integer" >&2; exit 1
  fi
}

# ── Subcommand: failed ───────────────────────────────────────────────
cmd_failed() {
  local project="$DEFAULT_SLUG"
  local details=false
  local branch=""

  # Auto-detect current branch
  if git rev-parse --abbrev-ref HEAD >/dev/null 2>&1; then
    branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
    [[ "$branch" == "HEAD" ]] && branch=""
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --project|-p) require_value "$1" "${2-}"; project="$2"; shift 2 ;;
      --details|-d) details=true; shift ;;
      --branch|-b)  require_value "$1" "${2-}"; branch="$2"; shift 2 ;;
      --help|-h)
        echo "Usage: circleci.sh failed [--project SLUG] [--branch NAME] [--details]"
        echo "  --project, -p  Project slug [default: $DEFAULT_SLUG]"
        echo "  --branch, -b   Branch name [default: current git branch]"
        echo "  --details, -d  Also list failed jobs within the workflow"
        exit 0 ;;
      *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
  done

  validate_slug "$project"

  local pipeline_url="$BASE/project/$project/pipeline"
  [[ -n "$branch" ]] && pipeline_url="${pipeline_url}?branch=$(printf '%s' "$branch" | python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.stdin.read()))")"

  local pipeline_response
  pipeline_response=$(curl -sf --max-time 30 -H "$AUTH" "$pipeline_url") || {
    echo "Error: failed to fetch pipelines" >&2; exit 1
  }
  local pipelines
  pipelines=$(echo "$pipeline_response" | python3 -c '
import json, sys
data = json.load(sys.stdin)
if "items" not in data:
    print("Error: unexpected API response", file=sys.stderr)
    sys.exit(1)
for i in data["items"]:
    print(i["id"])
' 2>&1) || { echo "$pipelines" >&2; exit 1; }

  local found=false
  while IFS= read -r pid; do
    [[ -z "$pid" ]] && continue
    local wf_response
    wf_response=$(curl -sf --max-time 30 -H "$AUTH" "$BASE/pipeline/$pid/workflow") || continue
    local failed
    failed=$(echo "$wf_response" | python3 -c "
import json, sys
for w in json.load(sys.stdin).get('items', []):
    if w['status'] in ('failed', 'error', 'failing', 'unauthorized'):
        print(w['status'], w['id'], w['name'])
") || continue

    if [[ -n "$failed" ]]; then
      echo "Pipeline: $pid"
      echo "$failed"
      if [[ "$details" == true ]]; then
        local wf_id
        wf_id=$(echo "$failed" | head -1 | awk '{print $2}')
        echo ""
        echo "Failed jobs in workflow $wf_id:"
        curl -sf --max-time 30 -H "$AUTH" "$BASE/workflow/$wf_id/job" | python3 -c '
import json, sys
for j in json.load(sys.stdin).get("items", []):
    if j["status"] in ("failed", "timedout", "infrastructure_fail"):
        print("  [" + j["status"] + "] " + j["name"] + " (job #" + str(j.get("job_number", "N/A")) + ")")
'
      fi
      found=true
      break
    fi
  done <<< "$pipelines"

  if [[ "$found" == false ]]; then
    echo "No failed workflows found in recent pipelines."
  fi
}

# ── Subcommand: jobs ─────────────────────────────────────────────────
cmd_jobs() {
  local workflow_id=""
  local failed_only=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --workflow|-w) require_value "$1" "${2-}"; workflow_id="$2"; shift 2 ;;
      --failed-only|-f) failed_only=true; shift ;;
      --help|-h)
        echo "Usage: circleci.sh jobs --workflow ID [--failed-only]"
        echo "  --workflow, -w    Workflow UUID (required)"
        echo "  --failed-only, -f Only show failed/timedout jobs"
        exit 0 ;;
      *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
  done

  if [[ -z "$workflow_id" ]]; then
    echo "Error: --workflow is required" >&2; exit 1
  fi
  validate_uuid "$workflow_id"

  FAILED_ONLY="$failed_only" curl -sf --max-time 30 -H "$AUTH" "$BASE/workflow/$workflow_id/job" | python3 -c '
import json, os, sys
failed_only = os.environ.get("FAILED_ONLY") == "true"
failed_statuses = {"failed", "timedout", "infrastructure_fail"}
items = [j for j in json.load(sys.stdin).get("items", [])
         if not failed_only or j["status"] in failed_statuses]
if not items:
    print("No jobs found." if not failed_only else "No failed jobs found.")
else:
    for j in items:
        num = j.get("job_number", "N/A")
        print("[" + j["status"] + "] " + j["name"] + " (job #" + str(num) + ")")
'
}

# ── Subcommand: artifacts ────────────────────────────────────────────
cmd_artifacts() {
  local job_number=""
  local project="$DEFAULT_SLUG"
  local download_url=""
  local output_file=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --job|-j)      require_value "$1" "${2-}"; job_number="$2"; shift 2 ;;
      --project|-p)  require_value "$1" "${2-}"; project="$2"; shift 2 ;;
      --download)    require_value "$1" "${2-}"; download_url="$2"; shift 2 ;;
      --output|-O)   require_value "$1" "${2-}"; output_file="$2"; shift 2 ;;
      --help|-h)
        echo "Usage: circleci.sh artifacts --job NUMBER [--project SLUG] [--download URL] [--output FILE]"
        echo "  --job, -j        Job number (required)"
        echo "  --project, -p    Project slug [default: $DEFAULT_SLUG]"
        echo "  --download       Download artifact at URL"
        echo "  --output, -O     Output filename for download [default: auto-detect from URL]"
        exit 0 ;;
      *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
  done

  if [[ -z "$job_number" ]]; then
    echo "Error: --job is required" >&2; exit 1
  fi
  validate_positive_int "--job" "$job_number"
  validate_slug "$project"

  if [[ -n "$download_url" ]]; then
    local dest="$output_file"
    if [[ -z "$dest" ]]; then
      # Try to extract meaningful filename from artifact URL
      # URLs look like: https://output.circle-artifacts.com/.../artifacts/0/path/to/file.xml
      dest=$(echo "$download_url" | python3 -c "
import sys, re
url = sys.stdin.read().strip()
m = re.search(r'/artifacts/\d+/(.+)$', url)
if m:
    # Use the artifact path, replacing slashes with dashes
    print(m.group(1).replace('/', '-'))
else:
    # Fall back to last path segment
    seg = url.rstrip('/').rsplit('/', 1)[-1]
    print(seg if seg and '?' not in seg[:20] else '')
" 2>/dev/null)
      [[ -z "$dest" ]] && dest="artifact-${job_number}"
    fi
    # Only send auth header to trusted CircleCI hosts
    if [[ "$download_url" =~ ^https://circleci\.com/ ]]; then
      curl -sfL --connect-timeout 10 -H "$AUTH" "$download_url" -o "$dest"
    elif [[ "$download_url" =~ ^https://output\.circle-artifacts\.com/ ]]; then
      curl -sfL --connect-timeout 10 "$download_url" -o "$dest"
    else
      echo "Error: --download URL must be a trusted CircleCI artifact URL." >&2
      return 1
    fi
    echo "Downloaded to: $dest"
    return
  fi

  curl -sf --max-time 30 -H "$AUTH" "$BASE/project/$project/$job_number/artifacts" | python3 -c '
import json, sys
items = json.load(sys.stdin).get("items", [])
if not items:
    print("No artifacts found for this job.")
else:
    for a in items:
        print(a["path"] + "  ->  " + a["url"])
'
}

# ── Subcommand: rerun ────────────────────────────────────────────────
cmd_rerun() {
  local workflow_id=""
  local from_failed=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --workflow|-w)   require_value "$1" "${2-}"; workflow_id="$2"; shift 2 ;;
      --from-failed|-f) from_failed=true; shift ;;
      --help|-h)
        echo "Usage: circleci.sh rerun --workflow ID [--from-failed]"
        echo "  --workflow, -w     Workflow UUID (required)"
        echo "  --from-failed, -f  Rerun only from failed jobs (default: full rerun)"
        exit 0 ;;
      *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
  done

  if [[ -z "$workflow_id" ]]; then
    echo "Error: --workflow is required" >&2; exit 1
  fi
  validate_uuid "$workflow_id"

  local payload="{}"
  [[ "$from_failed" == true ]] && payload='{"from_failed":true}'

  echo "Rerunning workflow $workflow_id (from_failed=$from_failed)..."
  curl -sf --max-time 30 -X POST -H "$AUTH" -H "Content-Type: application/json" \
    -d "$payload" "$BASE/workflow/$workflow_id/rerun" | python3 -c '
import json, sys
data = json.load(sys.stdin)
wf_id = data.get("workflow", {}).get("id", "") if "workflow" in data else data.get("id", "")
if wf_id:
    print("New workflow ID: " + wf_id)
else:
    print(json.dumps(data, indent=2))
'
}

# ── Subcommand: cancel ───────────────────────────────────────────────
cmd_cancel() {
  local workflow_id=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --workflow|-w) require_value "$1" "${2-}"; workflow_id="$2"; shift 2 ;;
      --help|-h)
        echo "Usage: circleci.sh cancel --workflow ID"
        echo "  --workflow, -w  Workflow UUID (required)"
        exit 0 ;;
      *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
  done

  if [[ -z "$workflow_id" ]]; then
    echo "Error: --workflow is required" >&2; exit 1
  fi
  validate_uuid "$workflow_id"

  echo "Cancelling workflow $workflow_id..."
  if curl -sf --max-time 30 -X POST -H "$AUTH" "$BASE/workflow/$workflow_id/cancel" 2>/dev/null; then
    echo "Cancelled."
  else
    echo "Error: failed to cancel workflow $workflow_id" >&2
    exit 1
  fi
}

# ── Subcommand: workflows ─────────────────────────────────────────────
cmd_workflows() {
  local pipeline_id=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --pipeline|-p) require_value "$1" "${2-}"; pipeline_id="$2"; shift 2 ;;
      --help|-h)
        echo "Usage: circleci.sh workflows --pipeline ID"
        echo "  --pipeline, -p  Pipeline UUID (required)"
        exit 0 ;;
      *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
  done

  if [[ -z "$pipeline_id" ]]; then
    echo "Error: --pipeline is required" >&2; exit 1
  fi
  validate_uuid "$pipeline_id"

  local response
  response=$(curl -sf --max-time 30 -H "$AUTH" "$BASE/pipeline/$pipeline_id/workflow") || {
    echo "Error: failed to fetch workflows" >&2; exit 1
  }

  echo "$response" | python3 -c '
import json, sys
data = json.load(sys.stdin)
if "message" in data:
    print("Error: " + data["message"], file=sys.stderr)
    sys.exit(1)
items = data.get("items", [])
if not items:
    print("No workflows found for this pipeline.")
else:
    for w in items:
        print(w["status"] + "  " + w["name"] + "  " + w["id"])
'
}

# ── Subcommand: pipelines ────────────────────────────────────────────
cmd_pipelines() {
  local project="$DEFAULT_SLUG"
  local branch=""
  local limit=10

  # Auto-detect current branch
  if git rev-parse --abbrev-ref HEAD >/dev/null 2>&1; then
    branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
    [[ "$branch" == "HEAD" ]] && branch=""
  fi

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --project|-p) require_value "$1" "${2-}"; project="$2"; shift 2 ;;
      --branch|-b)  require_value "$1" "${2-}"; branch="$2"; shift 2 ;;
      --limit|-n)   require_value "$1" "${2-}"; limit="$2"; shift 2 ;;
      --help|-h)
        echo "Usage: circleci.sh pipelines [--project SLUG] [--branch NAME] [--limit N]"
        echo "  --project, -p  Project slug [default: $DEFAULT_SLUG]"
        echo "  --branch, -b   Branch name [default: current git branch]"
        echo "  --limit, -n    Max pipelines to show [default: 10]"
        exit 0 ;;
      *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
  done

  validate_slug "$project"
  validate_positive_int "--limit" "$limit"

  local url="$BASE/project/$project/pipeline"
  [[ -n "$branch" ]] && url="${url}?branch=$(printf '%s' "$branch" | python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.stdin.read()))")"

  curl -sf --max-time 30 -H "$AUTH" "$url" | (LIMIT="$limit" BRANCH="$branch" python3 -c '
import json, os, sys
limit = int(os.environ["LIMIT"])
items = json.load(sys.stdin).get("items", [])[:limit]
if not items:
    b = os.environ.get("BRANCH", "")
    print("No pipelines found for branch: " + b if b else "No pipelines found.")
else:
    for p in items:
        b = p.get("vcs", {}).get("branch", "unknown")
        print("#" + str(p["number"]) + "  " + p["state"] + "  " + b + "  " + p["created_at"][:19] + "  " + p["id"])
')
}

# ── Subcommand: flaky ────────────────────────────────────────────────
cmd_flaky() {
  local project="$DEFAULT_SLUG"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --project|-p) require_value "$1" "${2-}"; project="$2"; shift 2 ;;
      --help|-h)
        echo "Usage: circleci.sh flaky [--project SLUG]"
        echo "  --project, -p  Project slug [default: $DEFAULT_SLUG]"
        exit 0 ;;
      *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
  done

  validate_slug "$project"

  curl -sf --max-time 30 -H "$AUTH" "$BASE/insights/$project/flaky-tests" | python3 -c '
import json, sys
tests = json.load(sys.stdin).get("flaky_tests", [])
if not tests:
    print("No flaky tests found.")
else:
    for t in tests:
        print(t["test_name"] + "  (flaky in " + t.get("workflow_name", "?") + "/" + t.get("job_name", "?") + ")")
'
}

# ── Subcommand: tests ────────────────────────────────────────────────
cmd_tests() {
  local job_number=""
  local project="$DEFAULT_SLUG"
  local failed_only=false

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --job|-j)        require_value "$1" "${2-}"; job_number="$2"; shift 2 ;;
      --project|-p)    require_value "$1" "${2-}"; project="$2"; shift 2 ;;
      --failed-only|-f) failed_only=true; shift ;;
      --help|-h)
        echo "Usage: circleci.sh tests --job NUMBER [--project SLUG] [--failed-only]"
        echo "  --job, -j        Job number (required)"
        echo "  --project, -p    Project slug [default: $DEFAULT_SLUG]"
        echo "  --failed-only, -f Only show failed tests"
        exit 0 ;;
      *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
  done

  if [[ -z "$job_number" ]]; then
    echo "Error: --job is required" >&2; exit 1
  fi
  validate_positive_int "--job" "$job_number"
  validate_slug "$project"

  FAILED_ONLY="$failed_only" curl -sf --max-time 30 -H "$AUTH" "$BASE/project/$project/$job_number/tests" | python3 -c '
import json, os, sys
failed_only = os.environ.get("FAILED_ONLY") == "true"
data = json.load(sys.stdin)
items = data.get("items", [])
if failed_only:
    items = [t for t in items if t.get("status", "") in ("failure", "error")]
if not items:
    print("No test results found." if not failed_only else "No failed tests found.")
else:
    for t in items:
        status = t.get("status", "unknown")
        name = t.get("name", "unnamed")
        classname = t.get("classname", "")
        label = "[" + status + "] " + name
        if classname:
            label += " (" + classname + ")"
        print(label)
        if status != "success" and t.get("message"):
            lines = t["message"].strip().splitlines()[:5]
            for line in lines:
                print("    " + line)
            if len(t["message"].strip().splitlines()) > 5:
                print("    ... (truncated)")
'
}

# ── Dispatch ─────────────────────────────────────────────────────────
SUBCOMMAND="${1:-}"
shift || true

case "$SUBCOMMAND" in
  failed)    cmd_failed "$@" ;;
  workflows) cmd_workflows "$@" ;;
  jobs)      cmd_jobs "$@" ;;
  artifacts) cmd_artifacts "$@" ;;
  rerun)     cmd_rerun "$@" ;;
  cancel)    cmd_cancel "$@" ;;
  pipelines) cmd_pipelines "$@" ;;
  tests)     cmd_tests "$@" ;;
  flaky)     cmd_flaky "$@" ;;
  --help|-h|"")
    echo "Usage: circleci.sh <subcommand> [OPTIONS]"
    echo ""
    echo "Subcommands:"
    echo "  failed      Find most recent failed workflow"
    echo "  workflows   List workflows for a pipeline"
    echo "  jobs        List jobs in a workflow"
    echo "  artifacts   Get job artifacts"
    echo "  rerun       Rerun a workflow (mutation — confirm before running)"
    echo "  cancel      Cancel a running workflow (mutation — confirm before running)"
    echo "  pipelines   List recent pipelines"
    echo "  tests       Get test results for a job"
    echo "  flaky       Get flaky tests"
    echo ""
    echo "Run 'circleci.sh <subcommand> --help' for subcommand-specific options."
    ;;
  *) echo "Unknown subcommand: $SUBCOMMAND" >&2; exit 1 ;;
esac
