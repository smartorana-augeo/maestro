#!/usr/bin/env bash
# submodules.sh — Clone and manage maestro submodules via GitHub REST API
set -Eeuo pipefail
# inherit_errexit requires bash 4.4+; macOS ships bash 3.2
if (( BASH_VERSINFO[0] > 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] >= 4) )); then
  shopt -s inherit_errexit
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
MAESTRO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
GITMODULES="$MAESTRO_ROOT/.gitmodules"
API_BASE="https://api.github.com"

# Repos to always skip
SKIP_REPOS=("maestro-template")

# Resolve GitHub token from environment or .env file
resolve_token() {
  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    printf '%s\n' "$GITHUB_TOKEN"
    return
  fi
  # Try maestro .env file
  if [[ -f "$MAESTRO_ROOT/.env" ]]; then
    local token
    token="$(grep -E '^GITHUB_TOKEN=' "$MAESTRO_ROOT/.env" 2>/dev/null | cut -d= -f2- | tr -d '"' | tr -d "'")" || true
    if [[ -n "$token" ]]; then
      printf '%s\n' "$token"
      return
    fi
  fi
  printf '\n'
}

# Build auth header if token is available
auth_header() {
  local token
  token="$(resolve_token)"
  if [[ -n "$token" ]]; then
    echo "Authorization: Bearer $token"
  else
    echo ""
  fi
}

# Make an authenticated GitHub API request
gh_api() {
  local url="$1"
  shift
  local auth
  auth="$(auth_header)"
  if [[ -n "$auth" ]]; then
    curl -sL --connect-timeout 10 -H "$auth" -H "Accept: application/vnd.github+json" "$@" "$url"
  else
    curl -sL --connect-timeout 10 -H "Accept: application/vnd.github+json" "$@" "$url"
  fi
}

usage() {
  cat <<'USAGE'
Usage: submodules.sh <command> [options]

Commands:
  clone [REPO...]          Download submodules via GitHub API. Clones all if no repos specified.
  update [REPO...]         Checkout default branch and pull latest for cloned submodules.
  update-refs [REPO...]    Update maestro's submodule gitlink references to each repo's current
                           remote HEAD SHA. API-only equivalent of `git submodule update --remote`.
                           Does not clone or download content. Use this for automated reference updates.
  status                   Show status of all submodules (cloned / not cloned).
  list                     List all submodules defined in .gitmodules.
  find-pr <PATTERN>        Find an open PR on maestro whose title matches PATTERN (case-insensitive).
                           Prints the branch name to stdout. Exit 0 if found, exit 1 if not.
  create-pr <TITLE> [BODY] [--labels L1,L2] Create a draft PR on maestro from the current branch.
                           Prints the PR URL to stdout. Labels are added after creation.
  push                     Push the current maestro branch via HTTPS using GITHUB_TOKEN.
  checkout-branch <BRANCH> Switch to BRANCH on maestro, creating it if it doesn't exist.

Options:
  --help              Show this help message.

Environment:
  GITHUB_TOKEN        GitHub personal access token. Required for private repos
                      and all write operations (find-pr, create-pr, push).
                      Can also be set in maestro's .env file.

Examples:
  submodules.sh clone                              # Clone all submodules
  submodules.sh clone ambassador nextweb           # Clone specific submodules
  submodules.sh update ambassador nextweb          # Pull latest for specific repos
  submodules.sh update                             # Pull latest for all cloned repos
  submodules.sh update-refs                        # Update all submodule refs to remote HEAD
  submodules.sh update-refs ambassador nextweb     # Update specific submodule refs
  submodules.sh status                             # Show clone status
  submodules.sh find-pr "update submodules"        # Find open PR by title pattern
  submodules.sh checkout-branch update-submodules  # Create/switch to a branch
  submodules.sh push                               # Push current branch via HTTPS
  submodules.sh create-pr "Update submodules" ""   # Create a draft PR
  submodules.sh create-pr "Update submodules" "" --labels "Ready for Review,submodules"
USAGE
}

