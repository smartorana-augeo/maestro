---
name: github-submodules
description: >-
  Manages maestro repository submodules using the GitHub REST API. Use this skill
  proactively whenever the user needs to clone, update, or check the status of
  repositories under maestro's repositories/ directory. Also trigger when the user
  mentions submodule synchronization, updating repo references, managing maestro
  dependencies, or asks "are submodules up to date" / "clone the repos" / "update
  submodule refs" — especially in environments where SSH-based git submodule
  commands are unavailable.
---

# GitHub Submodules

Clone and manage maestro submodules via the GitHub REST API when SSH-based `git submodule update` is unavailable. Use `submodules.sh` for all operations.

## Execution Behavior

Read-only subcommands (`status`, `list`, `find-pr`) execute immediately without confirmation. Content operations (`clone`, `update`, `update-refs`) download or modify repository content — confirm when operating on all submodules at once. Write subcommands (`push`, `create-pr`, `checkout-branch`) affect git state — confirm with the user before running.

## Authentication

Token sources (priority order):

1. `GITHUB_TOKEN` environment variable
2. Maestro `.env` file (`GITHUB_TOKEN=...`)

Public repos work without a token. Private Structuralapp repos require one.

### Required Token Permissions

For a **fine-grained PAT** (recommended), grant these permissions on the target repositories:

| Permission        | Access         | Required for                                      |
| ----------------- | -------------- | ------------------------------------------------- |
| **Contents**      | Read and write | `clone`, `update`, `push`                         |
| **Pull requests** | Read and write | `find-pr`, `create-pr`                            |
| **Metadata**      | Read-only      | Always required for fine-grained PATs (automatic) |

For a **classic PAT**, the `repo` scope covers all operations.

Without "Pull requests" permission, `find-pr` and `create-pr` will fail with `403 Resource not accessible by personal access token`.

## Commands

```bash
bash .claude/skills/github-submodules/scripts/submodules.sh <command> [REPO...]
```

| Command       | Description                                                                               | Example                                  |
| ------------- | ----------------------------------------------------------------------------------------- | ---------------------------------------- |
| `update-refs` | Update maestro's gitlink refs to each repo's current remote HEAD SHA (no download needed) | `submodules.sh update-refs`              |
| `clone`       | Download repos via GitHub API tarball endpoint                                            | `submodules.sh clone ambassador nextweb` |
| `update`      | Pull latest content for already-cloned repos                                              | `submodules.sh update ambassador`        |
| `status`      | Show clone status and branch for all repos                                                | `submodules.sh status`                   |
| `list`        | List all submodules defined in `.gitmodules`                                              | `submodules.sh list`                     |

When no repo names are given, `update-refs`, `clone`, and `update` operate on all submodules. `maestro-template` is automatically excluded from all operations.

**Use `update-refs` for automated reference updates** (e.g. the scheduled trigger). It is the API-only equivalent of `git submodule update --remote` — no tarballs, no synthetic commits, just real remote SHAs.

## PR Management Commands

```bash
bash .claude/skills/github-submodules/scripts/submodules.sh <command> [args]
```

| Command                                     | Description                                                                                                                  | Example                                                                                 |
| ------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| `find-pr <PATTERN>`                         | Find open PR on maestro whose title matches PATTERN (case-insensitive). Prints branch to stdout; returns exit 1 if no match. | `submodules.sh find-pr "update submodules"`                                             |
| `create-pr <TITLE> [BODY] [--labels L1,L2]` | Create a draft PR on maestro from the current branch. Prints PR URL. Optionally adds labels.                                 | `submodules.sh create-pr "Update submodules" "" --labels "Ready for Review,submodules"` |
| `push`                                      | Push the current maestro branch via HTTPS using GITHUB_TOKEN.                                                                | `submodules.sh push`                                                                    |
| `checkout-branch <BRANCH>`                  | Switch to BRANCH on maestro, creating it if it doesn't exist.                                                                | `submodules.sh checkout-branch my-feature`                                              |

All write operations require `GITHUB_TOKEN` in the environment or maestro `.env` file.

### Push Workflow

Complete automated submodule reference update workflow (HTTPS + GitHub API only):

```bash
MAESTRO_ROOT="$(git rev-parse --show-toplevel)"
SUBMODULES="$MAESTRO_ROOT/.claude/skills/github-submodules/scripts/submodules.sh"
PR_TITLE="chore: update submodule references"

# 1. Check if a PR already exists; create or switch to working branch
branch="$(bash "$SUBMODULES" find-pr "$PR_TITLE" 2>/dev/null)"
if [[ -n "$branch" ]]; then
  bash "$SUBMODULES" checkout-branch "$branch"
  git -C "$MAESTRO_ROOT" pull origin "$branch" --rebase --no-recurse-submodules
else
  bash "$SUBMODULES" checkout-branch "update-submodules"
fi

# 2. Update submodule references to the real remote HEAD SHAs (no downloads)
bash "$SUBMODULES" update-refs

# 3. Exit early if no submodule refs changed
if git -C "$MAESTRO_ROOT" diff --cached --quiet -- repositories/; then
  echo "All submodules are up to date"
  exit 0
fi

# 4. Commit the staged submodule ref changes
git -C "$MAESTRO_ROOT" commit -m "$PR_TITLE"

# 5. Push branch
bash "$SUBMODULES" push

# 6. Create a draft PR (only if one didn't exist yet)
if [[ -z "$branch" ]]; then
  bash "$SUBMODULES" create-pr "$PR_TITLE" ""
fi
```

## When to Use Each Command

- **Not sure if a repo is cloned?** Run `status` first.
- **Repo missing from `repositories/`?** Use `clone`.
- **Repo already cloned but need latest?** Use `update`.
- **Need to know what submodules exist?** Use `list`.
- **Need to commit and PR submodule updates?** Use the Push Workflow above.

## Troubleshooting

- **`403 Resource not accessible by personal access token`** — token lacks required permissions; for fine-grained PAT, ensure Contents (read/write) and Pull requests (read/write) are granted on target repos
- **`404 Not Found`** — repository doesn't exist, is private, or token has no access
- **`401 Bad credentials`** — token is invalid or expired; regenerate and update `.env`
- **`jq: command not found`** — install jq (`brew install jq` on macOS, `apt install jq` on Linux); required for PR management commands
- **Network timeout** — API calls timeout after 30s; check connectivity or retry
- **Tarball extraction failed** — check disk space in `repositories/` directory
- **Empty status output** — `.gitmodules` may be missing or have no entries; run `list` to verify

## Exit Codes

| Code | Meaning                                                               |
| ---- | --------------------------------------------------------------------- |
| `0`  | Success (or `find-pr` found a matching PR)                            |
| `1`  | Error (missing config, API failure, no matching PR, or invalid input) |

## Discovery

This skill uses the GitHub REST API directly. For endpoint documentation and response schemas, see:

- [Repositories API](https://docs.github.com/en/rest/repos)
- [Git References API](https://docs.github.com/en/rest/git/refs)
- [Pull Requests API](https://docs.github.com/en/rest/pulls)

## Permissions

Entries in `.claude/settings.local.json` that allow this skill to run without approval:

```json
"Bash(bash .claude/skills/github-submodules/*)",
"Bash(bash .claude/skills/github-submodules/scripts/submodules.sh *)"
```
