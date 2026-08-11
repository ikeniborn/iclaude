#!/usr/bin/env python3
"""loen governance aggregator (deterministic, offline) — topic layout.

Scans a docs/loen/ tree of durable topics (docs/loen/<topic>/) and emits ONE
JSON summary on stdout: per-topic facts plus cross-topic totals — loop success
rate, keep/revert counts, handoff reasons, failure taxonomy (REJECT verdicts'
numbered REQUIRED FIXES items), foreign (layout-drift) entries. Restates
artifact evidence only; cost/tokens and latency/VRAM are reported "unavailable".

stdlib only, read-only, no network. Empty or missing root -> valid empty
summary, exit 0 (governance over zero topics is not an error)."""
import argparse
import json
import os
import re

TOPIC = re.compile(r"^[a-z0-9][a-z0-9-]*$")
CANON_TOP = {"current", "governance.html"}
VERDICT = re.compile(r"^VERDICT:\s*(APPROVE|REJECT)\b")
FIXES_HEADER = re.compile(r"^REQUIRED FIXES:")
FIX_ITEM = re.compile(r"^\s*(\d+)[.)]\s+(.+?)\s*$")
SECTION = re.compile(r"^[A-Z][A-Z ]+:")


def read_lines(path):
    try:
        with open(path, encoding="utf-8") as f:
            return f.read().splitlines()
    except (OSError, UnicodeDecodeError):
        return None


def scalar(lines, key):
    for s in lines or []:
        m = re.match(rf"^{re.escape(key)}:\s*(.*)$", s)
        if m:
            return m.group(1).strip().strip('"').strip("'")
    return None


def parse_verdict(lines):
    for s in lines or []:
        m = VERDICT.match(s.strip())
        if m:
            return m.group(1)
    return None


def parse_fixes(lines):
    items, in_fixes = [], False
    for s in lines or []:
        stripped = s.strip()
        if FIXES_HEADER.match(stripped):
            in_fixes = True
            continue
        if not in_fixes:
            continue
        m = FIX_ITEM.match(s)
        if m:
            items.append(m.group(2))
        elif SECTION.match(stripped):
            in_fixes = False
    return items


def research_stats(topic_dir):
    lines = read_lines(os.path.join(topic_dir, "experiments.jsonl"))
    if lines is None:
        return None
    experiments = keep = revert = 0
    for raw in lines:
        raw = raw.strip()
        if not raw:
            continue
        try:
            rec = json.loads(raw)
        except ValueError:
            continue
        if rec.get("type") == "experiment":
            experiments += 1
            if rec.get("decision") == "keep":
                keep += 1
            elif rec.get("decision") == "revert":
                revert += 1
    return {"experiments": experiments, "keep": keep, "revert": revert}


def scan_topic(root, topic):
    d = os.path.join(root, topic)
    loop_lines = read_lines(os.path.join(d, "loop.yaml"))
    verdict_lines = read_lines(os.path.join(d, "evidence", "verifier-verdict.md"))
    verdict = parse_verdict(verdict_lines)
    fixes = parse_fixes(verdict_lines) if verdict == "REJECT" else []
    handoff = os.path.isfile(os.path.join(d, "handoff.md")) and \
        "status: handoff" in "\n".join(loop_lines or [])
    handoff_reason = None
    if handoff:
        hl = read_lines(os.path.join(d, "handoff.md")) or []
        grab = False
        for s in hl:
            if s.strip().startswith("## Required Human Decision"):
                grab = True
                continue
            if grab and s.strip():
                handoff_reason = s.strip()
                break
    topic_rec = {
        "topic": topic,
        "mode": scalar(loop_lines, "mode"),
        "status": scalar(loop_lines, "status"),
        "verdict": verdict,
        "research": research_stats(d),
    }
    return topic_rec, fixes, handoff_reason


def main():
    ap = argparse.ArgumentParser(description="loen cross-topic governance aggregator")
    ap.add_argument("--root", default=os.path.join("docs", "loen"))
    args = ap.parse_args()
    root = args.root

    topics, foreign = [], []
    by_mode, taxonomy = {}, {}
    keep = revert = done = 0
    handoff_reasons = []
    entries = sorted(os.listdir(root)) if os.path.isdir(root) else []
    for entry in entries:
        if entry in CANON_TOP:
            continue
        full = os.path.join(root, entry)
        if not (os.path.isdir(full) and TOPIC.match(entry)
                and os.path.isfile(os.path.join(full, "loop.yaml"))):
            foreign.append(entry)
            continue
        rec, fixes, handoff_reason = scan_topic(root, entry)
        topics.append(rec)
        by_mode[rec["mode"] or "unknown"] = by_mode.get(rec["mode"] or "unknown", 0) + 1
        if rec["status"] == "done" or rec["verdict"] == "APPROVE":
            done += 1
        for item in fixes:
            taxonomy[item] = taxonomy.get(item, 0) + 1
        if handoff_reason:
            handoff_reasons.append(handoff_reason)
        if rec["research"]:
            keep += rec["research"]["keep"]
            revert += rec["research"]["revert"]

    summary = {
        "root": root.replace(os.sep, "/"),
        "topics": topics,
        "foreign": foreign,
        "totals": {
            "topics_by_mode": by_mode,
            "success_rate": (done / len(topics)) if topics else None,
            "keep": keep,
            "revert": revert,
            "handoff_reasons": handoff_reasons,
            "failure_taxonomy": taxonomy,
            "cost_tokens": "unavailable",
            "latency_vram": "unavailable",
        },
    }
    print(json.dumps(summary, ensure_ascii=False, indent=2, sort_keys=True))


if __name__ == "__main__":
    main()
