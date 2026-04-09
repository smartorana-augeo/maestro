# Maestro - AI Context

AI orchestration workspace for Claude Code. For setup, structure, and discovery see `README.md`.

## File Naming

- Projects, todos, memories, ideas: `YYYY-MM-DD-descriptive-name.{project|todo|memory|idea}.md`
- Investigations: `YYYY-MM-DD-TICKET-ID-description.md`
- Public/personal: `*/public/` = shared (committed), `*/personal/` = private (gitignored).

### Frontmatter

```yaml
---
title: Item title
description: Brief description
status: planning|active|paused|completed|pending|in_progress
priority: high|medium|low
owner: Person responsible
created: YYYY-MM-DD
due: YYYY-MM-DD (optional)
tags: [relevant, tags]
related_projects: [other-file-names]
jira_ticket: TICKET-123 (optional)
repository: repo-name (optional)
---
```

## Commands

`.claude/commands/` — Development and workflow slash commands. See `.claude/commands/README.md` for full list.

## Skills

`.claude/skills/` — Domain-specific knowledge modules (integrations, observability, tooling). See `.claude/skills/README.md` for full list.

## Agents

`.claude/agents/` — Organized by category (workflow, architecture, quality, frameworks, database, development, devops). See `.claude/agents/README.md` for full list.

## Integration

**MCP (.mcp.json):** Atlassian (Jira, Confluence), GitHub, Context7.

**Env (.env):** `YOUR_NAME`, `YOUR_EMAIL`, `ATLASSIAN_EMAIL`, `ATLASSIAN_API_TOKEN`, `ATLASSIAN_DOMAIN`, `CONTEXT7_API_KEY`, `TESTRAIL_EMAIL`, `TESTRAIL_API_KEY`, `TESTRAIL_DOMAIN`.

**Submodules:** `git submodule update --init --recursive` then `git submodule update --remote`.

**Default branch:** `master` (not `main`).

## Workflow & principles

### 1. Workflow orchestration (plan first)

- Every non-trivial task starts in plan mode. 3+ steps or any architectural decision → plan first.
- If something goes sideways mid-build, stop and re-plan. Don't keep pushing.
- Write detailed specs upfront. Ambiguity is the enemy of clean output.

### 2. Subagent strategy

- Use subagents to keep the main context window clean.
- Offload research, exploration, and parallel analysis to subagents.
- For complex problems, spin up multiple subagents. One task per subagent.
- Focused execution over cluttered multitasking.

### 3. Self-improvement loop

- After any correction from the user, update a lessons file (e.g. `memories/public/lessons.md`) with the pattern.
- Write rules that prevent the same mistake from happening again. Iterate until the mistake rate drops.
- Every session: review lessons relevant to the project. Compounding system — the longer you use it, the smarter it gets about your workflow.

### 4. Verification before done

- Never mark a task complete without proving it works.
- Diff behavior between master and your changes when relevant.
- Before presenting: "Would a staff engineer approve this?" Run tests. Check logs. Demonstrate correctness.
- No "it should work" — only "here is proof it works."

### 5. Demand elegance

- For non-trivial changes, pause: "Is there a more elegant way?"
- If a fix feels hacky: "Knowing everything I know now, implement the elegant solution."
- Skip this for simple, obvious fixes to avoid over-engineering.

### 6. Autonomous bug fixing

- When given a bug report, fix it. No hand-holding. Use logs, errors, failing tests; resolve directly.
- Fix failing CI without being told how. Zero context switching required from the user.

### 7. Opening PRs

- Always open PRs in **draft mode** (`gh pr create --draft`).
- Use the PR template defined in each repository, `pull_request_template.md`. Fill in each relevant section of the template.

### 8. External comments

- All content posted to external systems (GitHub PRs/issues/comments, Jira comments, Confluence pages and comments) must end with a signature line.
- If Maestro posts directly: `~Maestro`
- If a single agent was used: `~{agent-name} via Maestro` (e.g. `~Felix via Maestro`, `~react-developer via Maestro`)
- If multiple agents collaborated: `~Agent team ({agent1}, {agent2}) via Maestro` (e.g. `~Agent team (Felix, react-developer, backend-developer) via Maestro`)

### Task management

1. **Plan first:** Write plan to `todos/` (e.g. a todo file) or `projects/` (e.g. a project file) with checkable items.
2. **Verify plan:** Check in before starting implementation.
3. **Track progress:** Mark items complete as you go.
4. **Explain changes:** High-level summary at each step.
5. **Document results:** Add review section to the todo/project file.
6. **Capture lessons:** Update lessons (e.g. `memories/public/lessons.md`) after every correction.

### Core principles

- **Simplicity first:** Make every change as simple as possible. Impact minimal code.
- **No laziness:** Find root causes. No temporary fixes. Senior developer standards only.
- **Minimal impact:** Touch only what is necessary. Avoid introducing bugs.
- **Never write directly to main or master:** Every change has to go through a PR review process, never commit directly on master or main.
- **Never modify dependencies without approval:** Do not add, remove, or upgrade `dependencies` or `devDependencies` in `package.json`, or modify `package-lock.json` / `yarn.lock`, without explicit user approval.

## Tips

- Check `memories/public/` before starting; link work via frontmatter; use tags.
- Use Context7 MCP for lib/framework docs; if unavailable, web search.

## Repo-Specific

> Add any context specific to your repository below this line. Do not sync this section back to the template.
