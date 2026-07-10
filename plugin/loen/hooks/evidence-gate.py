#!/usr/bin/env python3
"""Stop hook evidence-gate: when the loop signals completion (loop.yaml
status: done), require 5_check.md, 7_result.md, a verifier verdict, and a
non-empty evidence/ before letting the turn stop. In strict mode also require
distinct worker vs verifier identities. Inert without a done-signalling loop."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import loen_common as _c  # noqa: E402


def _has_verdict(evidence_dir):
    if not os.path.isdir(evidence_dir):
        return False
    for name in os.listdir(evidence_dir):
        if "verdict" in name.lower() and os.path.isfile(os.path.join(evidence_dir, name)):
            return True
    return False


def main():
    event = _c.read_event()
    if _c.is_off():
        return 0
    topic = _c.event_topic(event)
    if not topic:
        return 0
    loop_text = _c.read_loop_artifact(topic)
    if not loop_text:
        return 0
    policy = _c.parse_loop_yaml(loop_text)
    if str(policy.get("status", "")).strip() != "done":
        return 0  # not a done-signalling stop

    topic_dir = os.path.join(_c.artifact_root(), topic)
    evidence_dir = os.path.join(topic_dir, "evidence")
    missing = []
    if not os.path.isfile(os.path.join(topic_dir, "5_check.md")):
        missing.append("5_check.md")
    if not os.path.isfile(os.path.join(topic_dir, "7_result.md")):
        missing.append("7_result.md")
    if not _has_verdict(evidence_dir):
        missing.append("evidence/verifier-verdict.md")
    if not (os.path.isdir(evidence_dir) and os.listdir(evidence_dir)):
        missing.append("evidence/ (non-empty)")
    if missing:
        return _c.block_or_nudge(
            "loop marked done but evidence is missing: " + ", ".join(missing))

    if _c.is_strict():
        worker = os.path.join(evidence_dir, "worker-id")
        verifier = os.path.join(evidence_dir, "verifier-id")
        if os.path.isfile(worker) and os.path.isfile(verifier):
            if open(worker).read().strip() == open(verifier).read().strip():
                return _c.block_or_nudge("strict mode: worker and verifier identities must differ")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception:
        sys.exit(0)
