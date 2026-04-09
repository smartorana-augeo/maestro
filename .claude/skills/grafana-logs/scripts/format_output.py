#!/usr/bin/env python3
"""format_output.py — Format Loki JSON responses for human-readable output.

Reads a Loki API JSON response from stdin and prints formatted log lines.

Configuration via environment variables:
  FIELDS        Comma-separated JSON fields to extract (e.g., msg,level,status)
  MAX_WIDTH     Truncate each output line to N characters (0 = unlimited)
  SINCE         Duration string for count mode display (e.g., 5m, 1h)
  SHOW_TIMESTAMPS  1 to prepend ISO 8601 timestamps to each line (default: 1)
  SORT_ORDER    "asc" for oldest first, "desc" for newest first (default: desc)
  MODE          "count" for count_over_time results, "range" for query_range (default: range)
  JSON_OUTPUT   1 to emit raw JSON entries (default: 0)
  DEDUP         1 to collapse consecutive duplicate log lines (default: 0)
  SHOW_LABELS   1 to prefix each line with stream labels (default: 0)

Compatible with Python 3.6+.
"""

import json
import os
import sys
import time


def ns_to_iso(timestamp_ns):
    """Convert a nanosecond epoch string to ISO 8601 truncated to seconds."""
    ts_sec = int(timestamp_ns) // 1_000_000_000
    t = time.gmtime(ts_sec)
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", t)


def format_count(data, since):
    """Handle count_over_time (instant query) results."""
    if data.get("status") != "success":
        err = data.get("error", "unknown error")
        print("Error: " + str(err), file=sys.stderr)
        sys.exit(1)
    total = 0
    breakdown = []
    for stream in data.get("data", {}).get("result", []):
        value = int(float(stream.get("value", ["", "0"])[1]))
        total += value
        labels = stream.get("metric", {})
        if labels:
            label_str = ", ".join(k + "=" + str(v) for k, v in sorted(labels.items()))
            breakdown.append((label_str, value))

    print(str(total) + " matching log lines in the last " + since)
    # Show breakdown by stream if there are multiple
    if len(breakdown) > 1:
        for label_str, value in sorted(breakdown, key=lambda x: -x[1]):
            print("  " + label_str + ": " + str(value))


def extract_error_context(line):
    """Try to extract structured error context from a JSON log line.

    Returns a formatted string with error details, or None if not an error
    or if the line is not JSON.
    """
    try:
        obj = json.loads(line)
    except (json.JSONDecodeError, TypeError):
        return None

    # Only enrich lines that look like errors
    level = str(obj.get("level", obj.get("log_level", ""))).lower()
    status = obj.get("status", obj.get("statusCode", obj.get("http_status", "")))
    has_error_indicator = (
        level in ("error", "fatal", "crit", "critical")
        or (isinstance(status, (int, str)) and str(status).startswith("5"))
    )
    if not has_error_indicator:
        return None

    parts = []
    # Error message
    for key in ("err", "error", "error_message", "errorMessage", "err_msg"):
        val = obj.get(key)
        if val:
            parts.append("  error: " + str(val))
            break

    # Stack trace
    for key in ("stack", "stackTrace", "stack_trace", "errorStack"):
        val = obj.get(key)
        if val:
            # Truncate very long stacks to first 5 lines
            stack_lines = str(val).strip().split("\n")
            if len(stack_lines) > 5:
                stack_lines = stack_lines[:5] + ["  ... (" + str(len(stack_lines) - 5) + " more lines)"]
            parts.append("  stack:\n    " + "\n    ".join(stack_lines))
            break

    # Request context
    ctx_parts = []
    for key in ("method", "http_method"):
        val = obj.get(key)
        if val:
            ctx_parts.append(str(val))
            break
    for key in ("url", "path", "request_path", "requestUrl"):
        val = obj.get(key)
        if val:
            ctx_parts.append(str(val))
            break
    if status:
        ctx_parts.append("status=" + str(status))
    for key in ("duration", "response_time", "responseTime", "elapsed"):
        val = obj.get(key)
        if val:
            ctx_parts.append("duration=" + str(val) + "ms")
            break
    if ctx_parts:
        parts.append("  request: " + " ".join(ctx_parts))

    return "\n".join(parts) if parts else None


def format_stream_labels(stream):
    """Format stream labels into a compact prefix string."""
    labels = stream.get("stream", {})
    # Pick only the most useful labels for display
    display_keys = ["service_name", "environment", "level", "namespace"]
    parts = []
    for k in display_keys:
        if k in labels:
            parts.append(labels[k])
    if not parts:
        # Fallback: show all labels
        parts = [k + "=" + v for k, v in sorted(labels.items())]
    return "[" + "|".join(parts) + "]"


