#!/usr/bin/env python3
"""PreToolUse loop-gate: edits to numbered stage artifacts require an active
loop and correct stage ordering (no N_*.md while a lower-numbered artifact is
missing); 7_result requires 5_check.md to contain PASS. Fails open on error."""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import loen_common as _c  # noqa: E402
import loen_artifacts as _a  # noqa: E402

_STAGE_RE = re.compile(r"^([1-7])_.*\.md$")


def _stage_complete(path):
    """A lower stage counts as done only if its file exists AND has been filled
    (no unfilled ``{{placeholder}}`` left from the scaffold template). This keeps
    the ordering guard meaningful even though scaffold pre-creates all 7 files."""
    if not os.path.isfile(path):
        return False
    try:
        with open(path, encoding="utf-8") as fh:
            return "{{" not in fh.read()
    except (OSError, UnicodeDecodeError):
        return False


def main():
    event = _c.read_event()
    run, topic = _c.should_run_hook(event)
    if not run or not topic:
        return 0
    if _c.tool_class(_c.tool_name(event)) != "edit":
        return 0
    loop_text = _c.read_loop_artifact(topic)
    if not loop_text:
        return 0  # no loop.yaml -> no contract -> plugin is inert
    topic_dir = os.path.join(_c.artifact_root(), topic)
    policy = _c.parse_loop_yaml(loop_text)
    for path in _c.extract_paths(event):
        base = os.path.basename(_c.normalize_path(path))
        m = _STAGE_RE.match(base)
        if not m or not _c.is_loen_topic_path(path, topic):
            continue
        if str(policy.get("status", "")).strip() != "active":
            return _c.block_or_nudge("no active loop: bootstrap the run first")
        n = int(m.group(1))
        for k in range(1, n):
            prev = _a.STAGE_FILES[k - 1]
            if not _stage_complete(os.path.join(topic_dir, prev)):
                return _c.block_or_nudge(
                    f"stage ordering: cannot write {base} while {prev} is not yet filled")
        if n == 7:
            check_path = os.path.join(topic_dir, "5_check.md")
            text = ""
            if os.path.isfile(check_path):
                text = _a.strip_comments(open(check_path, encoding="utf-8").read())
            if "PASS" not in text:
                return _c.block_or_nudge("7_result requires 5_check.md to contain PASS")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception:
        sys.exit(0)
