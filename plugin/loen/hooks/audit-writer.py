#!/usr/bin/env python3
"""PostToolUse audit-writer: regenerate the topic's audit.html and upsert its
docs/TODO.md row. Side-effecting only — never blocks (always exit 0)."""
import datetime
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import loen_common as _c  # noqa: E402
import loen_artifacts as _a  # noqa: E402


def main():
    event = _c.read_event()
    if _c.is_off():
        return 0
    topic = _c.event_topic(event)
    if not topic or not _c.validate_topic_slug(topic):
        return 0
    if not _c.read_loop_artifact(topic):
        return 0
    root = _c.artifact_root()
    policy = _c.loop_policy(topic)
    status = str(policy.get("status") or "").strip()
    if status != "active":
        return 0  # inert once the loop is finished — no churn on unrelated work
    stage = str(policy.get("current_stage") or policy.get("stage") or "")
    verdict = "–"
    today = os.environ.get("LOEN_TODAY") or datetime.date.today().isoformat()
    _a.render_audit(topic, root)
    _a.upsert_todo_row(topic, stage, verdict, today)
    return 0


if __name__ == "__main__":
    try:
        main()
    except Exception:
        pass
    sys.exit(0)
