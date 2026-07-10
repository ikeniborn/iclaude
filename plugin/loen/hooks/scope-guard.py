#!/usr/bin/env python3
"""PreToolUse scope-guard: block edits to protected_scope and edits outside
mutable_scope. The topic's own directory is always writable. Fails open on any
unexpected error (outside enforce/strict the shared primitive never blocks)."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import loen_common as _c  # noqa: E402


def main():
    event = _c.read_event()
    run, topic = _c.should_run_hook(event)
    if not run or not topic:
        return 0
    if _c.tool_class(_c.tool_name(event)) != "edit":
        return 0
    loop_text = _c.read_loop_artifact(topic)
    if not loop_text:
        return 0  # no loop.yaml -> inert
    policy = _c.parse_loop_yaml(loop_text)
    if str(policy.get("status", "")).strip() != "active":
        return 0  # a finished/paused loop must not gate the whole project
    fs = (policy.get("permissions") or {}).get("filesystem") or {}
    protected = fs.get("protected_scope") or []
    mutable = fs.get("mutable_scope") or []
    for path in _c.extract_paths(event):
        if _c.is_loen_topic_path(path, topic):
            continue
        if _c.matches_any(path, protected):
            return _c.block_or_nudge(f"protected_scope edit blocked: {path}")
        if mutable and not _c.matches_any(path, mutable):
            return _c.block_or_nudge(f"out-of-scope edit blocked (not in mutable_scope): {path}")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception:
        sys.exit(0)
