#!/usr/bin/env python3
"""PreToolUse permission-guard: for Bash commands, enforce shell deny_patterns,
a hard block on `git reset --hard`, network mode (off/allowlist for
curl/wget/ssh/scp/nc), and the shell.allow allowlist. Inert without a loop.yaml.
Fails open on error."""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import loen_common as _c  # noqa: E402

_NET_TOOLS = re.compile(r"\b(curl|wget|ssh|scp|nc|netcat)\b")


def main():
    event = _c.read_event()
    if _c.tool_class(_c.tool_name(event)) != "shell":
        return 0
    run, topic = _c.should_run_hook(event)
    if not run or not topic:
        return 0
    loop_text = _c.read_loop_artifact(topic)
    if not loop_text:
        return 0
    policy = _c.parse_loop_yaml(loop_text)
    shell = (policy.get("permissions") or {}).get("shell") or {}
    network = (policy.get("permissions") or {}).get("network") or {}
    command = _c.shell_command(event)

    if re.search(r"git\s+reset\s+--hard", command):
        return _c.block_or_nudge("`git reset --hard` is blocked by loen")

    for pattern in (shell.get("deny_patterns") or []):
        try:
            if re.search(pattern, command):
                return _c.block_or_nudge(f"command matches deny_pattern {pattern!r}: {command}")
        except re.error:
            if _c.command_matches(command, pattern):
                return _c.block_or_nudge(f"command matches deny_pattern {pattern!r}: {command}")

    if str(network.get("mode") or "off").strip() == "off" and _NET_TOOLS.search(command):
        allowlist = network.get("allowlist") or []
        if not any(host and host in command for host in allowlist):
            return _c.block_or_nudge(f"network is off: blocked network command: {command}")

    allow = shell.get("allow") or []
    if allow and not any(_c.command_matches(command, p) or re.search(p, command) for p in allow):
        return _c.block_or_nudge(f"command not in shell.allow allowlist: {command}")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception:
        sys.exit(0)
