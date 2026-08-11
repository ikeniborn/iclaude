#!/usr/bin/env python3
"""Bounded context capsules for loen role subagents.

A capsule is a fixed text block built ONLY from durable artifacts under a
topic directory — never from chat history. Handing a subagent a capsule (plus
the relative topic path) is the L1 isolation mechanism: the loop survives
context compaction and new threads because state lives on disk. Stdlib only.
"""
from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import loen_common as _c  # noqa: E402


def _read(topic_dir, name):
    path = os.path.join(topic_dir, name)
    if not os.path.isfile(path):
        return ""
    try:
        with open(path, encoding="utf-8") as fh:
            return fh.read()
    except (OSError, UnicodeDecodeError):
        return ""


def _relevant_files(context_md):
    """Lines under the Facts / Relevant Files sections that reference a path."""
    out = []
    for line in context_md.splitlines():
        s = line.strip()
        if s.startswith("- ") and ("relevant" in s.lower() or "/" in s or "." in s):
            out.append(s[2:].strip())
    return out[:12]


def _last_evidence(check_md):
    """The last non-empty, non-heading line of 5_check.md."""
    for line in reversed(check_md.splitlines()):
        s = line.strip()
        if s and not s.startswith("#") and not s.startswith("```"):
            return s
    return ""


def render_capsule(topic_dir, role, question):
    """Return a bounded capsule text for ``role`` answering ``question``."""
    policy = _c.parse_loop_yaml(_read(topic_dir, "loop.yaml"))
    topic = str(policy.get("topic") or os.path.basename(os.path.normpath(topic_dir)))
    mutable = policy.get("mutable_scope") or []
    protected = policy.get("protected_scope") or []
    gates = policy.get("quality_gates") or []
    relevant = _relevant_files(_read(topic_dir, "2_context.md"))
    last_evidence = _last_evidence(_read(topic_dir, "5_check.md"))
    lines = [
        "# loen capsule",
        f"Topic: {topic}",
        f"Objective: {policy.get('objective', '')}",
        f"Loop mode: {policy.get('mode', '')}",
        f"Current stage: {policy.get('current_stage', policy.get('stage', ''))}",
        f"Mutable scope: {', '.join(map(str, mutable))}",
        f"Protected scope: {', '.join(map(str, protected))}",
        f"Quality gates: {', '.join(map(str, gates))}",
        f"Relevant files: {', '.join(relevant) if relevant else '(none listed)'}",
        f"Last evidence: {last_evidence or '(none)'}",
        f"Topic directory (read here, not chat): {topic_dir}",
        "",
        f"Role: {role}",
        f"Question: {question}",
    ]
    return "\n".join(lines)
