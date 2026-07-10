#!/usr/bin/env python3
"""Durable-state authority for loen topics (Claude Code runtime).

Owns the numbered stage-artifact set, topic scaffolding, the machine-readable
run-contract validation, the regenerated audit report, the docs/TODO.md row,
and the append-only attempts log. Stdlib only.
"""
from __future__ import annotations

import hashlib
import html
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import loen_common as _c  # noqa: E402

STAGE_FILES = [
    "1_goal.md", "2_context.md", "3_plan.md", "4_act.md",
    "5_check.md", "6_reflect.md", "7_result.md",
]

_VALID_MODES = ("delivery", "repair", "research", "review")


# --- hashing ---------------------------------------------------------------

def plan_body_hash(text):
    """sha256 (first 16 hex) of the plan body, excluding a leading YAML
    frontmatter block (``---\\n … \\n---\\n``)."""
    stripped = re.sub(r"\A---\n.*?\n---\n", "", text or "", count=1, flags=re.DOTALL)
    return hashlib.sha256(stripped.encode("utf-8")).hexdigest()[:16]


def _as_int(value, default=0):
    try:
        return int(str(value).strip())
    except (TypeError, ValueError):
        return default


# --- scaffolding -----------------------------------------------------------

def loop_yaml_text(topic, templates_dir=None, **overrides):
    """Render the loop.yaml template with the topic filled and optional
    top-level scalar overrides applied."""
    if templates_dir is None:
        templates_dir = os.path.join(os.path.dirname(__file__), "..", "assets", "templates")
    with open(os.path.join(templates_dir, "loop.yaml"), encoding="utf-8") as fh:
        text = fh.read()
    text = text.replace("{{topic}}", topic)
    for key, value in overrides.items():
        text = re.sub(rf"(?m)^{re.escape(key)}:.*$", f"{key}: {value}", text, count=1)
    return text


def scaffold_topic(topic, templates_dir, root):
    """Create ``<root>/<topic>/`` with the 7 stage files, loop.yaml, evidence/,
    and write the ``<root>/current`` pointer."""
    if not _c.validate_topic_slug(topic):
        raise ValueError(f"invalid topic slug: {topic!r}")
    topic_dir = os.path.join(root, topic)
    os.makedirs(os.path.join(topic_dir, "evidence"), exist_ok=True)
    for name in STAGE_FILES + ["handoff.md", "audit.html"]:
        src = os.path.join(templates_dir, name)
        dst = os.path.join(topic_dir, name)
        if os.path.isfile(src) and not os.path.exists(dst):
            text = open(src, encoding="utf-8").read().replace("{{topic}}", topic)
            with open(dst, "w", encoding="utf-8") as fh:
                fh.write(text)
    loop_path = os.path.join(topic_dir, "loop.yaml")
    if not os.path.exists(loop_path):
        with open(loop_path, "w", encoding="utf-8") as fh:
            fh.write(loop_yaml_text(topic, templates_dir))
    attempts = os.path.join(topic_dir, "attempts.jsonl")
    if not os.path.exists(attempts):
        open(attempts, "w", encoding="utf-8").close()
    os.makedirs(root, exist_ok=True)
    with open(os.path.join(root, "current"), "w", encoding="utf-8") as fh:
        fh.write(topic + "\n")


# --- run contract ----------------------------------------------------------

def validate_run_contract(loop, plan_text):
    """Return (ok, errors). The gate loop-run must pass before auto-running."""
    errors = []
    run = loop.get("run") or {}
    if run.get("plan_approved") is not True:
        errors.append("run.plan_approved must be true (approve the plan in loop-start)")
    expected = plan_body_hash(plan_text)
    if str(run.get("plan_hash") or "") != expected:
        errors.append(f"run.plan_hash mismatch (expected {expected})")
    mode = str(loop.get("mode") or "")
    if mode not in _VALID_MODES:
        errors.append(f"mode must be one of {_VALID_MODES}, got {mode!r}")
    if not (loop.get("mutable_scope") or []):
        errors.append("mutable_scope must be non-empty")
    if not (loop.get("quality_gates") or []):
        errors.append("quality_gates must define at least one verifier command")
    if _as_int((loop.get("budget") or {}).get("max_iterations"), 0) <= 0:
        errors.append("budget.max_iterations must be > 0")
    if not str(loop.get("rollback_policy") or "").strip():
        errors.append("rollback_policy must be non-empty")
    if mode == "research":
        if not any("target" in str(s).lower() for s in (loop.get("stop_conditions") or [])):
            errors.append("research mode needs a stop_condition containing 'target'")
    if mode == "review":
        has_scope = bool(loop.get("context_sources") or []) or bool(str(loop.get("review_scope") or "").strip())
        if not has_scope:
            errors.append("review mode needs a non-empty review scope (context_sources or review_scope)")
    return (not errors, errors)


# --- audit report ----------------------------------------------------------

def _read(topic_dir, name):
    path = os.path.join(topic_dir, name)
    if not os.path.isfile(path):
        return ""
    try:
        with open(path, encoding="utf-8") as fh:
            return fh.read()
    except (OSError, UnicodeDecodeError):
        return ""


