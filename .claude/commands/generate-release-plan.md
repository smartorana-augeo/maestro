# Create Release Plan

Create a comprehensive release and deployment plan for a Jira ticket.

## Usage

When invoked, you'll be prompted for:

- JIRA_TICKET: The Jira ticket ID (e.g., ASC2-508)

## Instructions

You are a Release Manager and Technical Lead.

### CRITICAL REQUIREMENTS:

1. **Atlassian Access Required** - If the claude.ai Atlassian MCP tools are available (e.g. `mcp__claude_ai_Atlassian__getJiraIssue`), use those. Otherwise, use the `atlassian` skill which calls the Atlassian REST API via shell scripts (requires `ATLASSIAN_EMAIL`, `ATLASSIAN_API_TOKEN`, and `ATLASSIAN_DOMAIN` in the project `.env` file)
2. **Github Access Required** - You MUST have access to the Github MCP server
3. **Test Connectivity First** - Test connectivity by attempting to get user info from both services
4. **Fail Fast** - If neither Atlassian method works or Github isn't available, quit early and throw an error message

### Context Locations

- **Code**: Look in the `repositories/` folder
- **Architecture Docs**: https://github.com/Structuralapp/docs
- **Confluence**: https://augeomarketing.atlassian.net/wiki/spaces/PD/overview
- **Template**: https://augeomarketing.atlassian.net/wiki/spaces/PD/pages/9135390754/TM001+Testing+Plan+Template

### Release Overview

- Brief description of the ticket requirements and release scope
- Release objectives and success criteria
- Target audience and stakeholders
- Release timeline and milestones

### Pre-Release Analysis

- Current system state and baseline
- Dependencies and prerequisites
- Risk assessment and mitigation strategies
- Resource requirements and availability

### Release Strategy

- Release approach (phased, big bang, feature flags)
- Rollout plan and deployment strategy
- Environment preparation and configuration
- Data migration requirements (if applicable)

### Testing & Validation

- Pre-release testing requirements
- User acceptance testing plan
- Performance and security validation
- Rollback testing and procedures

### Deployment Plan

- Deployment sequence and steps
- Configuration changes and environment setup
- Database migrations and schema changes
- Monitoring and observability setup

### Communication & Documentation

- Stakeholder communication plan
- User documentation and training materials
- Technical documentation updates
- Change management and user adoption

### Post-Release Activities

- Monitoring and validation
- Performance metrics and KPIs
- User feedback collection
- Issue tracking and resolution

### Risk Management

- Identified risks and mitigation strategies
- Contingency plans and rollback procedures
- Success criteria and failure indicators
- Lessons learned and improvement opportunities

### Save as Project

Create a project file in `projects/public/` with naming convention:
`YYYY-MM-DD-{JIRA_TICKET}-release-plan.project.md`

Include YAML frontmatter:

```yaml
---
title: {JIRA_TICKET} Release Plan
description: Release plan for {ticket summary}
status: planning
priority: {from jira}
owner: {from jira}
created: {today}
tags: [release-plan, deployment, {jira-ticket}]
jira_ticket: {JIRA_TICKET}
---
```
