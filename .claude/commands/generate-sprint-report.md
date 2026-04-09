# Generate Sprint Report

Automate the generation of a sprint summary report from Jira data, saving it locally and publishing it to Confluence.

## Usage

When invoked, you'll be prompted for:

- **Jira project key**: The Jira project (e.g., "CODE", "OPS", "CSSTRC")
- **Board ID**: The Jira board ID (e.g., 347 for the CODE board)
- **Sprint name**: The Jira sprint name (e.g., "2026-Mar", "2026-Feb")
- **Confluence parent page ID**: The page ID under which the report will be created (optional — will prompt if not provided)

You may also pass arguments inline: `<project-key> <board-id> <sprint-name> [confluence-parent-page-id]`

**Arguments:** $ARGUMENTS

## Instructions

You are an orchestrator generating a comprehensive sprint summary report. Infer the team name from existing sibling sprint reports on Confluence or local reports in `projects/personal/*-sprint-summary.md`. If no prior reports exist to infer from, prompt the user for the team name.

### Orchestration

Use **Felix** (subagent_type: `felix`) to orchestrate this task. Felix should:

1. **Parse arguments and gather missing inputs** (Steps 1).
2. **Delegate Jira data retrieval and analysis** (Steps 2-3) — Felix can handle this directly or delegate to a subagent.
3. **Delegate report writing** to a **documentation-engineer** agent (subagent_type: `documentation-engineer`) — pass the analyzed data, metrics, and the report structure template (Step 4) so the documentation-engineer can produce a polished report.
4. **Review the output** — Felix reviews the documentation-engineer's report for accuracy against the Jira data before saving.
5. **Save locally and publish to Confluence** (Steps 5-6) — Felix handles file writing and Confluence publishing.
6. **Present the summary** to the user (Step 7).

Felix should spin up subagents in parallel where possible (e.g., fetching reference reports and querying Jira simultaneously).

### CRITICAL REQUIREMENTS:

1. **MANDATORY JIRA ACCESS** — You MUST successfully retrieve sprint data from Jira before proceeding. If you cannot query Jira, STOP and report the failure.
2. **Use claude.ai Atlassian Connector First** — If the claude.ai Atlassian MCP tools are available (e.g. `mcp__claude_ai_Atlassian__searchJiraIssuesUsingJql`), use those to query Jira via JQL.
3. **Fallback: Atlassian Skill** — If the connector is not available, use the `atlassian` skill which calls the Atlassian REST API via shell scripts. This requires `ATLASSIAN_EMAIL`, `ATLASSIAN_API_TOKEN`, and `ATLASSIAN_DOMAIN` in the project `.env` file.
4. **No Report Without Data** — Never proceed with generating the report if you cannot retrieve the Jira sprint data.

### Reference Reports

Before generating, review existing sprint summaries to ensure consistent format:

- **Local**: Look for files matching `projects/personal/*-sprint-summary.md` and use the most recent ones as your template.
- **Confluence**: Fetch sibling pages under the same parent page ID provided by the user and review the most recent sprint summary for formatting consistency.

---

### Step 1: Parse Arguments

Parse `$ARGUMENTS` for the project key, board ID, sprint name, and optional Confluence parent page ID. If not provided, ask the user for:

1. Jira project key (e.g., "CODE") — used in the JQL query and report title
2. Board ID (e.g., 347) — used for the sprint report link
3. Sprint name (e.g., "2026-Mar") — this must match the Jira sprint name exactly
4. Confluence parent page ID or URL where the report should be created

Extract the month and year from the sprint name for file naming (e.g., "2026-Mar" -> `2026-03`).

---

### Step 2: Query Jira for Sprint Data

**MANDATORY**: Retrieve all issues in the sprint.

Use JQL:

```
project = {project-key} AND sprint = "<sprint-name>" ORDER BY assignee ASC, key ASC
```

Fields to request: `summary`, `status`, `issuetype`, `priority`, `assignee`, `resolution`, `customfield_10004` (story points).

**Handle pagination**: Jira returns a maximum of 50 results per request. You MUST paginate through all results using `startAt` and `maxResults` until you have retrieved every issue. Check the `total` field in the response to know when you have all results.

---

### Step 3: Analyze the Data

Compute the following metrics from the retrieved issues:

#### Overall Metrics

