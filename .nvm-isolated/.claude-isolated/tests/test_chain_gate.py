#!/usr/bin/env python3
"""Characterization tests for chain-gate.py — feed crafted payloads on stdin,
assert exit code / stdout. Run: python3 test_chain_gate.py (exit 0 = all pass)."""

import json
import os
import subprocess
import sys
import tempfile

HOOK = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "hooks", "chain-gate.py")


def body_hash(path):
    # First check if file has frontmatter; if not, hash entire file
    with open(path, "r", encoding="utf-8") as f:
        first_line = f.readline().strip()
    if first_line != "---":
        # No frontmatter; hash entire file as the "body"
        with open(path, "rb") as f:
            content = f.read()
        import hashlib
        return hashlib.sha256(content).hexdigest()[:16]

    # Has frontmatter; use canonical pipeline
    pipeline = (
        "awk 'BEGIN{fm=0} /^---$/{fm++; next} fm>=2{print}' "
        '"%s" | sha256sum | cut -c1-16' % path
    )
    out = subprocess.run(["bash", "-c", pipeline], capture_output=True, text=True, check=True)
    return out.stdout.strip()


def write_spec(path, validated):
    """Write a spec at `path`. validated=True → a passing review: block whose
    spec_hash matches the body; validated=False → no frontmatter (unvalidated)."""
    body = "# Design\n\nSome spec body.\n"
    with open(path, "w", encoding="utf-8") as f:
        f.write(body)
    if not validated:
        return
    h = body_hash(path)
    fm = (
        "---\n"
        "review:\n"
        "  spec_hash: %s\n"
        "  last_run: 2026-07-01\n"
        "  phases:\n"
        "    structure:   { status: passed }\n"
        "    coverage:    { status: passed }\n"
        "    clarity:     { status: passed }\n"
        "    consistency: { status: passed }\n"
        "  findings: []\n"
        "---\n" % h
    )
    with open(path, "w", encoding="utf-8") as f:
        f.write(fm + body)


def run(payload, event, cfg_dir, cwd):
    env = dict(os.environ, CLAUDE_CONFIG_DIR=cfg_dir)
    payload = dict(payload, hook_event_name=event)
    p = subprocess.run(
        ["python3", HOOK], input=json.dumps(payload),
        capture_output=True, text=True, env=env, cwd=cwd,
    )
    return p.returncode, p.stdout, p.stderr


def own(cfg_dir, abspath, sid):
    state = os.path.join(cfg_dir, "state")
    os.makedirs(state, exist_ok=True)
    with open(os.path.join(state, "idd-sessions.json"), "w", encoding="utf-8") as f:
        json.dump({abspath: {"session": sid, "ts": 9999999999}}, f)


def main():
    failures = []

    def check(name, cond):
        print(("PASS " if cond else "FAIL ") + name)
        if not cond:
            failures.append(name)

    with tempfile.TemporaryDirectory() as repo, tempfile.TemporaryDirectory() as cfg:
        specs = os.path.join(repo, "docs", "superpowers", "specs")
        os.makedirs(specs)
        spec = os.path.join(specs, "2026-07-01-foo-design.md")
        sid = "sess-1"

        # 1. fail-open on broken stdin
        env = dict(os.environ, CLAUDE_CONFIG_DIR=cfg)
        p = subprocess.run(["python3", HOOK], input="not json",
                           capture_output=True, text=True, env=env, cwd=repo)
        check("broken stdin → exit 0", p.returncode == 0)

        # 2. PreToolUse Skill not in GATE_MAP → allow
        rc, _, _ = run({"tool_name": "Skill", "session_id": sid,
                        "tool_input": {"skill": "frontend-design"}}, "PreToolUse", cfg, repo)
        check("ungated skill → exit 0", rc == 0)

        # 3. PreToolUse writing-plans, owned + unvalidated spec → block, names /check-chain spec
        write_spec(spec, validated=False)
        own(cfg, os.path.abspath(spec) if os.path.isabs(spec) else os.path.join(repo, "docs/superpowers/specs/2026-07-01-foo-design.md"), sid)
        own(cfg, os.path.join(repo, "docs/superpowers/specs/2026-07-01-foo-design.md"), sid)
        rc, _, err = run({"tool_name": "Skill", "session_id": sid,
                          "tool_input": {"skill": "superpowers:writing-plans"}}, "PreToolUse", cfg, repo)
        check("unvalidated spec → block exit 2", rc == 2)
        check("block message names /check-chain spec", "/check-chain spec" in err)

        # 4. PreToolUse writing-plans, owned + validated spec → allow
        write_spec(spec, validated=True)
        own(cfg, os.path.join(repo, "docs/superpowers/specs/2026-07-01-foo-design.md"), sid)
        rc, _, _ = run({"tool_name": "Skill", "session_id": sid,
                        "tool_input": {"skill": "superpowers:writing-plans"}}, "PreToolUse", cfg, repo)
        check("validated spec → exit 0", rc == 0)

        # 5. PostToolUse Write of unvalidated artifact → nudge naming /check-chain spec
        write_spec(spec, validated=False)
        rc, out, _ = run({"tool_name": "Write",
                          "tool_input": {"file_path": os.path.join(repo, "docs/superpowers/specs/2026-07-01-foo-design.md")},
                          "tool_response": {}}, "PostToolUse", cfg, repo)
        check("nudge → exit 0", rc == 0)
        check("nudge stdout names /check-chain spec", "/check-chain spec" in out)

        # 6. PostToolUse Write of validated artifact → silent
        write_spec(spec, validated=True)
        rc, out, _ = run({"tool_name": "Write",
                          "tool_input": {"file_path": os.path.join(repo, "docs/superpowers/specs/2026-07-01-foo-design.md")},
                          "tool_response": {}}, "PostToolUse", cfg, repo)
        check("validated artifact → silent (no stdout)", rc == 0 and out.strip() == "")

    print()
    if failures:
        print("FAILURES: %d" % len(failures))
        sys.exit(1)
    print("ALL PASS")


if __name__ == "__main__":
    main()
