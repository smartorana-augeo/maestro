# Maestro Template

AI powered multi-repo orchestration template for Claude Code.

## How to Use This Template

This is an orchestrator layer that sits on top of your existing codebases. It does not replace your repos — it wraps them. You add your repositories as git submodules, and Maestro provides AI-powered workflows, commands, agents, and skills that work across all of them from a single context.

**Getting started:**

- Click **"Use this template"** on GitHub to create your own copy in your team's workspace.
- Add your repositories as submodules under the appropriate directories.
- See the [Local Setup](#local-setup) guide below on the new repo.
- Use the provided commands, skills, and agents as-is, or customize them to fit your workflow.

**Contributing back:**

If you build a command, skill, or agent that would be useful to other teams, upstream it. Open a PR against this template so the improvement is available to everyone. The more teams contribute, the more useful the shared tooling becomes.

**Copy/paste friendly:**

You are not required to adopt this template wholesale. If you only need a specific skill, command, or agent, copy it into your own setup. Everything is designed to be modular and self-contained enough to work independently.

**Audit before use:**

Some skills and scripts contain org-specific defaults (Grafana host URLs, datasource IDs, 1Password entry names, Atlassian domains, etc.) inherited from the team that built this template. After creating your repo from this template, audit `.claude/skills/` and any scripts under `.claude/skills/*/scripts/` and replace these values with your own. The agents are intentionally stack-agnostic and should not require changes.

## Directory Structure

```
maestro-template/
├── .claude/
│   ├── agents/          # Specialized agents by category
│   ├── commands/        # Slash commands for common workflows
│   └── skills/          # Domain-specific skill modules
├── docs/                # Documentation
├── memories/            # Persistent context (public/ + personal/)
├── personal/            # Personal scratch work (gitignored)
├── projects/            # Project tracking files
├── repositories/        # Git submodules for managed repos
├── todos/               # Task tracking files
├── setup.sh             # Interactive setup script (bash)
├── setup.js             # Interactive setup script (node)
├── .env.example         # Environment variable template
├── .mcp.json            # MCP server configuration
├── CLAUDE.md            # AI context file
└── MEMORY.md            # Auto-memory index file
```

## Prerequisites

After cloning this template, make sure you have the following installed before running setup:

- **Node.js** (>= 14.0.0) and **npm** — [nodejs.org](https://nodejs.org/)
- **GitHub CLI (`gh`)** — [cli.github.com](https://cli.github.com/) (requires Git)
  - **SSH connection with GitHub** — required for submodule operations. Run `gh auth login` and select SSH when prompted for git protocol. Verify with `gh auth status`.
- **Claude Code CLI** (recommended) — [claude.com/claude-code](https://claude.com/claude-code)

## Submodule Setup

> **One-time setup.** This only needs to be done once by the person creating the repo from the template. Once the submodules are committed and pushed, other team members just need to run `setup.sh` (or `git submodule update --init --recursive`) after cloning.

After creating your repo from the template and cloning it, add each repository you want Maestro to manage:

```bash
git submodule add git@github.com:YOUR_ORG/REPO_NAME.git repositories/REPO_NAME
```

Then initialize, commit, and push:

```bash
git submodule update --init --recursive
git add .gitmodules repositories/
git commit -m "chore: add submodules"
git push
```

You can confirm submodules are registered by checking the `repositories/` directory.

## Local Setup

1. **Create your repo:**

   Click **"Use this template"** → **"Create a new repository"** on GitHub, then continue the rest of your setup in the new cloned repository.

2. **Run setup:**

   ```bash
   ./setup.sh
   # or
   node setup.js
   ```

3. **Configure environment:**
   Copy `.env.example` to `.env` and fill in your values:
   - `YOUR_NAME`, `YOUR_EMAIL`
   - `ATLASSIAN_EMAIL`, `ATLASSIAN_API_TOKEN`, `ATLASSIAN_DOMAIN`

   > **Note:** `.claude/settings.json` denies Claude's Read tool on `.env` to prevent explicit secret exposure. Scripts (e.g. `query_logs.sh`) can still source `.env` at runtime — the restriction only applies to Claude reading the file directly.

## Commands

Slash commands in `.claude/commands/`. Invoke with `/<name>` in Claude Code.

**Development:** `/generate-technical-plan`, `/research`, `/generate-test-suite`, `/review-pr`, `/generate-release-plan`, `/commit`, `/open-pr`, `/refresh-pr-description`

**Workflow:** `/start-todo`, `/start-project`, `/memory`, `/generate-jira-ticket`, `/generate-sprint-report`, `/refresh-git`, `/refresh-workspace-docs`

See [commands README](.claude/commands/README.md) for descriptions.

## Skills

Skills in `.claude/skills/` provide domain-specific knowledge, used automatically when relevant:

- **circle-ci** — CircleCI pipeline investigation and management
- **confluence-doc** — Confluence page creation from projects and plans
- **grafana-logs** — Grafana Cloud Loki log querying
- **skill-creator** — Guidance for creating new skills
- **tempo** — Tempo time tracking from calendar events
- **testrail** — TestRail project, suite, section, and test case browsing and creation

## Agents

Specialized agents organized by category. See [agents README](.claude/agents/README.md) for the full list.

| Category     | Agents                                                                                                                                       |
| ------------ | -------------------------------------------------------------------------------------------------------------------------------------------- |
| workflow     | felix, project-manager, debugger, git-workflow-manager, github-actions-expert, documentation-engineer                                        |
| architecture | technical-architect, cloud-architect                                                                                                         |
| quality      | code-reviewer, refactoring-specialist, ux-researcher, chaos-engineer                                                                         |
| frameworks   | nextjs-expert, playwright-expert, graphql-expert, typescript-expert                                                                          |
| database     | mongodb-expert, postgres-expert, sql-pro                                                                                                     |
| development  | ui-ux-designer, js-node-developer, js-react-developer, js-reactnative-developer, fullstack-developer, dotnet-developer, coldfusion-developer |
| devops       | bash-expert, grafana-expert, loki-expert                                                                                                     |

## Integrations

- **MCP (.mcp.json):** Atlassian (Jira, Confluence), GitHub, Context7

## Public vs Personal

Some content directories (e.g. `memories/`) contain both a `public/` and `personal/` subdirectory.

- **`public/`** — Committed to git and shared with the team. Use for anything that benefits others: shared memories, reusable scripts, team-wide project tracking.
- **`personal/`** — Gitignored. Use for your own notes, drafts, scratch work, or anything you don't want committed. Your personal files stay local to your machine.

This convention lets everyone use the same workspace structure without stepping on each other's files.

## File Naming

- Projects, todos, memories, ideas: `YYYY-MM-DD-descriptive-name.{project|todo|memory|idea}.md`
- Investigations: `YYYY-MM-DD-TICKET-ID-description.md`
