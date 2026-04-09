# Create Technical Plan

Create a comprehensive technical implementation plan for a Jira ticket.

## Usage

When invoked, you'll be prompted for:

- JIRA_TICKET: The Jira ticket ID (e.g., ASC2-508)
- REPO_NAME: The target repository name (optional, defaults to current repository)

## Instructions

You are an Architect-level software engineer creating a technical plan.

### CRITICAL REQUIREMENTS:

1. **MANDATORY JIRA ACCESS** - You MUST successfully retrieve the Jira ticket details before proceeding. If you cannot access the Jira ticket details, STOP and report the failure - do not proceed with creating the plan
2. **Use claude.ai Atlassian Connector First** - If the claude.ai Atlassian MCP tools are available (e.g. `mcp__claude_ai_Atlassian__getJiraIssue`), use those to get details for any ticket on Jira or page on Confluence
3. **Fallback: Atlassian Skill** - If the connector is not available, use the `atlassian` skill which calls the Atlassian REST API via shell scripts. This requires `ATLASSIAN_EMAIL`, `ATLASSIAN_API_TOKEN`, and `ATLASSIAN_DOMAIN` in the project `.env` file
4. **No Plan Without Jira Data** - Never proceed with creating the plan if you cannot retrieve the Jira ticket information

### Context Locations

- **Code**: Look in the `repositories/{repo-name}` folder
- **Documentation**: Check the `repositories/docs` repo for overall system documentation
- **Research**: Check `todos/public/` and `memories/public/` for existing research on this ticket
- **Confluence**: https://augeomarketing.atlassian.net/wiki/spaces/PD/overview

### Step 1: Retrieve Jira Ticket Information

**MANDATORY**: First, you MUST successfully retrieve the Jira ticket details.

- Try the claude.ai Atlassian connector (MCP tools) first
- If unavailable, use the `atlassian` skill (requires `.env` credentials)
- If all fail, STOP and report the failure - do not proceed

### Step 2: Review Existing Research

Check if research or memory documents exist for this ticket in:

- `todos/public/`
- `memories/public/`

Use these findings to inform your technical plan.

### Step 3: Create Technical Plan

Analyze the current codebase and provide:

#### Overview

- Brief description of the ticket requirements
- Scope and boundaries of the implementation
- Success criteria and acceptance criteria

#### Technical Analysis

- Current system architecture relevant to this ticket
- Dependencies and integration points
- Data flow and system interactions
- Performance considerations

#### Implementation Strategy

- High-level approach and methodology

#### Detailed Implementation Plan

- Step-by-step implementation phases
- File and component changes required
- Database schema changes (if applicable)
- API changes and new endpoints
- Frontend/UI changes (if applicable)

#### Testing Strategy

- Unit testing requirements
- Integration testing approach
- End-to-end testing scenarios
- Performance testing considerations
- Security testing requirements

#### Deployment & Rollout

- Deployment strategy
- Configuration changes required
- Database migrations
- Rollback plan
- Monitoring and observability

### Step 4: Save as Project

Create a project file in `projects/public/` with naming convention:
`YYYY-MM-DD-{JIRA_TICKET}-technical-plan.project.md`

Include YAML frontmatter:

```yaml
---
title: {JIRA_TICKET} Technical Plan
description: Technical implementation plan for {ticket summary}
status: planning
priority: {from jira}
owner: {from jira}
created: {today}
tags: [technical-plan, {repo-name}, {jira-ticket}]
jira_ticket: {JIRA_TICKET}
repository: {REPO_NAME}
---
```
