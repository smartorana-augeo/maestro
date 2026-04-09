# Create Memory

Create a memory document to store important context that should persist.

## Usage
When invoked, you'll be prompted for what to memorize.

## Instructions

Create a new memory file in `memories/public/` or `memories/personal/`.

Memories are for important context that should be preserved and referenced later, such as:
- System architecture decisions
- Process documentation
- Database schemas
- Integration patterns
- Lessons learned
- Team decisions
- Workflow documentation

### Naming Convention
`YYYY-MM-DD-descriptive-topic-name.memory.md`

### YAML Frontmatter
```yaml
---
title: Memory Title
description: Brief description of what this memory contains
created: YYYY-MM-DD
updated: YYYY-MM-DD (optional)
tags: [relevant, tags, here]
related_projects: [project-file-names]
related_todos: [todo-file-names]
repository: repo-name (optional)
---
```

### Content Structure

Write the memory content in a clear, organized format:

#### Context
- What this memory is about
- Why it's important
- When it was created or discovered

#### Details
The main content - be thorough and specific. Include:
- Code examples
- Architecture diagrams (in markdown)
- Decision rationales
- Process steps
- Configuration details
- Important gotchas or learnings

#### References
- Links to documentation
- Related files in repositories
- Confluence pages
- Other memory files
- People to contact

### Determine Location
- **Public** (`memories/public/`): Shared knowledge, team decisions, system architecture
- **Personal** (`memories/personal/`): Personal learnings, private notes, individual discoveries
