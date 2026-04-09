# Commands

Custom slash commands for common workflows. Invoke with `/<name>` in Claude Code.

## Development

- **`/generate-technical-plan`** — Create comprehensive technical implementation plans for Jira tickets
- **`/research`** — Conduct research before technical planning
- **`/generate-test-suite`** — Generate comprehensive test strategies
- **`/review-pr`** — Perform detailed pull request reviews
- **`/generate-release-plan`** — Create release and deployment plans
- **`/commit`** — Create well-formatted git commits with conventional commit messages
- **`/open-pr`** — Create a pull request using GitHub CLI
- **`/refresh-pr-description`** — Update an existing PR's title and description to reflect current branch state

## Workflow

- **`/start-todo`** — Create and track individual tasks
- **`/start-project`** — Track projects with milestones
- **`/memory`** — Store important context that should persist
- **`/generate-jira-ticket`** — Draft detailed Jira tickets
- **`/generate-sprint-report`** — Generate sprint summary reports from Jira data, publish to Confluence
- **`/refresh-git`** — Pull latest changes from master and clean up merged branches
- **`/refresh-workspace-docs`** — Scan directory and update all READMEs and CLAUDE.md to match current state

Each command has a detailed `.md` file in this directory with full instructions.
