#!/usr/bin/env python3
"""Convert Atlassian Document Format (ADF) JSON to plain text.

Usage:
    # Pipe JSON from atlassian_api.sh
    atlassian_api.sh GET '/rest/api/3/issue/CODE-123' | python3 parse_adf.py

    # Extract a specific field's ADF
    atlassian_api.sh GET '/rest/api/3/issue/CODE-123' | python3 parse_adf.py --field description

    # Parse raw ADF JSON directly
    echo '{"type":"doc","version":1,"content":[...]}' | python3 parse_adf.py --raw

Output: plain text with markdown-like formatting (headings, lists, code blocks).
"""

from __future__ import annotations

import argparse
import json
import sys

_MAX_DEPTH = 50


def adf_to_text(node: dict, indent: int = 0, list_type: str | None = None, list_index: int = 0, _depth: int = 0) -> str:
    """Recursively convert an ADF node to plain text."""
    if _depth > _MAX_DEPTH:
        return ""
    if not node or not isinstance(node, dict):
        return ""

    node_type = node.get("type", "")
    attrs = node.get("attrs", {})
    content = node.get("content", [])
    marks = node.get("marks", [])

    # Inline text node
    if node_type == "text":
        text = node.get("text", "")
        for mark in marks:
            mark_type = mark.get("type", "")
            if mark_type == "strong":
                text = f"**{text}**"
            elif mark_type == "em":
                text = f"*{text}*"
            elif mark_type == "code":
                text = f"`{text}`"
            elif mark_type == "strike":
                text = f"~~{text}~~"
            elif mark_type == "link":
                href = mark.get("attrs", {}).get("href", "")
                text = f"[{text}]({href})"
        return text

    # Block nodes
    if node_type == "doc":
        return _join_blocks(content, indent, _depth)

    if node_type == "paragraph":
        return "".join(adf_to_text(c, indent, _depth=_depth + 1) for c in content)

    if node_type == "heading":
        level = attrs.get("level", 1)
        text = "".join(adf_to_text(c, indent, _depth=_depth + 1) for c in content)
        return f"{'#' * level} {text}"

    if node_type == "bulletList":
        lines = []
        for item in content:
            lines.append(adf_to_text(item, indent, list_type="bullet", _depth=_depth + 1))
        return "\n".join(lines)

    if node_type == "orderedList":
        lines = []
        for i, item in enumerate(content, 1):
            lines.append(adf_to_text(item, indent, list_type="ordered", list_index=i, _depth=_depth + 1))
        return "\n".join(lines)

    if node_type == "listItem":
        prefix = "  " * indent
        if list_type == "ordered":
            prefix += f"{list_index}. "
        else:
            prefix += "- "
        parts = []
        for i, child in enumerate(content):
            if child.get("type") in ("bulletList", "orderedList"):
                parts.append(adf_to_text(child, indent + 1, _depth=_depth + 1))
            else:
                text = adf_to_text(child, indent, _depth=_depth + 1)
                if i == 0:
                    parts.append(f"{prefix}{text}")
                else:
                    parts.append(f"{'  ' * (indent + 1)}{text}")
        return "\n".join(parts)

    if node_type == "codeBlock":
        lang = attrs.get("language", "")
        code = "".join(adf_to_text(c, indent, _depth=_depth + 1) for c in content)
        return f"```{lang}\n{code}\n```"

    if node_type == "blockquote":
        text = _join_blocks(content, indent, _depth)
        return "\n".join(f"> {line}" for line in text.split("\n"))

    if node_type == "rule":
        return "---"

    if node_type == "table":
        return _render_table(content, indent)

    if node_type == "tableRow":
        cells = [adf_to_text(c, indent, _depth=_depth + 1) for c in content]
        return "| " + " | ".join(cells) + " |"

    if node_type in ("tableCell", "tableHeader"):
        return "".join(adf_to_text(c, indent, _depth=_depth + 1) for c in content)

    if node_type == "panel":
        panel_type = attrs.get("panelType", "info").upper()
        text = _join_blocks(content, indent, _depth)
        return f"[{panel_type}] {text}"

    if node_type == "mention":
        return f"@{attrs.get('text', attrs.get('id', 'unknown'))}"

    if node_type == "emoji":
        return attrs.get("shortName", attrs.get("text", ""))

    if node_type == "hardBreak":
        return "\n"

    if node_type == "inlineCard":
        return attrs.get("url", "")

    if node_type in ("mediaGroup", "mediaSingle"):
        parts = []
        for c in content:
            parts.append(adf_to_text(c, indent, _depth=_depth + 1))
        return "\n".join(parts)

    if node_type == "media":
        return f"[media: {attrs.get('type', 'file')}]"

    if node_type == "expand":
        title = attrs.get("title", "Details")
        text = _join_blocks(content, indent, _depth)
        return f"<{title}>\n{text}"

    if node_type == "status":
        return f"[{attrs.get('text', '')}]"

    if node_type == "taskList":
        lines = []
        for item in content:
            lines.append(adf_to_text(item, indent, list_type="task", _depth=_depth + 1))
        return "\n".join(lines)

    if node_type == "taskItem":
        state = attrs.get("state", "TODO")
        checkbox = "[x]" if state == "DONE" else "[ ]"
        prefix = "  " * indent
        text = "".join(adf_to_text(c, indent, _depth=_depth + 1) for c in content)
        return f"{prefix}- {checkbox} {text}"

    if node_type == "decisionList":
        lines = []
        for item in content:
            lines.append(adf_to_text(item, indent, list_type="decision", _depth=_depth + 1))
        return "\n".join(lines)

    if node_type == "decisionItem":
        state = attrs.get("state", "DECIDED")
        prefix = "  " * indent
        text = "".join(adf_to_text(c, indent, _depth=_depth + 1) for c in content)
        return f"{prefix}> DECISION ({state}): {text}"

    # Fallback: try to render children
    if content:
        return _join_blocks(content, indent, _depth)
    return ""