# Parse .gitmodules into parallel arrays
# TODO: Read submodule.<name>.branch from .gitmodules and prefer it over
#       get_default_branch() when set. Not needed yet — no submodules currently
#       configure a tracked branch.
declare -a SUB_NAMES=()
declare -a SUB_PATHS=()
declare -a SUB_URLS=()

parse_gitmodules() {
  if [[ ! -f "$GITMODULES" ]]; then
    echo "Error: .gitmodules not found at $GITMODULES" >&2
    exit 1
  fi

  local names
  names="$(git config --file "$GITMODULES" --get-regexp 'submodule\..*\.path' | awk '{sub(/^submodule\./, "", $1); sub(/\.path$/, "", $1); print $1}')"

  while IFS= read -r name; do
    [[ -z "$name" ]] && continue
    local path url
    path="$(git config --file "$GITMODULES" --get "submodule.${name}.path")"
    url="$(git config --file "$GITMODULES" --get "submodule.${name}.url")"
    SUB_NAMES+=("$name")
    SUB_PATHS+=("$path")
    SUB_URLS+=("$url")
  done <<< "$names"
}

# Extract org/repo from a GitHub URL (SSH, HTTPS, or local proxy)
extract_nwo() {
  local url="$1"
  local nwo=""
  if [[ "$url" =~ github\.com[:/]([^/]+/[^/]+)$ ]]; then
    nwo="${BASH_REMATCH[1]}"
    nwo="${nwo%.git}"
  elif [[ "$url" =~ /git/([^/]+/[^/]+)$ ]]; then
    # Local proxy format: http://local_proxy@127.0.0.1:<port>/git/<org>/<repo>
    nwo="${BASH_REMATCH[1]}"
    nwo="${nwo%.git}"
  fi
  echo "$nwo"
}

short_name() {
  basename "$1"
}

should_skip() {
  local name="$1"
  for skip in "${SKIP_REPOS[@]}"; do
    if [[ "$name" == "$skip" ]]; then
      return 0
    fi
  done
  return 1
}

