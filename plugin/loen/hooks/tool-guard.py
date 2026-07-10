#!/usr/bin/env python3
"""PreToolUse tool-guard: the tool must be in tools.allowed, and the acting
role must be permitted for the loop's current_stage (stages.<stage>.roles).
Inert when no loop.yaml exists. Fails open on error."""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import loen_common as _c  # noqa: E402


def _role(event):
    """The explicitly-asserted role, or None. An unset role means the
    main-session worker (the orchestrator) — NOT constrained by stage roles;
    only dispatched subagents carry LOEN_ROLE / tool_input.role."""
    env_role = os.environ.get("LOEN_ROLE", "").strip()
    if env_role:
        return env_role
    role = _c.tool_input(event).get("role")
    return str(role).strip() if role else None


def main():
    event = _c.read_event()
    run, topic = _c.should_run_hook(event)
    if not run or not topic:
        return 0
    loop_text = _c.read_loop_artifact(topic)
    if not loop_text:
        return 0
    policy = _c.parse_loop_yaml(loop_text)
    name = _c.tool_name(event)

    allowed = (policy.get("tools") or {}).get("allowed") or []
    if allowed and name not in allowed:
        return _c.block_or_nudge(f"tool '{name}' not in tools.allowed for topic {topic}")

    role = _role(event)
    if role is None:
        return 0  # main-session worker (orchestrator): not stage-role-constrained
    stage = str(policy.get("current_stage") or policy.get("stage") or "").strip()
    stage_roles = ((policy.get("stages") or {}).get(stage) or {}).get("roles") or []
    if stage_roles and role not in stage_roles:
        return _c.block_or_nudge(
            f"role '{role}' not permitted for stage '{stage}' (allowed: {stage_roles})")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception:
        sys.exit(0)
