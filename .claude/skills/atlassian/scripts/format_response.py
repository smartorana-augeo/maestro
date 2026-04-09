#!/usr/bin/env python3
"""Format Atlassian API JSON responses into concise, readable output.

Usage:
    # Format issue details
    atlassian_api.sh GET '/rest/api/3/issue/CODE-123' | python3 format_response.py issue

    # Format search results
    atlassian_api.sh GET '/rest/api/3/search/jql?jql=...' | python3 format_response.py search

    # Format project list
    atlassian_api.sh GET '/rest/api/3/project/search' | python3 format_response.py projects

    # Format Confluence search results
    atlassian_api.sh GET '/wiki/rest/api/content/search?cql=...' | python3 format_response.py confluence-search

    # Format transitions
    atlassian_api.sh GET '/rest/api/3/issue/CODE-123/transitions' | python3 format_response.py transitions

    # Format user search
    atlassian_api.sh GET '/rest/api/3/user/search?query=...' | python3 format_response.py users

    # Format Confluence spaces
    atlassian_api.sh GET '/wiki/api/v2/spaces' | python3 format_response.py spaces

    # Format Agile boards
    atlassian_api.sh GET '/rest/agile/1.0/board?projectKeyOrId=CODE' | python3 format_response.py boards

    # Format JSM Ops alerts
    atlassian_api.sh GET '/jsm/ops/api/v1/alerts?query=status:open' | python3 format_response.py alerts

    # Format JSM Ops schedules
    atlassian_api.sh GET '/jsm/ops/api/v1/schedules' | python3 format_response.py schedules

    # Format JSM Ops teams
    atlassian_api.sh GET '/jsm/ops/api/v1/teams' | python3 format_response.py teams

Reduces verbose JSON to essential fields, saving context tokens.
"""

from __future__ import annotations

import argparse
import json
import sys


def format_issue(data: dict) -> str:
    """Format a single Jira issue."""
    f = data.get("fields", {})
    lines = [
        f"Key:        {data.get('key', 'N/A')}",
        f"Summary:    {f.get('summary', 'N/A')}",
        f"Status:     {_name(f.get('status'))}",
        f"Type:       {_name(f.get('issuetype'))}",
        f"Priority:   {_name(f.get('priority'))}",
        f"Assignee:   {_display(f.get('assignee'))}",
        f"Reporter:   {_display(f.get('reporter'))}",
        f"Labels:     {', '.join(f.get('labels', [])) or 'None'}",
        f"Sprint:     {_sprint(f)}",
        f"Created:    {_date(f.get('created'))}",
        f"Updated:    {_date(f.get('updated'))}",
    ]
    parent = f.get("parent")
    if parent:
        lines.append(f"Parent:     {parent.get('key', '')} - {parent.get('fields', {}).get('summary', '')}")
    subtasks = f.get("subtasks", [])
    if subtasks:
        lines.append(f"Subtasks:   {', '.join(s.get('key', '') for s in subtasks)}")
    components = f.get("components", [])
    if components:
        lines.append(f"Components: {', '.join(c.get('name', '') for c in components)}")
    fix_versions = f.get("fixVersions", [])
    if fix_versions:
        lines.append(f"Fix Ver:    {', '.join(v.get('name', '') for v in fix_versions)}")
    story_points = f.get("customfield_10016")
    if story_points is not None:
        lines.append(f"Points:     {story_points}")
    return "\n".join(lines)


def format_search(data: dict) -> str:
    """Format JQL search results."""
    issues = data.get("issues", [])
    total = data.get("total", len(issues))
    lines = [f"Results: {len(issues)} of {total} total\n"]
    for issue in issues:
        f = issue.get("fields", {})
        status = _name(f.get("status"))
        assignee = _display(f.get("assignee"))
        priority = _name(f.get("priority"))
        lines.append(f"  {issue.get('key', ''):12s} [{status:15s}] [{priority:6s}] {assignee:20s} {f.get('summary', '')}")
    return "\n".join(lines)


def format_projects(data: dict | list) -> str:
    """Format project list."""
    if isinstance(data, list):
        projects = data
    else:
        projects = data.get("values", data.get("results", []))
    lines = [f"Projects: {len(projects)}\n"]
    for p in projects:
        lines.append(f"  {p.get('key', ''):10s} {p.get('name', '')}")
    return "\n".join(lines)


def format_transitions(data: dict) -> str:
    """Format available transitions."""
    transitions = data.get("transitions", [])
    lines = [f"Available transitions: {len(transitions)}\n"]
    for t in transitions:
        to_status = _name(t.get("to"))
        lines.append(f"  ID: {t.get('id', ''):5s}  Name: {t.get('name', ''):20s}  -> {to_status}")
    return "\n".join(lines)


def format_users(data: dict | list) -> str:
    """Format user search results."""
    users = data if isinstance(data, list) else [data]
    lines = [f"Users: {len(users)}\n"]
    for u in users:
        lines.append(f"  {u.get('accountId', ''):40s} {u.get('displayName', '')} <{u.get('emailAddress', 'N/A')}>")
    return "\n".join(lines)


def format_confluence_search(data: dict) -> str:
    """Format Confluence CQL search results."""
    results = data.get("results", [])
    total = data.get("totalSize", len(results))
    lines = [f"Results: {len(results)} of {total} total\n"]
    for r in results:
        space = r.get("space", {}).get("key", "")
        page_id = r.get("id", "")
        lines.append(f"  [{space:6s}] ID:{page_id:10s} {r.get('title', '')}")
    return "\n".join(lines)


