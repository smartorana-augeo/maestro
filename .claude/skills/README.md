# Maestro skills

Domain-specific knowledge modules that extend Claude with specialized capabilities. Skills are invoked automatically when relevant, or explicitly via the `Skill` tool.

## Integrations

- **`atlassian`** — Full Atlassian API integration for Jira, Confluence, JSM, and Compass — use as a fallback when the claude.ai Atlassian connector is not available
- **`confluence-doc`** — Create comprehensive Confluence documentation from projects, technical plans, or code
- **`github-submodules`** — Manages maestro repository submodules using the GitHub REST API
- **`tempo`** — Log time entries to Tempo (Jira time tracking) by fetching Outlook calendar events or parsing a pasted list of time ranges and issue keys
- **`testrail`** — Interact with the TestRail API to browse projects, test suites, sections, and test cases, and to create new content

## Observability

- **`circle-ci`** — Investigate and manage CircleCI pipelines, workflows, and jobs via the CircleCI API v2
- **`grafana-logs`** — Query application logs from Grafana Cloud Loki via the datasource proxy API

## Tooling

- **`skill-creator`** — Create new skills, modify and improve existing skills, and measure skill performance

Each skill has a detailed `.md` file in its folder with triggers, instructions, and usage examples.
