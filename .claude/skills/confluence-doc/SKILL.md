---
name: Confluence Documentation
description: Create comprehensive Confluence documentation from projects, technical plans, or code. Use this skill when the user asks to create Confluence docs, wiki pages, or documentation for Atlassian Confluence.
---

# Confluence Documentation

This skill helps you create well-structured Confluence documentation from various sources including technical plans, project files, code analysis, and research notes.

## When to Use This Skill

- User asks to create Confluence documentation
- User wants to publish a technical plan to Confluence
- User needs to document a project in wiki format
- User requests documentation for team knowledge sharing

## Instructions

### 1. Gather Context

First, understand what needs to be documented:

- If documenting a project, read the project file from `projects/public/` or `projects/personal/`
- If documenting a technical plan, check for related memory files in `memories/public/`
- If documenting code, read relevant source files from `repositories/`
- Check for related Jira tickets if mentioned

### 2. Structure the Documentation

Confluence documentation should follow this structure:

**Title**: Clear, descriptive title
**Overview**: Brief summary (2-3 sentences)
**Table of Contents**: For longer documents

**Main Sections** (adapt based on content type):

For Technical Documentation:

- Background/Context
- Architecture Overview
- Technical Details
- Implementation Notes
- API Reference (if applicable)
- Dependencies
- Configuration
- Testing
- Deployment
- Troubleshooting

For Project Documentation:

- Project Overview
- Goals & Objectives
- Scope
- Timeline & Milestones
- Team & Responsibilities
- Requirements
- Deliverables
- Success Metrics
- Risks & Mitigation
- Resources

For Feature Documentation:

- Feature Overview
- User Stories
- Technical Approach
- Design Decisions
- Implementation Plan
- Testing Strategy
- Rollout Plan

### 3. Format for Confluence

Use Confluence-compatible markup:

```
h1. Main Title
h2. Section Heading
h3. Subsection

*bold text*
_italic text_
-strikethrough-

* Bullet point
** Nested bullet
# Numbered list

{code:javascript}
// Code blocks with language
{code}

{info}
Info panel for callouts
{info}

{warning}
Warning panel for important notes
{warning}

{note}
Note panel for additional context
{note}

|| Header 1 || Header 2 ||
| Cell 1 | Cell 2 |

[Link text|https://example.com]
[Internal page link]
```

### 4. Include Key Elements

Always include:

- **Status Label**: Add status macro at top (e.g., Draft, In Progress, Completed)
- **Metadata Table**: Author, created date, last updated, related Jira tickets
- **Related Pages**: Links to related Confluence docs
- **Contributors**: List team members involved

### 5. Generate the Documentation

Create a well-formatted Confluence document following the structure above. Output the content in Confluence wiki markup format.

### 6. Save for Reference

After creating the documentation:

- Save a copy to `docs/` in the appropriate department subfolder
- Create a memory file in `memories/public/` noting what was documented
- Include the Confluence page link in the memory for future reference

## Tips

- Use info/warning/note panels to highlight important information
- Break up long sections with headings and visual elements
- Include code examples in code blocks with proper syntax highlighting
- Add tables for structured data (requirements, specifications, etc.)
- Use bullet points and numbered lists for readability
- Include diagrams or references to architecture images when relevant
- Link to Jira tickets using TICKET-123 format
- Cross-reference related Confluence pages

## Supporting Files

- `templates/technical-doc.md` - Template for technical documentation
- `templates/project-doc.md` - Template for project documentation
- `templates/feature-doc.md` - Template for feature documentation

## Output Format

Present the final documentation in a code block with the language set to `confluence` so the user can easily copy and paste it into Confluence.

## Atlassian Integration

To interact with Confluence and Jira directly, use one of these methods (in order of preference):

1. **claude.ai Atlassian Connector** — If the claude.ai Atlassian MCP tools are available (e.g. `mcp__claude_ai_Atlassian__getConfluencePage`, `mcp__claude_ai_Atlassian__createConfluencePage`), use those to fetch existing pages, create/update pages, and enrich documentation with Jira ticket data.
2. **Atlassian Skill** — If the connector is not available, use the `atlassian` skill which calls the Atlassian REST API via shell scripts. This requires `ATLASSIAN_EMAIL`, `ATLASSIAN_API_TOKEN`, and `ATLASSIAN_DOMAIN` in the project `.env` file.

Check for available methods at the start of the skill execution.
