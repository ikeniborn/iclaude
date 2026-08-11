#!/usr/bin/env python3
"""Shared deterministic helpers for loen hook assets (Claude Code runtime).

Ported from the icodex loen_common.py and adapted:
- default LOEN_MODE is ``enforce`` (not ``advisory``);
- tools are the Claude Code set (Write/Edit/MultiEdit/Bash/Read/Grep/Glob);
- ``tool_class`` takes a tool-name string; ``topic_from_path`` returns None on
  a miss; the active-topic pointer ``<root>/current`` is a plain-text file
  holding the active topic slug (not a symlink);
- ``parse_loop_yaml`` understands inline flow maps ``{k: v}`` and lists ``[a, b]``.

No third-party dependencies — stdlib only.
"""
from __future__ import annotations

import fnmatch
import json
import os
import posixpath
import re
import sys

BLOCK = 2
_MODES = ("off", "advisory", "enforce", "strict")
_SLUG = re.compile(r"^[a-z0-9][a-z0-9-]*$")


# --- mode ------------------------------------------------------------------

def mode():
    value = os.environ.get("LOEN_MODE", "enforce").strip().lower()
    return value if value in _MODES else "enforce"


def is_off():
    return mode() == "off"


def is_enforcing():
    return mode() in ("enforce", "strict")


def is_advisory():
    return mode() == "advisory"


def is_strict():
    return mode() == "strict"


def stderr(message):
    print(f"[loen] {message}", file=sys.stderr)


def block_or_nudge(message):
    """Shared enforcement primitive: block (exit 2) in enforce/strict,
    print-only in advisory, silent in off."""
    if is_enforcing():
        stderr(message)
        return BLOCK
    if is_advisory():
        stderr(f"(advisory) {message}")
    return 0


# --- event I/O -------------------------------------------------------------

def read_event():
    try:
        raw = sys.stdin.read()
    except OSError:
        return {}
    if not raw.strip():
        return {}
    try:
        data = json.loads(raw)
    except json.JSONDecodeError:
        return {}
    return data if isinstance(data, dict) else {}


def tool_name(event):
    return str(event.get("tool_name") or event.get("tool") or event.get("name") or "")


def tool_input(event):
    value = event.get("tool_input") or event.get("input") or event.get("parameters") or {}
    if isinstance(value, dict):
        return value
    if isinstance(value, str):
        return {"_raw": value}
    return {}


def tool_class(name):
    """Normalize a Claude Code tool name to a coarse class."""
    t = name or ""
    if t in ("Write", "Edit", "MultiEdit"):
        return "edit"
    if t in ("Bash", "shell"):
        return "shell"
    if t in ("Read",):
        return "read"
    if t in ("Grep", "Glob"):
        return "search"
    return "other"


def shell_command(event):
    inp = tool_input(event)
    value = inp.get("command") or inp.get("_raw") or event.get("command") or ""
    return value if isinstance(value, str) else ""


def command_matches(command, pattern):
    return command == pattern or fnmatch.fnmatch(command, pattern)


# --- artifact roots & slugs ------------------------------------------------

def artifact_root():
    return os.environ.get("LOEN_ARTIFACT_ROOT", "docs/loen")


def validate_topic_slug(slug):
    return bool(slug) and bool(_SLUG.match(slug))


def normalize_path(path):
    clean = (path or "").replace("\\", "/")
    normalized = posixpath.normpath(clean)
    if normalized == ".":
        return ""
    if clean.startswith("/"):
        cwd = posixpath.normpath(os.getcwd().replace("\\", "/"))
        if normalized == cwd:
            return ""
        if normalized.startswith(cwd + "/"):
            return normalized[len(cwd) + 1:]
    return normalized


def matches_any(path, patterns):
    clean = normalize_path(path)
    return any(fnmatch.fnmatch(clean, p) for p in (patterns or []))


def topic_from_path(path):
    """Return the topic slug if ``path`` is under ``<root>/<topic>/…`` else None."""
    clean = normalize_path(path)
    roots = []
    for r in ("docs/loen", normalize_path(artifact_root())):
        if r and r not in roots:
            roots.append(r)
    for root in roots:
        if not clean.startswith(root + "/"):
            continue
        candidate = clean[len(root) + 1:].split("/", 1)[0]
        if validate_topic_slug(candidate):
            return candidate
    return None


def is_loen_topic_path(path, topic_name):
    clean = normalize_path(path)
    root = normalize_path(os.path.join(artifact_root(), topic_name))
    return clean.startswith(f"docs/loen/{topic_name}/") or clean.startswith(root + "/")


# --- loop.yaml parsing -----------------------------------------------------

def _parse_scalar(value):
    value = value.strip().strip('"').strip("'")
    low = value.lower()
    if low == "true":
        return True
    if low == "false":
        return False
    return value


def _split_top(inner):
    """Split a flow-collection body on top-level commas (bracket-aware)."""
    parts, depth, cur = [], 0, ""
    for ch in inner:
        if ch in "{[":
            depth += 1; cur += ch
        elif ch in "}]":
            depth -= 1; cur += ch
        elif ch == "," and depth == 0:
            parts.append(cur); cur = ""
        else:
            cur += ch
    if cur.strip():
        parts.append(cur)
    return parts


