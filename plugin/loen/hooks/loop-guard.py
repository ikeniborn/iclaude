#!/usr/bin/env python3
"""loen loop-guard — deterministic PreToolUse guard for
Write|Edit|MultiEdit.

A. Layout/naming enforcement for writes under docs/loen/ (within the
   active topic).
B. Scope enforcement elsewhere (protected_scope / mutable_scope from
   the active loop.yaml).

No-op when there is no active loop (docs/loen/current absent) for
non-loen paths. Composes with the always-on secret-blocking hooks
(separate). Exit 0 = allow. Exit 2 = block (reason on stderr)."""
import fnmatch
import json
import os
import re
import sys

LOEN_ROOT = "docs/loen"
CURRENT = os.path.join(LOEN_ROOT, "current")
RUN_ID = re.compile(r"^\d{4}-\d{2}-\d{2}-[a-z0-9-]+$")

ITER_FILES = r"(diff\.patch|gates\.log|verifier\.md|metrics\.jsonl)"


def canon_patterns(R):
    Rq = re.escape(R)
    return [
        re.compile(r"^docs/loen/current$"),
        re.compile(r"^docs/loen/RUNBOOK\.md$"),
        re.compile(r"^docs/loen/governance\.html$"),
        re.compile(rf"^docs/loen/{Rq}/loop\.yaml$"),
        re.compile(rf"^docs/loen/{Rq}/plan\.md$"),
        re.compile(rf"^docs/loen/{Rq}/state\.md$"),
        re.compile(rf"^docs/loen/{Rq}/pr-summary\.md$"),
        re.compile(rf"^docs/loen/{Rq}/report\.html$"),
        re.compile(rf"^docs/loen/{Rq}/experiments\.jsonl$"),
        re.compile(
            rf"^docs/loen/{Rq}/iterations/iter-\d{{2}}/{ITER_FILES}$"),
    ]


def rel(path):
    try:
        p = os.path.relpath(os.path.abspath(path), os.getcwd())
        return p.replace(os.sep, "/")
    except Exception:
        return path


def active_run():
    """Return the run-id from the docs/loen/current symlink, or None."""
    if os.path.islink(CURRENT):
        return os.path.basename(os.readlink(CURRENT).rstrip("/"))
    return None


def _inline_list(s):
    """Parse 'key: [a, b]' -> [a, b]; None if not an inline flow list."""
    m = re.match(r"^[\w-]+:\s*\[(.*)\]\s*$", s)
    if m is None:
        return None
    body = m.group(1).strip()
    if not body:
        return []
    return [x.strip().strip('"').strip("'")
            for x in body.split(",") if x.strip()]


def load_scope(R):
    """Return (mutable, protected) glob lists from the active loop.yaml,
    or ([], []). Handles BOTH block-style lists and inline flow lists
    ('key: [a, b]')."""
    ly = os.path.join(LOEN_ROOT, R, "loop.yaml") if R else None
    if not ly or not os.path.exists(ly):
        return [], []
    mutable, protected, cur = [], [], None
    with open(ly, encoding="utf-8") as f:
        for line in f:
            s = line.rstrip("\n")
            if re.match(r"^mutable_scope:", s):
                hit = mutable
            elif re.match(r"^protected_scope:", s):
                hit = protected
            else:
                hit = None
            if hit is not None:
                inline = _inline_list(s)
                if inline is None:
                    cur = hit          # block-style list on next lines
                else:
                    hit.extend(inline)  # inline flow list on this line
                    cur = None
                continue
            if re.match(r"^[A-Za-z_]", s):
                cur = None
                continue
            m = re.match(r"^\s*-\s*(.+?)\s*$", s)
            if m and cur is not None:
                cur.append(m.group(1).strip().strip('"').strip("'"))
    return mutable, protected


def block(msg):
    sys.stderr.write("loen loop-guard: " + msg + "\n")
    sys.exit(2)


def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        sys.exit(0)
    fp = (data.get("tool_input") or {}).get("file_path")
    if not fp:
        sys.exit(0)
    path = rel(fp)
    R = active_run()

    if path == "docs/loen/current":
        # bootstrap: setting the active-run pointer is always allowed
        sys.exit(0)
    if path == "docs/loen/RUNBOOK.md":
        sys.exit(0)
    if path == "docs/loen/governance.html":
        sys.exit(0)

    if path.startswith("docs/loen/"):
        if R is None:
            block("no active loop (docs/loen/current missing); "
                  "bootstrap the run first")
        m = re.match(r"^docs/loen/([^/]+)/", path)
        seg = m.group(1) if m else ""
        if not RUN_ID.match(seg):
            block(f"malformed run-id segment '{seg}' "
                  f"(expected <YYYY-MM-DD>-<topic>)")
        if seg != R:
            block(f"cross-topic write: '{seg}' != active run '{R}' — "
                  f"stay within the active topic")
        for pat in canon_patterns(R):
            if pat.match(path):
                sys.exit(0)
        block(
            f"non-canonical loen artifact path: {path}\n"
            f"  expected: docs/loen/{R}/{{loop.yaml,plan.md,state.md,"
            f"pr-summary.md,report.html,experiments.jsonl}}\n"
            f"  or:       docs/loen/{R}/iterations/iter-NN/"
            f"{{diff.patch,gates.log,verifier.md,metrics.jsonl}}\n"
            f"  top-level: docs/loen/{{current,RUNBOOK.md,"
            f"governance.html}}"
        )

    # outside docs/loen/ -> scope enforcement, only when a loop is active
    if R is None:
        sys.exit(0)
    mutable, protected = load_scope(R)
    for g in protected:
        if fnmatch.fnmatch(path, g):
            block(f"protected_scope violation: {path} matches '{g}'")
    if mutable and not any(fnmatch.fnmatch(path, g) for g in mutable):
        block(f"out-of-scope edit: {path} not in mutable_scope {mutable}")
    sys.exit(0)


if __name__ == "__main__":
    try:
        main()
    except SystemExit:
        raise             # deliberate allow (exit 0) / block (exit 2)
    except Exception:
        sys.exit(0)       # fail-open: guard crash must never block edits