filter_repos() {
  local -a requested=("$@")
  local -a indices=()

  for i in "${!SUB_NAMES[@]}"; do
    local sname
    sname="$(short_name "${SUB_PATHS[$i]}")"

    if should_skip "$sname"; then
      continue
    fi

    if [[ ${#requested[@]} -eq 0 ]]; then
      indices+=("$i")
    else
      for req in "${requested[@]}"; do
        if [[ "$sname" == "$req" ]]; then
          indices+=("$i")
          break
        fi
      done
    fi
  done

  if [[ ${#indices[@]} -gt 0 ]]; then
    echo "${indices[@]}"
  fi
}

# Get the default branch for a repo via the API
get_default_branch() {
  local nwo="$1"
  local response branch
  response="$(gh_api "$API_BASE/repos/$nwo")"
  if command -v jq &>/dev/null; then
    branch="$(printf '%s' "$response" | jq -r '.default_branch // empty')"
  else
    branch="$(printf '%s' "$response" | grep -o '"default_branch":"[^"]*"' | cut -d'"' -f4)"
  fi
  if [[ -z "$branch" ]]; then
    echo "Warning: Could not determine default branch for $nwo, falling back to 'master'" >&2
    branch="master"
  fi
  echo "$branch"
}

require_jq() {
  if ! command -v jq &>/dev/null; then
    echo "Error: jq is required for this operation." >&2
    echo "Install via: brew install jq (macOS) or apt-get install jq (Linux)" >&2
    exit 1
  fi
}

require_token() {
  local token
  token="$(resolve_token)"
  if [[ -z "$token" ]]; then
    echo "Error: GITHUB_TOKEN required for this operation." >&2
    echo "Set GITHUB_TOKEN in environment or maestro .env file." >&2
    exit 1
  fi
  echo "$token"
}

get_maestro_nwo() {
  local remote_url
  remote_url="$(git -C "$MAESTRO_ROOT" remote get-url origin 2>/dev/null)" || {
    echo "Error: Could not get maestro remote URL" >&2; return 1
  }
  local nwo
  nwo="$(extract_nwo "$remote_url")"
  if [[ -z "$nwo" ]]; then
    echo "Error: Could not parse org/repo from: $remote_url" >&2; return 1
  fi
  echo "$nwo"
}

cmd_clone() {
  local -a repos=("$@")
  local -a indices=()
  local _filter_out
  _filter_out="$(filter_repos ${repos[@]+"${repos[@]}"})"
  if [[ -n "$_filter_out" ]]; then
    read -ra indices <<< "$_filter_out"
  fi

  if [[ ${#indices[@]} -eq 0 ]]; then
    echo "No matching submodules found."
    return 1
  fi

  # Check auth status
  local token
  token="$(resolve_token)"
  if [[ -z "$token" ]]; then
    echo "Warning: No GITHUB_TOKEN found. Only public repos will work." >&2
    echo "Set GITHUB_TOKEN in environment or maestro .env file for private repos." >&2
    echo ""
  fi

  local cloned=0 skipped=0 failed=0

  local tmp_dir
  tmp_dir="$(mktemp -d /tmp/submodule-XXXXXXXXXX)"
  trap 'rm -rf -- "$tmp_dir"' EXIT

  for i in "${indices[@]}"; do
    local sname path nwo target
    sname="$(short_name "${SUB_PATHS[$i]}")"
    path="${SUB_PATHS[$i]}"
    nwo="$(extract_nwo "${SUB_URLS[$i]}")"
    target="$MAESTRO_ROOT/$path"

    if [[ -d "$target" ]] && [[ -n "$(ls -A "$target" 2>/dev/null)" ]]; then
      echo "-- $sname — already cloned at $path"
      skipped=$((skipped + 1))
      continue
    fi

    if [[ -z "$nwo" ]]; then
      echo "!! $sname — could not parse GitHub org/repo from URL: ${SUB_URLS[$i]}"
      failed=$((failed + 1))
      continue
    fi

    if [[ ! "$nwo" =~ ^[a-zA-Z0-9._-]+/[a-zA-Z0-9._-]+$ ]]; then
      echo "!! $sname — invalid repo path: $nwo" >&2
      failed=$((failed + 1))
      continue
    fi

    # Get default branch
    local branch
    branch="$(get_default_branch "$nwo")"
    echo ">> Cloning $nwo ($branch) -> $path ..."

    # Clean up empty directory if it exists
    if [[ -d "$target" ]]; then
      rm -rf -- "$target"
    fi
    mkdir -p "$target"

    # Download tarball and extract
    local tarball_url tmp_file http_code
    tarball_url="$API_BASE/repos/$nwo/tarball/$branch"
    tmp_file="$tmp_dir/$(basename "$sname").tar.gz"
    http_code="$(gh_api "$tarball_url" -o "$tmp_file" -w "%{http_code}")"

    if [[ "$http_code" != "200" ]]; then
      echo "!! $sname — download failed (HTTP $http_code)"
      rm -f -- "$tmp_file"
      failed=$((failed + 1))
      continue
    fi

    # Extract tarball (strip the top-level directory GitHub adds)
    if tar xzf "$tmp_file" --strip-components=1 -C "$target" 2>&1; then
      rm -f -- "$tmp_file"

      # Initialize as a git repo with the remote set
      (
        cd "$target"
        git init -q
        git remote add origin "https://github.com/$nwo.git"
        git add -A
        git commit -q -m "Initial clone from $nwo ($branch)" --allow-empty
        git branch -M "$branch"
      )

      echo "OK $sname cloned ($branch)"
      cloned=$((cloned + 1))
    else
      echo "!! $sname — extract failed"
      rm -f -- "$tmp_file"
      failed=$((failed + 1))
    fi
  done

  echo ""
  echo "Done: $cloned cloned, $skipped already present, $failed failed"
}

cmd_update() {
  local -a repos=("$@")
  local -a indices=()
  local _filter_out
  _filter_out="$(filter_repos ${repos[@]+"${repos[@]}"})"
  if [[ -n "$_filter_out" ]]; then
    read -ra indices <<< "$_filter_out"
  fi

  if [[ ${#indices[@]} -eq 0 ]]; then
    echo "No matching submodules found."
    return 1
  fi

  local token
  token="$(resolve_token)"
  if [[ -z "$token" ]]; then
    echo "Warning: No GITHUB_TOKEN found. Only public repos will work." >&2
    echo ""
  fi

  local updated=0 skipped=0 failed=0

  local tmp_dir
  tmp_dir="$(mktemp -d /tmp/submodule-XXXXXXXXXX)"
  trap 'rm -rf -- "$tmp_dir"' EXIT

  for i in "${indices[@]}"; do
    local sname path nwo target
    sname="$(short_name "${SUB_PATHS[$i]}")"
    path="${SUB_PATHS[$i]}"
    nwo="$(extract_nwo "${SUB_URLS[$i]}")"
    target="$MAESTRO_ROOT/$path"

    if [[ ! -d "$target/.git" ]]; then
      echo "-- $sname — not cloned (run 'clone' first)"
      skipped=$((skipped + 1))
      continue
    fi

    if [[ -z "$nwo" ]]; then
      echo "!! $sname — could not parse GitHub org/repo from URL: ${SUB_URLS[$i]}"
      failed=$((failed + 1))
      continue
    fi

    if [[ ! "$nwo" =~ ^[a-zA-Z0-9._-]+/[a-zA-Z0-9._-]+$ ]]; then
      echo "!! $sname — invalid repo path: $nwo" >&2
      failed=$((failed + 1))
      continue
    fi

    echo ">> Updating $sname ..."

    # Get default branch from API
    local branch
    branch="$(get_default_branch "$nwo")"

    # Download fresh tarball
    local tarball_url tmp_file http_code
    tarball_url="$API_BASE/repos/$nwo/tarball/$branch"
    tmp_file="$tmp_dir/$(basename "$sname").tar.gz"
    http_code="$(gh_api "$tarball_url" -o "$tmp_file" -w "%{http_code}")"

    if [[ "$http_code" != "200" ]]; then
      echo "!! $sname — download failed (HTTP $http_code)"
      rm -f -- "$tmp_file"
      failed=$((failed + 1))
      continue
    fi

    # Get the real HEAD commit SHA for this branch from GitHub API
    # This must be done BEFORE extracting the tarball so the submodule
    # reference in maestro points to the actual remote commit, not a
    # local synthetic commit created by the tarball extraction.
    local real_sha branch_response
    branch_response="$(gh_api "$API_BASE/repos/$nwo/branches/$branch")"
    if command -v jq &>/dev/null; then
      real_sha="$(printf '%s' "$branch_response" | jq -r '.commit.sha // empty')"
    else
      real_sha="$(printf '%s' "$branch_response" | grep -o '"sha":"[^"]*"' | head -1 | cut -d'"' -f4)"
    fi

    if [[ -n "$(git -C "$target" status --porcelain --untracked-files=all)" ]]; then
      echo "!! $sname — local changes present; refusing to overwrite" >&2
      rm -f -- "$tmp_file"
      failed=$((failed + 1))
      continue
    fi

    # Clear working tree (keep .git), extract fresh content
    if (
      cd "$target" || { echo "!! Failed to cd to $target" >&2; exit 1; }
      # Remove everything except .git
      find . -maxdepth 1 ! -name '.' ! -name '.git' -exec rm -rf -- {} +
      # Extract new content
      tar xzf "$tmp_file" --strip-components=1 -C .
      rm -f -- "$tmp_file"
      # Stage and commit the update
      git add -A
      if git diff --cached --quiet; then
        echo "   Already up to date."
      else
        git commit -q -m "Update from $nwo ($branch) $(date +%Y-%m-%d)"
      fi
      git branch -M "$branch"
    ); then
      # Update the parent repo's submodule reference to the real remote commit SHA.
      # The tarball extraction creates a local commit with a different SHA — using
      # update-index ensures maestro points to the actual commit on GitHub.
      if [[ -n "$real_sha" && "$real_sha" != "null" ]]; then
        git -C "$MAESTRO_ROOT" update-index --cacheinfo "160000,$real_sha,$path"
        echo "OK $sname updated ($branch @ ${real_sha:0:7})"
      else
        echo "OK $sname updated ($branch, warning: could not get real SHA)"
      fi
      updated=$((updated + 1))
    else
      echo "!! $sname — update failed"
      rm -f -- "$tmp_file"
      failed=$((failed + 1))
    fi
  done

  echo ""
  echo "Done: $updated updated, $skipped not cloned, $failed failed"
}

cmd_status() {
  printf "%-25s %-10s %s\n" "SUBMODULE" "STATUS" "BRANCH"
  printf "%-25s %-10s %s\n" "---------" "------" "------"

  for i in "${!SUB_NAMES[@]}"; do
    local sname path target status branch
    sname="$(short_name "${SUB_PATHS[$i]}")"
    path="${SUB_PATHS[$i]}"
    target="$MAESTRO_ROOT/$path"

    if should_skip "$sname"; then
      status="skipped"
      branch="-"
    elif [[ -d "$target/.git" ]]; then
      status="cloned"
      branch="$(cd "$target" && git branch --show-current 2>/dev/null || echo "detached")"
    elif [[ -d "$target" ]] && [[ -n "$(ls -A "$target" 2>/dev/null)" ]]; then
      status="cloned"
      branch="unknown"
    else
      status="missing"
      branch="-"
    fi

    printf "%-25s %-10s %s\n" "$sname" "$status" "$branch"
  done
}

cmd_list() {
  for i in "${!SUB_NAMES[@]}"; do
    local sname nwo
    sname="$(short_name "${SUB_PATHS[$i]}")"
    nwo="$(extract_nwo "${SUB_URLS[$i]}")"
    echo "$sname  ($nwo)"
  done
}

cmd_find_pr() {
  local pattern="${1:-}"
  if [[ -z "$pattern" ]]; then
    echo "Error: pattern is required for find-pr" >&2
    exit 1
  fi
  require_jq
  local nwo token response api_error branch
  token="$(require_token)"
  nwo="$(get_maestro_nwo)"
  response="$(gh_api "$API_BASE/repos/$nwo/pulls?state=open&per_page=100")"
  # Check for API error response (object with "message" key instead of array)
  api_error="$(printf '%s' "$response" | jq -r 'if type == "object" and .message then .message else empty end' 2>/dev/null)"
  if [[ -n "$api_error" ]]; then
    echo "Error: GitHub API error: $api_error" >&2
    exit 1
  fi
  branch="$(printf '%s' "$response" | jq -r --arg pat "$pattern" \
    '.[] | select(.title | ascii_downcase | contains($pat | ascii_downcase)) | .head.ref' \
    | head -1)"
  if [[ -z "$branch" ]]; then
    return 1
  fi
  printf '%s\n' "$branch"
}

cmd_create_pr() {
  local title="" body="" labels=""
  # Parse positional args and flags
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --labels)
        [[ $# -ge 2 && "$2" != --* ]] || { echo "Error: --labels requires a value" >&2; exit 1; }
        labels="$2"
        shift 2
        ;;
      --*)
        echo "Unknown argument: $1" >&2
        exit 1
        ;;
      *)
        if [[ -z "$title" ]]; then title="$1"
        elif [[ -z "$body" ]]; then body="$1"
        else echo "Unknown argument: $1" >&2; exit 1
        fi
        shift ;;
    esac
  done
  if [[ -z "$title" ]]; then
    echo "Error: title is required for create-pr" >&2
    exit 1
  fi
  require_jq
  local token nwo head base payload response pr_url pr_number
  token="$(require_token)"
  nwo="$(get_maestro_nwo)"
  head="$(git -C "$MAESTRO_ROOT" branch --show-current)"
  base="$(get_default_branch "$nwo")"
  payload="$(jq -n \
    --arg title "$title" \
    --arg body "$body" \
    --arg head "$head" \
    --arg base "$base" \
    '{title: $title, body: $body, head: $head, base: $base, draft: true}')"
  response="$(gh_api "$API_BASE/repos/$nwo/pulls" \
    -X POST \
    -H "Content-Type: application/json" \
    -d "$payload")"
  pr_url="$(printf '%s' "$response" | jq -r '.html_url // empty')"
  if [[ -z "$pr_url" ]]; then
    echo "Error: PR creation failed. Response:" >&2
    printf '%s\n' "$response" | jq . 2>/dev/null || printf '%s\n' "$response" >&2
    exit 1
  fi
  printf '%s\n' "$pr_url"

  # Add labels if requested
  if [[ -n "$labels" ]]; then
    pr_number="$(printf '%s' "$response" | jq -r '.number')"
    local labels_json
    labels_json="$(printf '%s' "$labels" | jq -R 'split(",") | map(gsub("^\\s+|\\s+$"; ""))')"
    local label_payload
    label_payload="$(jq -n --argjson labels "$labels_json" '{labels: $labels}')"
    local label_response
    label_response="$(gh_api "$API_BASE/repos/$nwo/issues/$pr_number/labels" \
      -X POST \
      -H "Content-Type: application/json" \
      -d "$label_payload")"
    if printf '%s' "$label_response" | jq -e '.[0].name' >/dev/null 2>&1; then
      echo "Labels added: $labels" >&2
    else
      echo "Warning: failed to add labels. Response:" >&2
      printf '%s\n' "$label_response" | jq . 2>/dev/null || printf '%s\n' "$label_response" >&2
    fi
  fi
}

cmd_push() {
  local token nwo branch remote_url output askpass
  token="$(require_token)"
  nwo="$(get_maestro_nwo)"
  branch="$(git -C "$MAESTRO_ROOT" branch --show-current)"
  if [[ -z "$branch" ]]; then
    echo "Error: Could not determine current branch (detached HEAD?)" >&2
    exit 1
  fi
  # Use origin's remote URL if it's already HTTP(S) (e.g. CCR local proxy);
  # only construct HTTPS+token URL when origin is SSH (local dev).
  local origin_url
  origin_url="$(git -C "$MAESTRO_ROOT" remote get-url origin 2>/dev/null)" || origin_url=""
  if [[ "$origin_url" =~ ^https?:// ]]; then
    remote_url="$origin_url"
  else
    remote_url="https://github.com/${nwo}.git"
  fi
  printf '>> Pushing branch '\''%s'\'' to %s ...\n' "$branch" "$nwo"
  # Provide token via GIT_ASKPASS (temp script) — works in both local and CCR envs:
  # - CCR: environment's credential helper provides creds; askpass is unused fallback
  # - Local: no HTTPS creds configured; askpass provides the PAT
  # Do NOT clear credential.helper — CCR environments need their built-in helper
  local askpass_dir askpass
  askpass_dir="$(mktemp -d)"
  trap 'rm -rf -- "$askpass_dir"' RETURN EXIT
  askpass="${askpass_dir}/askpass"
  printf '#!/bin/sh\nprintf "%%s\\n" "%s"\n' "$token" > "$askpass"
  chmod 700 "$askpass"
  if output="$(GIT_ASKPASS="$askpass" GIT_TERMINAL_PROMPT=0 git -C "$MAESTRO_ROOT" \
    push "$remote_url" "HEAD:refs/heads/$branch" 2>&1)"; then
    printf '%s\n' "$output"
    printf 'OK pushed '\''%s'\''\n' "$branch"
  else
    printf '%s\n' "$output" >&2
    echo "Error: push failed" >&2
    exit 1
  fi
}

cmd_checkout_branch() {
  local branch="${1:-}"
  if [[ -z "$branch" ]]; then
    echo "Error: branch name is required for checkout-branch" >&2
    exit 1
  fi
  # Reject branch names that could be interpreted as git flags
  if [[ "$branch" == -* ]]; then
    echo "Error: branch name must not start with '-': $branch" >&2
    exit 1
  fi
  if git -C "$MAESTRO_ROOT" show-ref --verify --quiet "refs/heads/$branch" 2>/dev/null; then
    git -C "$MAESTRO_ROOT" checkout "$branch"
  elif git -C "$MAESTRO_ROOT" show-ref --verify --quiet "refs/remotes/origin/$branch" 2>/dev/null; then
    git -C "$MAESTRO_ROOT" checkout -b "$branch" --track "origin/$branch"
  else
    git -C "$MAESTRO_ROOT" checkout -b "$branch"
  fi
}

cmd_update_refs() {
  local -a repos=("$@")
  local -a indices=()
  local _filter_out
  _filter_out="$(filter_repos "${repos[@]+"${repos[@]}"}")"
  if [[ -n "$_filter_out" ]]; then
    read -ra indices <<< "$_filter_out"
  fi

  if [[ ${#indices[@]} -eq 0 ]]; then
    echo "No matching submodules found."
    return 1
  fi

  local updated=0 skipped=0 failed=0

  for i in "${indices[@]}"; do
    local sname path nwo branch sha branch_response
    sname="$(short_name "${SUB_PATHS[$i]}")"
    path="${SUB_PATHS[$i]}"
    nwo="$(extract_nwo "${SUB_URLS[$i]}")"

    if [[ -z "$nwo" ]]; then
      echo "!! $sname — could not parse GitHub org/repo from URL: ${SUB_URLS[$i]}"
      failed=$((failed + 1))
      continue
    fi

    if [[ ! "$nwo" =~ ^[a-zA-Z0-9._-]+/[a-zA-Z0-9._-]+$ ]]; then
      echo "!! $sname — invalid repo path: $nwo" >&2
      failed=$((failed + 1))
      continue
    fi

    branch="$(get_default_branch "$nwo")"
    branch_response="$(gh_api "$API_BASE/repos/$nwo/branches/$branch")"
    if command -v jq &>/dev/null; then
      sha="$(printf '%s' "$branch_response" | jq -r '.commit.sha // empty')"
    else
      sha="$(printf '%s' "$branch_response" | grep -o '"sha":"[^"]*"' | head -1 | cut -d'"' -f4)"
    fi

    if [[ -z "$sha" || "$sha" == "null" ]]; then
      echo "!! $sname — could not get HEAD SHA from GitHub API"
      failed=$((failed + 1))
      continue
    fi

    git -C "$MAESTRO_ROOT" update-index --cacheinfo "160000,$sha,$path"
    echo "OK $sname → ${sha:0:7} ($branch)"
    updated=$((updated + 1))
  done

  echo ""
  echo "Done: $updated updated, $skipped skipped, $failed failed"
}

# --- Main ---
if [[ $# -eq 0 ]] || [[ "$1" == "--help" ]]; then
  usage
  exit 0
fi

COMMAND="$1"
shift

case "$COMMAND" in
  clone)           parse_gitmodules; cmd_clone "$@" ;;
  update)          parse_gitmodules; cmd_update "$@" ;;
  update-refs)     parse_gitmodules; cmd_update_refs "$@" ;;
  status)          parse_gitmodules; cmd_status ;;
  list)            parse_gitmodules; cmd_list ;;
  find-pr)         cmd_find_pr "$@" ;;
  create-pr)       cmd_create_pr "$@" ;;
  push)            cmd_push ;;
  checkout-branch) cmd_checkout_branch "$@" ;;
  *)
    echo "Unknown command: $COMMAND" >&2
    usage
    exit 1
    ;;
esac