def format_spaces(data: dict) -> str:
    """Format Confluence spaces list."""
    spaces = data.get("results", [])
    lines = [f"Spaces: {len(spaces)}\n"]
    for s in spaces:
        lines.append(f"  {s.get('key', ''):10s} (ID: {s.get('id', ''):8s}) {s.get('name', '')}  [{s.get('type', '')}]")
    return "\n".join(lines)


def format_boards(data: dict) -> str:
    """Format Agile board list."""
    boards = data.get("values", [])
    lines = [f"Boards: {len(boards)}\n"]
    for b in boards:
        location = b.get("location", {})
        project_key = location.get("projectKey", "")
        lines.append(f"  ID: {str(b.get('id', '')):6s} [{b.get('type', ''):6s}] {project_key:10s} {b.get('name', '')}")
    return "\n".join(lines)


def format_confluence_page(data: dict) -> str:
    """Format a single Confluence page."""
    lines = [
        f"ID:         {data.get('id', 'N/A')}",
        f"Title:      {data.get('title', 'N/A')}",
        f"Status:     {data.get('status', 'N/A')}",
        f"Space ID:   {data.get('spaceId', 'N/A')}",
    ]
    version = data.get("version", {})
    if version:
        lines.append(f"Version:    {version.get('number', 'N/A')} (by {_display(version.get('authorId') or version.get('by'))} on {_date(version.get('createdAt', version.get('when')))})")
    parent_id = data.get("parentId")
    if parent_id:
        lines.append(f"Parent ID:  {parent_id}")
    body = data.get("body", {})
    storage = body.get("storage", {})
    if storage:
        value = storage.get("value", "")
        preview = value[:500]
        if len(value) > 500:
            preview += f"\n... ({len(value)} chars total)"
        lines.append(f"\n--- Body ---\n{preview}")
    return "\n".join(lines)


def _name(obj: dict | str | None) -> str:
    """Extract name from a Jira object."""
    if not obj:
        return "None"
    if isinstance(obj, str):
        return obj
    return obj.get("name", obj.get("displayName", "N/A"))


def _display(obj: dict | str | None) -> str:
    """Extract display name."""
    if not obj:
        return "Unassigned"
    if isinstance(obj, str):
        return obj
    return obj.get("displayName", obj.get("name", "N/A"))


def _sprint(fields: dict) -> str:
    """Extract active sprint name from customfield_10020 (array of sprint objects)."""
    sprints = fields.get("customfield_10020") or []
    if not isinstance(sprints, list):
        return "None"
    active = next((s for s in sprints if isinstance(s, dict) and s.get("state") == "active"), None)
    if active:
        return active.get("name", "None")
    # Fall back to first sprint if none active
    if sprints and isinstance(sprints[0], dict):
        return f"{sprints[0].get('name', 'None')} ({sprints[0].get('state', '')})"
    return "None"


def _date(iso_str: str | None) -> str:
    """Format ISO date to readable date."""
    if not iso_str:
        return "N/A"
    return iso_str[:10]


def format_alerts(data: dict) -> str:
    """Format JSM Ops alert list (search results or list endpoint)."""
    alerts = data.get("data", [])
    if isinstance(alerts, dict):
        alerts = [alerts]
    total = data.get("totalCount", len(alerts))
    lines = [f"Alerts: {len(alerts)} of {total} total\n"]
    for a in alerts:
        alert_id = a.get("id", "")[:8]  # truncate UUID for readability
        status = a.get("status", "unknown")
        priority = a.get("priority", "N/A")
        ack = "ACK" if a.get("acknowledged") else "---"
        created = (a.get("createdAt") or "")[:10]
        message = a.get("message", "")
        lines.append(f"  {alert_id}  [{status:8s}] [{priority:2s}] {ack} {created}  {message}")
    return "\n".join(lines)


def format_schedules(data: dict) -> str:
    """Format JSM Ops schedule list."""
    schedules = data.get("data", [])
    lines = [f"Schedules: {len(schedules)}\n"]
    for s in schedules:
        enabled = "enabled" if s.get("enabled") else "disabled"
        owner = (s.get("ownerTeam") or {}).get("name", "N/A")
        tz = s.get("timezone", "")
        lines.append(f"  {s.get('id', ''):36s} [{enabled:8s}] {owner:20s} {s.get('name', '')} ({tz})")
    return "\n".join(lines)


def format_teams(data: dict) -> str:
    """Format JSM Ops team list."""
    teams = data.get("data", [])
    lines = [f"Teams: {len(teams)}\n"]
    for t in teams:
        members = t.get("members", [])
        desc = t.get("description", "")
        lines.append(f"  {t.get('id', ''):36s} {t.get('name', ''):25s} ({len(members)} members)  {desc}")
    return "\n".join(lines)


FORMATTERS: dict[str, object] = {
    "issue": format_issue,
    "search": format_search,
    "projects": format_projects,
    "transitions": format_transitions,
    "users": format_users,
    "confluence-search": format_confluence_search,
    "confluence-page": format_confluence_page,
    "spaces": format_spaces,
    "boards": format_boards,
    "alerts": format_alerts,
    "schedules": format_schedules,
    "teams": format_teams,
}


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Format Atlassian API JSON responses into readable output.",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("format_type", metavar="FORMAT", choices=FORMATTERS.keys(),
                        help=f"Response format type. One of: {', '.join(FORMATTERS.keys())}")
    args = parser.parse_args()

    try:
        data = json.load(sys.stdin)
    except json.JSONDecodeError as e:
        print(f"Error: invalid JSON input: {e}", file=sys.stderr)
        sys.exit(1)

    print(FORMATTERS[args.format_type](data))


if __name__ == "__main__":
    main()