def _parse_flow(value):
    value = value.strip()
    if value.startswith("{") and value.endswith("}"):
        inner = value[1:-1].strip()
        d = {}
        for part in _split_top(inner):
            if ":" in part:
                k, v = part.split(":", 1)
                d[k.strip().strip('"').strip("'")] = _parse_flow(v)
        return d
    if value.startswith("[") and value.endswith("]"):
        inner = value[1:-1].strip()
        return [_parse_flow(p) for p in _split_top(inner)] if inner else []
    return _parse_scalar(value)


def parse_loop_yaml(text):
    """Bespoke, bounded YAML-subset parser for loop.yaml.

    Supports block maps (2-space indent), block sequences (``- item``),
    inline flow maps ``{k: v}`` and inline flow lists ``[a, b]``. Values that
    open a block (a bare ``key:``) become a dict, or a list if the first child
    is a ``- item``.
    """
    root = {}
    # stack of dicts: (indent, container, parent, key_in_parent)
    stack = [(-1, root, None, None)]

    for raw in (text or "").splitlines():
        line = raw.split("#", 1)[0].rstrip()
        if not line.strip():
            continue
        indent = len(line) - len(line.lstrip(" "))
        stripped = line.strip()

        while len(stack) > 1 and indent <= stack[-1][0]:
            stack.pop()
        _, container, parent, pkey = stack[-1]

        if stripped.startswith("- "):
            # Ensure the current container is a list.
            if isinstance(container, dict):
                if container:
                    # non-empty dict cannot become a list; skip
                    continue
                newlist = []
                if parent is not None and pkey is not None:
                    parent[pkey] = newlist
                stack[-1] = (stack[-1][0], newlist, parent, pkey)
                container = newlist
            container.append(_parse_flow(stripped[2:]))
            continue

        if ":" not in stripped:
            continue
        key, value = stripped.split(":", 1)
        key = key.strip()
        value = value.strip()
        if not isinstance(container, dict):
            continue
        if value == "":
            child = {}
            container[key] = child
            stack.append((indent, child, container, key))
        else:
            container[key] = _parse_flow(value)

    _ensure_defaults(root)
    return root


def _ensure_defaults(data):
    data.setdefault("mutable_scope", [])
    data.setdefault("protected_scope", [])
    data.setdefault("quality_gates", [])
    data.setdefault("stop_conditions", [])
    data.setdefault("handoff_conditions", [])
    data.setdefault("stages", {})
    tools = data.setdefault("tools", {})
    tools.setdefault("allowed", [])
    tools.setdefault("denied", [])
    perms = data.setdefault("permissions", {})
    fs = perms.setdefault("filesystem", {})
    fs.setdefault("mutable_scope", [])
    fs.setdefault("protected_scope", [])
    net = perms.setdefault("network", {})
    net.setdefault("mode", "off")
    net.setdefault("allowlist", [])
    sh = perms.setdefault("shell", {})
    sh.setdefault("allow", [])
    sh.setdefault("deny_patterns", [])
    data.setdefault("run", {})
    # Mirror top-level scope into permissions.filesystem when it is empty.
    if data["mutable_scope"] and not fs["mutable_scope"]:
        fs["mutable_scope"] = list(data["mutable_scope"])
    if data["protected_scope"] and not fs["protected_scope"]:
        fs["protected_scope"] = list(data["protected_scope"])
    if "current_stage" in data:
        data["stage"] = data["current_stage"]
    elif "stage" in data:
        data["current_stage"] = data["stage"]


# --- topic discovery -------------------------------------------------------

def read_loop_artifact(topic_value):
    if not topic_value:
        return ""
    loop_file = os.path.join(artifact_root(), topic_value, "loop.yaml")
    if not os.path.isfile(loop_file):
        return ""
    try:
        with open(loop_file, encoding="utf-8") as fh:
            return fh.read()
    except (OSError, UnicodeDecodeError):
        return ""


def loop_policy(topic_value):
    return parse_loop_yaml(read_loop_artifact(topic_value))


def current_topic():
    """Active topic: the ``<root>/current`` pointer file, else the first
    topic whose loop.yaml has ``status: active``."""
    root = artifact_root()
    pointer = os.path.join(root, "current")
    if os.path.isfile(pointer):
        try:
            with open(pointer, encoding="utf-8") as fh:
                slug = fh.read().strip()
        except (OSError, UnicodeDecodeError):
            slug = ""
        if validate_topic_slug(slug) and os.path.isdir(os.path.join(root, slug)):
            return slug
    if os.path.isdir(root):
        for name in sorted(os.listdir(root)):
            loop_file = os.path.join(root, name, "loop.yaml")
            if validate_topic_slug(name) and os.path.isfile(loop_file):
                pol = parse_loop_yaml(read_loop_artifact(name))
                if str(pol.get("status", "")).strip() == "active":
                    return name
    return None


def extract_paths(event):
    inp = tool_input(event)
    paths = []
    for key in ("file_path", "path"):
        value = inp.get(key)
        if isinstance(value, str) and value.strip():
            paths.append(value.strip())
    return list(dict.fromkeys(paths))


def event_topic(event):
    explicit = os.environ.get("LOEN_TOPIC", "").strip()
    if explicit:
        return explicit
    for path in extract_paths(event):
        found = topic_from_path(path)
        if found:
            return found
    return current_topic()


def should_run_hook(event):
    """Return (should_run, topic)."""
    topic = event_topic(event)
    return ((not is_off()) and bool(topic), topic)