- **Total Issues**: Count of all issues in the sprint
- **Completed (Done)**: Issues with status "Done"
- **Closed (Won't Fix)**: Issues with resolution "Won't Do" or "Won't Fix"
- **In Progress / To Do**: Issues not Done and not Won't Fix (still open or in progress)
- **Total Story Points**: Sum of `customfield_10004` across all issues
- **Points Completed**: Story points for Done issues
- **Points Won't Fix**: Story points for Won't Fix issues
- **Points Remaining**: Story points for In Progress / To Do issues

#### By Assignee

For each assignee, compute:

- Done count
- Won't Fix count
- In Progress count
- Total issues
- Points completed
- Points total

Sort by total issues descending.

#### Workstream Grouping

Group issues into thematic workstreams by analyzing:

- Common prefixes in summaries (e.g., "[Slack]", "[Postcard]", "[Workday]")
- Related ticket sequences (e.g., CODE-7465 through CODE-7473)
- Shared functional areas
- Primary assignee

For each workstream, write a brief narrative paragraph summarizing what was accomplished, followed by the list of issue keys.

#### Won't Fix Analysis

For each Won't Fix issue, capture the key, summary, and infer a brief note about why it was closed.

---

### Step 4: Generate the Report

Write the report in markdown matching the exact structure of existing sprint summaries.

#### Frontmatter

```yaml
---
title: "Sprint Summary - {Month} {Year}"
description: "Summary of the {project-key} project sprint for {Month} {Year}"
status: completed
priority: medium
owner: Andy Shi
created: { today's date YYYY-MM-DD }
tags: [sprint-summary, { project-key-lowercase }, { month-year-lowercase }]
---
```

#### Report Structure (follow this order exactly)

1. **No h1 title in the body** — The page title on Confluence serves as the title. Do not include a `# Title` heading in the body. The local markdown file should still have the `title` in frontmatter but start the body with the Executive Summary.

2. **Executive Summary**: 2-3 sentences covering total issues completed, story points, Won't Fix count, carryover count, and the major workstreams by name. Be specific with numbers.

3. **Kanban Note** _(CODE board only, or if the user explicitly requests it)_: Include this paragraph after the executive summary:

   > **Note:** The team currently operates in a **Kanban format**, not formal Scrum. Stories and points were added mid-sprint as business needs arose, so the final point total ({total points}) exceeds what was initially planned at sprint start.

4. **Key Metrics**: Table with the overall metrics computed in Step 3.

5. **NOTE Callout**: Include this blockquote after the metrics table:

   > **NOTE:** To view the burndown (committed vs. final points), see the [Jira Sprint Report](https://augeomarketing.atlassian.net/jira/software/c/projects/{project-key}/boards/{board-id}/reports/sprint-retrospective) (Board {board-id} > Sprint Report > "{sprint-name}").

6. **By Assignee**: Table with per-assignee breakdown. Add a footnote at the bottom noting which board this report covers and that work tracked on the OPS and CSSTRC boards is not reflected.

7. **Workstreams**: Numbered subsections (### 1. Workstream Name (Primary Assignee)), each with a narrative paragraph and `**Issues:** {PROJECT}-XXXX, {PROJECT}-YYYY` list.

8. **Key Accomplishments**: Bullet points highlighting the most impactful completions. Use bold for the headline of each bullet. Aim for 4-8 bullets.

9. **Won't Fix Items**: Introductory sentence stating the count, followed by a table with Key, Summary, and Notes columns.

10. **Looking Ahead**: 4-6 bullet points predicting next sprint focus areas based on in-progress work and patterns observed.

---

### Step 5: Save the Report Locally

Write the report to:

```
projects/personal/YYYY-MM-sprint-summary.md
```

Where `YYYY-MM` is derived from the sprint name (e.g., "2026-Mar" -> `2026-03`).

---

### Step 6: Publish to Confluence

Create a new Confluence page. If the claude.ai Atlassian MCP tools are available, use those. Otherwise, use the `atlassian` skill (requires `.env` credentials):

- **Space ID**: `9627795512` (AWE Engineering)
- **Parent page ID**: The ID provided by the user
- **Title**: `Sprint Summary - {Month} {Year}`
- **Body**: Convert the markdown report body (everything after the frontmatter) to Confluence storage format (XHTML)

If Confluence publishing fails, inform the user and provide the local file path so they can publish manually.

---

### Step 7: Summary

Present a summary to the user:

- Local file path
- Confluence page URL (if published)
- Key metrics at a glance
- Any items that need manual attention (e.g., the TODO for committed vs. final points)