def strip_comments(text):
    """Drop HTML comments so a sentinel word inside a template comment
    (e.g. '<!-- Write PASS ... -->') never counts as the real value."""
    return re.sub(r"<!--.*?-->", "", text or "", flags=re.DOTALL)


def render_audit(topic, root):
    """Regenerate ``<root>/<topic>/audit.html`` and return its text.

    Verdict is ``Done`` iff 7_result contains ``Done`` AND 5_check contains
    ``PASS`` AND ``evidence/`` is non-empty."""
    topic_dir = os.path.join(root, topic)
    policy = _c.parse_loop_yaml(_read(topic_dir, "loop.yaml"))
    evidence_dir = os.path.join(topic_dir, "evidence")
    evidence_nonempty = os.path.isdir(evidence_dir) and any(
        os.path.isfile(os.path.join(evidence_dir, f)) for f in os.listdir(evidence_dir)
    )
    done = (
        "Done" in strip_comments(_read(topic_dir, "7_result.md"))
        and "PASS" in strip_comments(_read(topic_dir, "5_check.md"))
        and evidence_nonempty
    )
    verdict = "Done" if done else "In progress"
    page = "\n".join([
        "<!doctype html>",
        "<html lang=\"en\">",
        "<head><meta charset=\"utf-8\"><title>loen audit: "
        + html.escape(topic) + "</title></head>",
        "<body>",
        f"<h1>loen audit: {html.escape(topic)}</h1>",
        f"<p>Status: {html.escape(str(policy.get('status', '')))}</p>",
        f"<p>Stage: {html.escape(str(policy.get('current_stage', policy.get('stage', ''))))}</p>",
        f"<p>Verdict: {verdict}</p>",
        "</body>",
        "</html>",
        "",
    ])
    os.makedirs(topic_dir, exist_ok=True)
    with open(os.path.join(topic_dir, "audit.html"), "w", encoding="utf-8") as fh:
        fh.write(page)
    return page


# --- TODO.md row -----------------------------------------------------------

_TODO_HEADER = "| Topic | Status | Intent | Spec | Plan | Result | Opened | Closed | Notes |"
_TODO_SEP = "|---|---|---|---|---|---|---|---|---|"


_LOEN_NOTE = "loen runtime"


def _row_cells(line):
    # "| a | b | c |" -> ["a","b","c"]
    return [c.strip() for c in line.strip().strip("|").split("|")]


def upsert_todo_row(topic, stage, verdict, today, path="docs/TODO.md"):
    """Idempotently upsert the topic's row in docs/TODO.md (keyed by topic).

    Never clobbers a row managed by another tool (e.g. check-chain): a row is
    loen-owned only if its Notes cell contains 'loen runtime'. For a loen-owned
    row, preserve Intent/Spec/Plan/Opened and update only Status/Result/Closed.
    """
    status = "done" if verdict == "OK" else "in-progress"
    if os.path.isfile(path):
        lines = open(path, encoding="utf-8").read().splitlines()
    else:
        lines = [_TODO_HEADER, _TODO_SEP]
    prefix = f"| {topic} |"
    idx = next((i for i, ln in enumerate(lines) if ln.startswith(prefix)), None)
    if idx is not None:
        cells = _row_cells(lines[idx])
        # cells: Topic Status Intent Spec Plan Result Opened Closed Notes
        if len(cells) >= 9 and _LOEN_NOTE not in cells[8]:
            return  # foreign row (check-chain etc.) — do not clobber
        intent = cells[2] if len(cells) > 2 else "–"
        spec = cells[3] if len(cells) > 3 else "–"
        plan = cells[4] if len(cells) > 4 else "–"
        opened = cells[6] if len(cells) > 6 and cells[6] else today
        closed = today if status == "done" else (cells[7] if len(cells) > 7 else "")
        lines[idx] = (f"| {topic} | {status} | {intent} | {spec} | {plan} | "
                      f"{verdict} | {opened} | {closed} | {_LOEN_NOTE} |")
    else:
        closed = today if status == "done" else ""
        lines.append(f"| {topic} | {status} | – | – | – | {verdict} | "
                     f"{today} | {closed} | {_LOEN_NOTE} |")
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    with open(path, "w", encoding="utf-8") as fh:
        fh.write("\n".join(lines) + "\n")


# --- attempts log ----------------------------------------------------------

def clear_current(root):
    """Remove the docs/loen/current pointer (call on a loop's terminal so a
    finished topic never gates unrelated project work)."""
    pointer = os.path.join(root, "current")
    try:
        if os.path.isfile(pointer):
            os.remove(pointer)
    except OSError:
        pass


def append_attempt(topic, record, root):
    topic_dir = os.path.join(root, topic)
    os.makedirs(topic_dir, exist_ok=True)
    line = json.dumps(record, sort_keys=True, separators=(",", ":"))
    with open(os.path.join(topic_dir, "attempts.jsonl"), "a", encoding="utf-8") as fh:
        fh.write(line + "\n")
