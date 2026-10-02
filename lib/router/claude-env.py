#!/usr/bin/env python3
"""Preserve the caller's tool environment when CCR launches Claude Code."""
import json
import os
from pathlib import Path
import shlex
import sys

args = sys.argv[1:]
# CCR appends its generated settings after user arguments. Leave that shared
# cached file unchanged; pass corrected settings inline for this session only.
index = len(args) - 1 - args[::-1].index("--settings")
settings = json.loads(Path(args[index + 1]).read_text())
for name in ("NO_PROXY", "no_proxy"):
    fallback = "no_proxy" if name == "NO_PROXY" else "NO_PROXY"
    entries = [entry for entry in os.environ.get(name, os.environ.get(fallback, "")).split(",") if entry]
    if "127.0.0.1" not in entries:
        entries.append("127.0.0.1")
    settings["env"][name] = ",".join(entries)
args[index + 1] = json.dumps(settings)
os.environ["HOME"] = os.environ.pop("ICLAUDE_ROUTER_USER_HOME")
command = shlex.split(os.environ.pop("ICLAUDE_ROUTER_CLAUDE_COMMAND"))
os.environ.pop("CLAUDE_PATH", None)
os.execvpe(command[0], command + args, os.environ)
