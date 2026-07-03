#!/usr/bin/env python3
"""loen governance aggregator (deterministic, offline).

Scans a docs/loen/ tree and emits ONE JSON summary on stdout: per-run
facts plus cross-run totals — loop success rate, keep/revert counts,
handoff/stop reasons, failure taxonomy (REJECT verdicts' numbered
REQUIRED FIXES items; gates.log is free-form and deliberately NOT
parsed), protected-path alerts, foreign (layout-drift) entries.
Restates artifact evidence only; the dashboards loen artifacts cannot
back (cost/tokens, latency/VRAM) are reported as "unavailable".

stdlib only, read-only, no network. Empty or missing root -> valid
empty summary, exit 0 (governance over zero runs is not an error)."""
import argparse
import json
import os
import re

RUN_ID = re.compile(r"^\d{4}-\d{2}-\d{2}-[a-z0-9-]+$")
CANON_TOP = {"current", "RUNBOOK.md", "governance.html"}
ITER_DIR = re.compile(r"^iter-\d{2}$")
VERDICT = re.compile(r"^VERDICT:\s*(APPROVE|REJECT)\b")
FIXES_HEADER = re.compile(r"^REQUIRED FIXES:")
FIX_ITEM = re.compile(r"^\s*(\d+)[.)]\s+(.+?)\s*$")
SECTION = re.compile(r"^[A-Z][A-Z ]+:")
PROTECTED_ALERT = re.compile(r"^ERROR: protected path changed:")
HANDOFF = re.compile(
    r"^\s*(?:[-*]\s*)?(?:handoff|stop)\s*:\s*(.+?)\s*$", re.IGNORECASE)


def read_lines(path):
    """File content as a line list, or None when unreadable."""
    try:
        with open(path, encoding="utf-8") as f:
            return f.read().splitlines()
    except (OSError, UnicodeDecodeError):
        return None


def parse_mode(lines):
    for s in lines or []:
        m = re.match(r"^mode:\s*(\S+)", s)
        if m:
            return m.group(1)
    return None


def parse_primary(lines):
    """Name of the first metrics.primary '<name>:max|min' entry, or
    None. Handles the block-style template layout and inline flow
    lists, like the hook's loop.yaml parsing."""
    in_metrics = in_primary = False
    for s in lines or []:
        if re.match(r"^metrics:\s*$", s):
            in_metrics, in_primary = True, False
            continue
        if in_metrics and re.match(r"^\S", s):
            break
        if not in_metrics:
            continue
        m = re.match(r"^\s+primary:\s*(.*)$", s)
        if m:
            rest = m.group(1).strip()
            fm = re.match(r"^\[([^\]]*)\]$", rest)
            if fm:
                for entry in fm.group(1).split(","):
                    em = re.match(r"^([\w.-]+):(max|min)$",
                                  entry.strip().strip("\"'"))
                    if em:
                        return em.group(1)
                return None
            in_primary = not rest
            continue
        if in_primary:
            im = re.match(r"^\s*-\s*([\w.-]+):(max|min)\s*$", s)
            if im:
                return im.group(1)
            if re.match(r"^\s+[\w-]+:", s):
                in_primary = False
    return None


def parse_verdict(lines):
    for s in lines:
        m = VERDICT.match(s.strip())
        if m:
            return m.group(1)
    return None


def parse_fixes(lines):
    """Numbered items of the REQUIRED FIXES: section."""
    items, in_fixes = [], False
    for s in lines:
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


def parse_handoffs(lines):
    """'handoff:'/'stop:' reasons inside the state.md Attempts
    section, restated verbatim."""
    reasons, in_attempts = [], False
    for s in lines or []:
        if re.match(r"^##\s+Attempts\b", s):
            in_attempts = True
            continue
        if re.match(r"^##\s", s):
            in_attempts = False
            continue
        if in_attempts:
            m = HANDOFF.match(s)
            if m:
                reasons.append(m.group(1))
    return reasons


