# Create Todo

Create a new todo item to track a task or action item.

## Usage
When invoked, you'll be prompted for todo details.

## Instructions

Create a new todo file in `todos/public/` or `todos/personal/` (depending on if it's shared or private).

### Naming Convention
`YYYY-MM-DD-descriptive-name.todo.md`

### YAML Frontmatter
```yaml
---
title: Brief title of the task
description: Detailed description of what needs to be done
status: pending
priority: high|medium|low
owner: Person responsible
created: YYYY-MM-DD
due: YYYY-MM-DD (optional)
tags: [relevant, tags, here]
related_projects: [project-file-names]
jira_ticket: TICKET-123 (optional)
---
```

### Content Structure
After the frontmatter, include:

#### Context
Background information and why this todo exists.

#### Acceptance Criteria
- [ ] Specific criteria for completion
- [ ] What success looks like
- [ ] How to verify completion

#### Subtasks (optional)
- [ ] Break down into smaller steps
- [ ] Each step should be actionable
- [ ] Track progress on complex tasks

#### Notes
- Any additional information
- Links to relevant resources
- Dependencies on other work

### Determine Location
- **Public** (`todos/public/`): Shared tasks, team responsibilities, process improvements
- **Personal** (`todos/personal/`): Individual tasks, private notes, personal work items
