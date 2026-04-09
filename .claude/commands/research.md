# Conduct Research

Conduct comprehensive research for a technical implementation before creating a technical plan.

## Usage

When invoked, you'll be prompted for:

- JIRA_TICKET: The Jira ticket ID (e.g., ASC2-508)
- REPO_NAME: The target repository name (optional, defaults to current repository)

## Instructions

You are an Architect-level software engineer conducting research for a technical implementation.

### CRITICAL REQUIREMENTS:

1. **MANDATORY JIRA ACCESS** - You MUST successfully retrieve the Jira ticket details before proceeding. If you cannot access the Jira ticket details, STOP and report the failure
2. **Use claude.ai Atlassian Connector First** - If the claude.ai Atlassian MCP tools are available (e.g. `mcp__claude_ai_Atlassian__getJiraIssue`), use those to get details for any ticket on Jira or page on Confluence
3. **Fallback: Atlassian Skill** - If the connector is not available, use the `atlassian` skill which calls the Atlassian REST API via shell scripts. This requires `ATLASSIAN_EMAIL`, `ATLASSIAN_API_TOKEN`, and `ATLASSIAN_DOMAIN` in the project `.env` file
4. **No Research Without Jira Data** - Never proceed with creating the research if you cannot retrieve the Jira ticket information

### Context Locations

- **Code**: Look in the `repositories/{repo-name}` folder
- **Documentation**: Check the `repositories/docs` repo for overall system documentation
- **Confluence**: https://augeomarketing.atlassian.net/wiki/spaces/PD/overview

### Step 1: Retrieve Jira Ticket Information

**MANDATORY**: First, you MUST successfully retrieve the Jira ticket details.

- Try the claude.ai Atlassian connector (MCP tools) first
- If unavailable, use the `atlassian` skill (requires `.env` credentials)
- If all fail, STOP and report the failure - do not proceed

### Step 2: Conduct Research

Your research should identify and catalog all the documents, files, and resources that would be needed to create a comprehensive technical plan for this ticket.

#### Research Areas to Cover

**1. Jira Ticket Analysis**

- Ticket requirements and acceptance criteria
- Related tickets and dependencies
- Stakeholders and assignees
- Priority and timeline information

**2. Codebase Analysis**

- Relevant source code files and directories
- Database schemas and migrations
- API endpoints and services
- Configuration files
- Test files and test data

**3. Documentation Research**

- System architecture documentation
- API documentation
- Database schema documentation
- Deployment and infrastructure docs
- User guides and specifications

**4. Confluence Documentation**

- Project documentation spaces
- Technical specifications
- Process documentation
- Meeting notes and decisions

**5. External Dependencies**

- Third-party libraries and services
- External APIs and integrations
- Infrastructure dependencies
- Security and compliance requirements

#### Research Output Format

For each research area, provide:

- **File Paths**: Specific files that need to be examined
- **Documentation Links**: Confluence pages, external docs
- **Key Components**: Important code modules, services, databases
- **Dependencies**: Related systems, libraries, services
- **Stakeholders**: People who should be consulted
- **Timeline Considerations**: Any time-sensitive aspects

#### Research Summary

- **Critical Files**: Most important files that must be analyzed
- **Documentation Gaps**: Missing documentation that needs to be created
- **Knowledge Dependencies**: Information that requires human input
- **Research Completeness**: Assessment of whether sufficient information is available

### Step 3: Save as Memory

Create a memory document in `memories/public/` with naming convention:
`YYYY-MM-DD-{JIRA_TICKET}-research.memory.md`

Include YAML frontmatter:

```yaml
---
title: {JIRA_TICKET} Research
description: Research findings for {ticket summary}
created: {today}
tags: [research, {repo-name}, {jira-ticket}]
jira_ticket: {JIRA_TICKET}
repository: {REPO_NAME}
related_projects: []
---
```