def research_stats(run_dir, primary):
    """experiments.jsonl extras, or None when the stream is absent."""
    lines = read_lines(os.path.join(run_dir, "experiments.jsonl"))
    if lines is None:
        return None
    experiments = keep = revert = 0
    first = last = None
    for raw in lines:
        raw = raw.strip()
        if not raw:
            continue
        try:
            rec = json.loads(raw)
        except ValueError:
            continue
        vals = None
        rtype = rec.get("type")
        if rtype == "baseline":
            vals = rec.get("metrics")
        elif rtype == "experiment":
            experiments += 1
            if rec.get("decision") == "keep":
                keep += 1
            elif rec.get("decision") == "revert":
                revert += 1
            # a reverted record's metrics_after is null: the last
            # observed value is then its metrics_before (= last kept)
            vals = rec.get("metrics_after") or rec.get("metrics_before")
        if primary and isinstance(vals, dict) and primary in vals:
            if first is None:
                first = vals[primary]
            last = vals[primary]
    return {"experiments": experiments, "keep": keep, "revert": revert,
            "primary": primary, "primary_first": first,
            "primary_last": last}


def scan_run(root, run_id):
    """One run's facts + the pieces totals aggregates over."""
    d = os.path.join(root, run_id)
    loop_lines = read_lines(os.path.join(d, "loop.yaml"))
    iters_dir = os.path.join(d, "iterations")
    iters = sorted(
        e for e in (os.listdir(iters_dir)
                    if os.path.isdir(iters_dir) else [])
        if ITER_DIR.match(e))
    gates_log, verdicts, fixes = {}, {}, []
    alerts = 0
    for it in iters:
        ip = os.path.join(iters_dir, it)
        gates_log[it] = os.path.isfile(os.path.join(ip, "gates.log"))
        if gates_log[it]:
            for s in read_lines(os.path.join(ip, "gates.log")) or []:
                if PROTECTED_ALERT.match(s):
                    alerts += 1
        vlines = read_lines(os.path.join(ip, "verifier.md"))
        if vlines is not None:
            verdicts[it] = parse_verdict(vlines)
            if verdicts[it] == "REJECT":
                fixes.extend(parse_fixes(vlines))
    last_verdict = None
    for it in iters:
        if verdicts.get(it):
            last_verdict = verdicts[it]
    final_verdict = verdicts.get(iters[-1]) if iters else None
    run = {
        "run_id": run_id,
        "mode": parse_mode(loop_lines),
        "iterations": len(iters),
        "last_verdict": last_verdict,
        "gates_log": gates_log,
        "research": research_stats(d, parse_primary(loop_lines)),
    }
    handoffs = parse_handoffs(read_lines(os.path.join(d, "state.md")))
    return run, final_verdict, fixes, alerts, handoffs


def main():
    ap = argparse.ArgumentParser(
        description="loen cross-run governance aggregator")
    ap.add_argument("--root", default=os.path.join("docs", "loen"),
                    help="docs/loen root (default: resolve from CWD)")
    args = ap.parse_args()
    root = args.root

    runs, foreign = [], []
    by_mode, taxonomy = {}, {}
    keep = revert = alerts = approved = 0
    handoff_reasons = []
    entries = sorted(os.listdir(root)) if os.path.isdir(root) else []
    for entry in entries:
        if entry in CANON_TOP:
            continue
        if not RUN_ID.match(entry):
            foreign.append(entry)
            continue
        run, final_verdict, fixes, run_alerts, handoffs = scan_run(
            root, entry)
        runs.append(run)
        mode_key = run["mode"] or "unknown"
        by_mode[mode_key] = by_mode.get(mode_key, 0) + 1
        if final_verdict == "APPROVE":
            approved += 1
        for item in fixes:
            taxonomy[item] = taxonomy.get(item, 0) + 1
        alerts += run_alerts
        handoff_reasons.extend(handoffs)
        if run["research"]:
            keep += run["research"]["keep"]
            revert += run["research"]["revert"]

    summary = {
        "root": root.replace(os.sep, "/"),
        "runs": runs,
        "foreign": foreign,
        "totals": {
            "runs_by_mode": by_mode,
            "success_rate": (approved / len(runs)) if runs else None,
            "keep": keep,
            "revert": revert,
            "handoff_reasons": handoff_reasons,
            "failure_taxonomy": taxonomy,
            "protected_alerts": alerts,
            "cost_tokens": "unavailable",
            "latency_vram": "unavailable",
        },
    }
    print(json.dumps(summary, ensure_ascii=False, indent=2,
                     sort_keys=True))


if __name__ == "__main__":
    main()
