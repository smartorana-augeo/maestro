# Create Project

Create a new project file to track a one-time initiative with milestones.

## Usage
When invoked, you'll be prompted for project details.

## Instructions

Create a new project file in `projects/public/` or `projects/personal/`.

### Naming Convention
`YYYY-MM-DD-descriptive-project-name.project.md`

### YAML Frontmatter
```yaml
---
title: Project Name
description: Brief description of the project
status: planning|active|paused|completed
priority: high|medium|low
owner: Person responsible
started: YYYY-MM-DD
completed: YYYY-MM-DD (optional)
due: YYYY-MM-DD (optional)
tags: [relevant, tags, here]
jira_ticket: TICKET-123 (optional)
repository: repo-name (optional)
---
```

### Content Structure

#### Overview
- Project purpose and goals
- Stakeholders
- Success criteria

#### Milestones
- [ ] Milestone 1: Description (Due: YYYY-MM-DD)
- [ ] Milestone 2: Description (Due: YYYY-MM-DD)
- [ ] Milestone 3: Description (Due: YYYY-MM-DD)

#### Progress
Track progress and updates chronologically:

**YYYY-MM-DD**: Update description
- Accomplishments
- Blockers
- Next steps

#### Resources
- Links to documentation
- Related projects
- Dependencies
- People to consult

#### Risks & Mitigation
- **Risk**: Description → **Mitigation**: Strategy

### Determine Location
- **Public** (`projects/public/`): Team projects, shared initiatives, company-wide efforts
- **Personal** (`projects/personal/`): Individual learning projects, personal development, experiments
