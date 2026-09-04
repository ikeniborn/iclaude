#!/usr/bin/env python3
"""SessionEnd hook: cumulative Anthropic prompt-cache report for the session.

Reads the session transcript (.jsonl), sums per-turn cache usage across all
assistant messages, and writes a human-readable cache report. Fail-soft: any
error exits 0 so the Claude Code UI is never affected.
"""
import json
import os
import sys


def aggregate(transcript_path):
    """Sum cache usage across assistant turns in a transcript .jsonl.

    Returns {"read","creation","input","output","turns"} (ints). Non-JSON lines
    and non-assistant messages are skipped; a missing/unreadable file yields
    all-zero totals.
    """
    agg = {"read": 0, "creation": 0, "input": 0, "output": 0, "turns": 0}
    if not transcript_path or not os.path.isfile(transcript_path):
        return agg
    try:
        with open(transcript_path, "r", encoding="utf-8") as fh:
            for line in fh:
                line = line.strip()
                if not line:
                    continue
                try:
                    obj = json.loads(line)
                except (ValueError, TypeError):
                    continue
                if obj.get("type") != "assistant":
                    continue
                message = obj.get("message")
                if not isinstance(message, dict):
                    continue
                usage = message.get("usage")
                if not isinstance(usage, dict):
                    continue
                try:
                    read = int(usage.get("cache_read_input_tokens", 0) or 0)
                    creation = int(usage.get("cache_creation_input_tokens", 0) or 0)
                    inp = int(usage.get("input_tokens", 0) or 0)
                    out = int(usage.get("output_tokens", 0) or 0)
                except (ValueError, TypeError):
                    continue
                agg["read"] += read
                agg["creation"] += creation
                agg["input"] += inp
                agg["output"] += out
                agg["turns"] += 1
    except OSError:
        return agg
    return agg


def format_report(session_id, agg):
    """Build the human-readable report string (raw token counts, full precision)."""
    denom = agg["read"] + agg["creation"] + agg["input"]
    hit = "n/a" if denom == 0 else "%.0f%%" % (agg["read"] * 100.0 / denom)
    return (
        "iclaude cache report — session %s\n"
        "  cache-read   %d tok (%s)\n"
        "  cache-write  %d tok\n"
        "  uncached in  %d tok\n"
        "  output       %d tok\n"
        "  turns        %d\n"
    ) % (session_id, agg["read"], hit, agg["creation"],
         agg["input"], agg["output"], agg["turns"])


def _config_dir():
    env = os.environ.get("CLAUDE_CONFIG_DIR")
    if env:
        return env
    # Fallback: hooks/ -> .claude-isolated/
    return os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def main():
    try:
        raw = sys.stdin.read()
        data = json.loads(raw) if raw.strip() else {}
    except (ValueError, TypeError):
        return 0
    if not isinstance(data, dict):
        return 0
    agg = aggregate(data.get("transcript_path", ""))
    if agg["turns"] == 0:
        return 0  # nothing to report
    report = format_report(data.get("session_id", "unknown"), agg)
    # Primary sink: log file under the config dir.
    try:
        logs_dir = os.path.join(_config_dir(), "logs")
        os.makedirs(logs_dir, exist_ok=True)
        fname = "cache-report-%s.txt" % data.get("session_id", "unknown")
        with open(os.path.join(logs_dir, fname), "w", encoding="utf-8") as fh:
            fh.write(report)
    except OSError:
        pass
    # Best-effort: echo to the controlling terminal as the session closes.
    try:
        with open("/dev/tty", "w") as tty:
            tty.write("\n" + report)
    except OSError:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