def _join_blocks(content: list, indent: int, depth: int) -> str:
    """Join block-level nodes with blank lines."""
    parts = []
    for child in content:
        text = adf_to_text(child, indent, _depth=depth + 1)
        if text:
            parts.append(text)
    return "\n\n".join(parts)


def _render_table(rows: list, indent: int) -> str:
    """Render a table from ADF table rows."""
    if not rows:
        return ""
    rendered = []
    for i, row in enumerate(rows):
        line = adf_to_text(row, indent)
        rendered.append(line)
        if i == 0:
            cells = row.get("content", [])
            rendered.append("| " + " | ".join("---" for _ in cells) + " |")
    return "\n".join(rendered)


def main() -> None:
    parser = argparse.ArgumentParser(description="Convert ADF JSON to plain text")
    parser.add_argument("--field", default="description",
                        help="Field to extract from issue JSON (default: description)")
    parser.add_argument("--raw", action="store_true",
                        help="Input is raw ADF JSON, not a Jira issue response")
    args = parser.parse_args()

    try:
        data = json.load(sys.stdin)
    except json.JSONDecodeError as e:
        print(f"Error: invalid JSON input: {e}", file=sys.stderr)
        sys.exit(1)

    if args.raw:
        adf = data
    else:
        if "fields" in data:
            adf = data["fields"].get(args.field)
        else:
            adf = data.get(args.field)

    if adf is None:
        print(f"(no {args.field})")
        sys.exit(0)

    if isinstance(adf, str):
        print(adf)
        sys.exit(0)

    # Handle comment wrapper: fields.comment is {comments: [...], total: N}, not ADF
    if isinstance(adf, dict) and "comments" in adf and "type" not in adf:
        for i, comment in enumerate(adf["comments"]):
            author = comment.get("author", {}).get("displayName", "Unknown")
            created = comment.get("created", "")[:10]
            body = comment.get("body")
            print(f"--- Comment {i + 1} by {author} ({created}) ---")
            if body and isinstance(body, dict):
                print(adf_to_text(body))
            print()
        sys.exit(0)

    print(adf_to_text(adf))


if __name__ == "__main__":
    main()