def format_range(data, fields_str, max_width, show_timestamps, sort_order,
                 json_output=False, dedup=False, show_labels=False):
    """Handle query_range (log stream) results."""
    if data.get("status") != "success":
        err = data.get("error", "unknown error")
        print("Error: " + str(err), file=sys.stderr)
        sys.exit(1)

    results = data.get("data", {}).get("result", [])
    fields = [f.strip() for f in fields_str.split(",")] if fields_str else []

    # Build a map from (ts, line) -> stream labels for label display
    stream_label_map = {}
    if show_labels:
        for stream in results:
            label_prefix = format_stream_labels(stream)
            for ts, line in stream.get("values", []):
                stream_label_map[(ts, line)] = label_prefix

    # Collect all entries with their timestamps for sorting
    entries = []
    for stream in results:
        for ts, line in stream.get("values", []):
            entries.append((ts, line))

    # Sort entries by timestamp
    reverse = sort_order != "asc"
    entries.sort(key=lambda e: int(e[0]), reverse=reverse)

    # JSON output mode: emit entries as a JSON array
    if json_output:
        json_entries = []
        for ts, line in entries:
            entry = {"timestamp": ns_to_iso(ts), "timestamp_ns": ts}
            try:
                entry["log"] = json.loads(line)
            except (json.JSONDecodeError, TypeError):
                entry["log"] = line
            if show_labels and (ts, line) in stream_label_map:
                entry["labels"] = stream_label_map[(ts, line)]
            json_entries.append(entry)
        json.dump(json_entries, sys.stdout, indent=2)
        print()  # trailing newline
        print("--- " + str(len(json_entries)) + " log entries (JSON) ---", file=sys.stderr)
        return

    count = 0
    dedup_count = 0
    prev_display = None

    for ts, line in entries:
        display = line
        if fields:
            try:
                obj = json.loads(line)
                display = "\t".join(str(obj.get(f, "")) for f in fields)
            except (json.JSONDecodeError, AttributeError):
                pass

        if max_width > 0 and len(display) > max_width:
            display = display[:max_width] + "..."

        # Dedup: collapse consecutive identical lines
        if dedup and display == prev_display:
            dedup_count += 1
            continue
        elif dedup and dedup_count > 0:
            print("  ... repeated " + str(dedup_count) + " more time" +
                  ("s" if dedup_count > 1 else ""))
            dedup_count = 0

        prev_display = display

        parts = []
        if show_timestamps:
            parts.append(ns_to_iso(ts))
        if show_labels and (ts, line) in stream_label_map:
            parts.append(stream_label_map[(ts, line)])
        parts.append(display)
        print("  ".join(parts))

        # For error lines, show extracted context below
        if not fields:
            error_ctx = extract_error_context(line)
            if error_ctx:
                print(error_ctx)

        count += 1

    # Final dedup flush
    if dedup and dedup_count > 0:
        print("  ... repeated " + str(dedup_count) + " more time" +
              ("s" if dedup_count > 1 else ""))

    if count == 0:
        print("No matching log lines found.", file=sys.stderr)
    else:
        print("--- " + str(count) + " log lines ---", file=sys.stderr)


def main():
    mode = os.environ.get("MODE", "range")
    fields_str = os.environ.get("FIELDS", "")
    max_width = int(os.environ.get("MAX_WIDTH", "0"))
    since = os.environ.get("SINCE", "5m")
    show_timestamps = os.environ.get("SHOW_TIMESTAMPS", "1") == "1"
    sort_order = os.environ.get("SORT_ORDER", "desc")
    json_output = os.environ.get("JSON_OUTPUT", "0") == "1"
    dedup = os.environ.get("DEDUP", "0") == "1"
    show_labels = os.environ.get("SHOW_LABELS", "0") == "1"

    raw = sys.stdin.read()
    if not raw.strip():
        print("Error: empty response from Grafana API.", file=sys.stderr)
        sys.exit(1)

    try:
        data = json.loads(raw)
    except json.JSONDecodeError as e:
        # Check for common HTTP error patterns
        lower = raw.lower()
        if "unauthorized" in lower or "401" in lower:
            print("Error: Authentication failed (401). Check GRAFANA_TOKEN is valid.", file=sys.stderr)
        elif "forbidden" in lower or "403" in lower:
            print("Error: Access denied (403). Token may lack required permissions.", file=sys.stderr)
        elif "429" in lower or "rate limit" in lower:
            print("Error: Rate limited (429). Wait a moment and retry.", file=sys.stderr)
        elif "timeout" in lower or "504" in lower or "gateway" in lower:
            print("Error: Gateway timeout. Try a shorter --since or smaller --limit.", file=sys.stderr)
        elif "404" in lower or "not found" in lower:
            print("Error: Datasource not found (404). Check --ds ID is correct.", file=sys.stderr)
        else:
            print("Error: Failed to parse API response as JSON: " + str(e), file=sys.stderr)
            # Show first 500 chars of the raw response for debugging
            preview = raw[:500]
            if len(raw) > 500:
                preview += "..."
            print("Response preview: " + preview, file=sys.stderr)
        sys.exit(1)

    if mode == "count":
        format_count(data, since)
    else:
        format_range(data, fields_str, max_width, show_timestamps, sort_order,
                     json_output=json_output, dedup=dedup, show_labels=show_labels)


if __name__ == "__main__":
    main()
