#!/usr/bin/env python3
"""
PostToolUse hook — IDD→SDD post-artifact nudge.

After a skill produces an IDD/SDD artifact (intent / spec / plan) via the Write
tool, suggest running the matching /check-* validator — so the artifact is
validated right after creation instead of only being caught later at the next
transition by the PreToolUse phase gate (idd-gate.py).

A hook cannot run a slash command directly; it injects `additionalContext`
(PostToolUse) and Claude decides to act on it. The nudge is emitted ONLY when
the artifact is not yet validated for its current body (no passing `review:`
with a matching body hash). A validated artifact stays silent — so there is no
loop when /check-* later writes its frontmatter back (body unchanged → hash
still matches → silent).

check-result is intentionally NOT nudged here: it needs `git diff` + a plan
path and runs at branch-finish, not on an artifact write. That transition stays
covered by idd-gate.py via the finishing-a-development-branch skill.

Exit codes:
  0 — always. PostToolUse is advisory and must never disrupt the write.
      JSON on stdout = nudge; no stdout = silent.

Fail-open: any internal error → exit 0. A bug in the nudge must not break Write.
"""

import sys
import os
import json
import subprocess
import fnmatch

DOCS_ROOT = "docs/superpowers"

# Severities that mean "still needs work" → keep nudging until resolved.
BLOCK_ON = {"CRITICAL"}

# artifact dir → glob + state block + body-hash key + validator command.
# Mirrors the path rules in idd-gate.py GATE_MAP, keyed by artifact (not skill).
ARTIFACT_RULES = [
    {"dir": "intents", "glob": "*-intent.md", "block": "review",
     "hash_key": "intent_hash", "fix": "/check-intent"},
    {"dir": "specs", "glob": "*-design.md", "block": "review",
     "hash_key": "spec_hash", "fix": "/check-spec"},
    {"dir": "plans", "glob": "*.md", "block": "review",
     "hash_key": "plan_hash", "fix": "/check-plan"},
]


def rule_for(path):
    """Rule whose dir+glob matches path (under DOCS_ROOT), else None."""
    ap = os.path.abspath(path)
    for rule in ARTIFACT_RULES:
        root = os.path.abspath(os.path.join(DOCS_ROOT, rule["dir"]))
        if (ap == root or ap.startswith(root + os.sep)) and \
           fnmatch.fnmatch(os.path.basename(ap), rule["glob"]):
            return rule
    return None


def body_hash(path):
    """Body hash — IDENTICAL pipeline to the validators and idd-gate (shell out
    to the same bash rather than reimplement, to avoid drift)."""
    pipeline = (
        "awk 'BEGIN{fm=0} /^---$/{fm++; next} fm>=2{print}' "
        '"%s" | sha256sum | cut -c1-16' % path
    )
    out = subprocess.run(
        ["bash", "-c", pipeline],
        capture_output=True, text=True, check=True,
    )
    return out.stdout.strip()


def read_frontmatter(path):
    """YAML frontmatter between the first two '---'. {} if absent."""
    import yaml  # lazy import: missing → exception → fail-open in main()
    with open(path, "r", encoding="utf-8") as f:
        lines = f.read().splitlines()
    if not lines or lines[0].strip() != "---":
        return {}
    fm = []
    for line in lines[1:]:
        if line.strip() == "---":
            break
        fm.append(line)
    data = yaml.safe_load("\n".join(fm))
    return data if isinstance(data, dict) else {}


def validated(path, rule):
    """True if the artifact already passed its check for the CURRENT body:
    a matching body hash, every phase passed, no open CRITICAL finding.
    Same predicate idd-gate uses to open the gate — so once the gate is open
    the nudge falls silent."""
    fm = read_frontmatter(path)
    block = fm.get(rule["block"])
    if not isinstance(block, dict):
        return False
    if block.get(rule["hash_key"]) != body_hash(path):
        return False
    for _, ph in (block.get("phases") or {}).items():
        if not (isinstance(ph, dict) and ph.get("status") == "passed"):
            return False
    for f in (block.get("findings") or []):
        if isinstance(f, dict) and f.get("severity") in BLOCK_ON \
           and f.get("verdict") == "open":
            return False
    return True


def nudge(path, fix):
    """Emit the PostToolUse additionalContext suggestion."""
    msg = (
        "IDD artifact %s was just written and has not passed validation yet. "
        "Run %s on it (dispatch a clean-context subagent per the check-runner "
        "protocol in CLAUDE.md, then collect verdicts in the main session) so "
        "the IDD gate is open before the next chain transition." % (path, fix)
    )
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PostToolUse",
            "additionalContext": msg,
        }
    }))


def main():
    try:
        data = json.loads(sys.stdin.read())
    except (json.JSONDecodeError, ValueError):
        sys.exit(0)  # broken stdin → fail-open

    try:
        # The artifact is born on Write (full-file creation), which is the
        # culmination of the producing skill's work. Body edits (Edit) are not
        # nudged — that would spam mid-authoring; re-validation is covered by
        # idd-gate at the next transition.
        if data.get("tool_name") != "Write":
            sys.exit(0)
        path = (data.get("tool_input") or {}).get("file_path")
        if not path:
            sys.exit(0)
        rule = rule_for(path)
        if rule is None:
            sys.exit(0)  # not an IDD artifact
        if not os.path.exists(path):
            sys.exit(0)  # write reported but file absent → nothing to nudge
        if validated(path, rule):
            sys.exit(0)  # already passed for this body → silent (no loop)
        nudge(path, rule["fix"])
        sys.exit(0)
    except Exception as exc:  # advisory hook: never disrupt the write
        print("idd-nudge: internal error, skipping (fail-open): %s" % exc,
              file=sys.stderr)
        sys.exit(0)


if __name__ == "__main__":
    main()
