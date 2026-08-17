#!/usr/bin/env python3
"""
IDD→SDD chain gate — unified PreToolUse gate + PostToolUse nudge.

One hook, two events (branch on hook_event_name):
  PreToolUse  (Skill|Write|Edit|MultiEdit) → block (exit 2) an invalid chain
              transition until the upstream artifact passes validation.
  PostToolUse (Write) → after an intent/spec/plan artifact is written and is not
              yet validated, suggest /check-chain <stage> via additionalContext.

Replaces idd-gate.py + idd-nudge.py: the stage rules, body-hash pipeline,
frontmatter parsing, BLOCK_ON, and the "validated?" predicate are shared.

The hook only GATES/NUDGES; it never validates. Validation is /check-chain run in
a clean-context subagent; verdicts are collected in the main session. Communication
is via frontmatter review:/result_check:.

Session scoping — the gate resolves a candidate ONLY among artifacts owned by the
current session (session_id), recorded in $CLAUDE_CONFIG_DIR/state/idd-sessions.json.
A session that did not create an artifact is not gated by it. No session_id / no
ledger → fail-open.

Exit codes:
  0 — allow (PreToolUse) / silent-or-nudge (PostToolUse)
  2 — block (PreToolUse only)

Fail-open: any internal exception → exit 0. A bug here must never break a real
tool call.
"""

import sys
import json
import os
import glob
import time
import subprocess
import fnmatch

DOCS_ROOT = "docs/superpowers"
PLANS_DIR = os.path.join(DOCS_ROOT, "plans")

BLOCK_ON = {"CRITICAL"}
IMPL_GATE_FRESH_SECONDS = 7200  # 2h: only a freshly edited plan gates code edits

# One rule per stage: dir + glob (artifact), state block + body-hash key
# (frontmatter contract), fix (remediation command shown on block/nudge).
STAGE_RULES = {
    "intent": {"dir": "intents", "glob": "*-intent.md", "block": "review",
               "hash_key": "intent_hash", "fix": "/check-chain intent"},
    "spec":   {"dir": "specs", "glob": "*-design.md", "block": "review",
               "hash_key": "spec_hash", "fix": "/check-chain spec"},
    "plan":   {"dir": "plans", "glob": "*.md", "block": "review",
               "hash_key": "plan_hash", "fix": "/check-chain plan"},
    "result": {"dir": "plans", "glob": "*.md", "block": "result_check",
               "hash_key": "plan_hash", "fix": "/check-chain result"},
    # execute route: no plan is written, so the intent is the result artifact.
    "result_intent": {"dir": "intents", "glob": "*-intent.md",
                      "block": "result_check", "hash_key": "intent_hash",
                      "fix": "/check-chain result"},
}

# PreToolUse skill → stage rules (chain-transition gate). The first rule that
# resolves a session-owned candidate is the one that gates.
GATE_MAP = {
    "brainstorming": [STAGE_RULES["intent"]],
    "writing-plans": [STAGE_RULES["spec"]],
    "executing-plans": [STAGE_RULES["plan"]],
    "subagent-driven-development": [STAGE_RULES["plan"]],
    "finishing-a-development-branch": [STAGE_RULES["result"],
                                       STAGE_RULES["result_intent"]],
}

# Write-trigger rules (inline spec→plan, plan→impl transitions).
SPEC_RULE = STAGE_RULES["spec"]
PLAN_RULE = STAGE_RULES["plan"]

# PostToolUse nudge rules (artifact-keyed). result is intentionally excluded — it
# needs git diff + a plan path and runs at branch finish, covered by the gate.
NUDGE_RULES = [STAGE_RULES["intent"], STAGE_RULES["spec"], STAGE_RULES["plan"]]

# ── session-ownership ledger ────────────────────────────────────────────
LEDGER_MAX_AGE_SECONDS = 7 * 24 * 3600
ARTIFACT_DIRS = ("intents", "specs", "plans")
CLAIM_SKILLS = {"executing-plans", "subagent-driven-development"}


def ledger_path():
    cfg = os.environ.get("CLAUDE_CONFIG_DIR")
    return os.path.join(cfg, "state", "idd-sessions.json") if cfg else None


def load_ledger():
    path = ledger_path()
    if not path or not os.path.exists(path):
        return {}
    try:
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
    except (json.JSONDecodeError, ValueError, OSError):
        return {}
    if not isinstance(data, dict):
        return {}
    now = time.time()
    out = {}
    for key, val in data.items():
        if not isinstance(val, dict) or not os.path.exists(key):
            continue
        if now - val.get("ts", 0) > LEDGER_MAX_AGE_SECONDS:
            continue
        out[key] = val
    return out


def record_owner(path, sid):
    lp = ledger_path()
    if not lp or not sid:
        return
    ledger = load_ledger()
    ledger[os.path.abspath(path)] = {"session": sid, "ts": int(time.time())}
    try:
        os.makedirs(os.path.dirname(lp), exist_ok=True)
        tmp = "%s.%d.tmp" % (lp, os.getpid())
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(ledger, f)
        os.replace(tmp, lp)
    except OSError:
        pass


def owns(path, sid, ledger):
    if not sid:
        return False
    entry = ledger.get(os.path.abspath(path))
    return isinstance(entry, dict) and entry.get("session") == sid


def _is_artifact(path):
    return any(_under(path, os.path.join(DOCS_ROOT, d)) for d in ARTIFACT_DIRS)


def record_ownership(data, tool, sid):
    if tool in ("Write", "Edit", "MultiEdit"):
        path = (data.get("tool_input") or {}).get("file_path")
        if path and _is_artifact(path):
            record_owner(path, sid)
    elif tool == "Skill":
        skill = normalize_skill((data.get("tool_input") or {}).get("skill", ""))
        if skill in CLAIM_SKILLS:
            plan = newest_plan()
            if plan:
                record_owner(plan, sid)


def normalize_skill(name):
    return name.rsplit(":", 1)[-1].strip()


def resolve_candidate(rule, sid):
    pattern = os.path.join(DOCS_ROOT, rule["dir"], rule["glob"])
    matches = glob.glob(pattern)
    if not matches:
        return None
    ledger = load_ledger()
    owned = [m for m in matches if owns(m, sid, ledger)]
    if not owned:
        return None
    return max(owned, key=os.path.getmtime)


def newest_plan():
    pattern = os.path.join(DOCS_ROOT, PLAN_RULE["dir"], PLAN_RULE["glob"])
    matches = glob.glob(pattern)
    return max(matches, key=os.path.getmtime) if matches else None


def body_hash(path):
    pipeline = (
        "awk 'BEGIN{fm=0} /^---$/{fm++; next} fm>=2{print}' "
        '"%s" | sha256sum | cut -c1-16' % path
    )
    out = subprocess.run(
        ["bash", "-c", pipeline],
        capture_output=True, text=True, check=True,
    )
    return out.stdout.strip()


def _frontmatter_from_lines(lines):
    import yaml  # lazy import: missing → exception → fail-open in main()
    if not lines or lines[0].strip() != "---":
        return {}
    fm = []
    for line in lines[1:]:
        if line.strip() == "---":
            break
        fm.append(line)
    data = yaml.safe_load("\n".join(fm))
    return data if isinstance(data, dict) else {}


def read_frontmatter(path):
    with open(path, "r", encoding="utf-8") as f:
        return _frontmatter_from_lines(f.read().splitlines())


def resolve_spec_from_chain(content):
    data = _frontmatter_from_lines((content or "").splitlines())
    chain = data.get("chain")
    spec = chain.get("spec") if isinstance(chain, dict) else None
    if spec and os.path.exists(spec):
        return spec
    return None


def _under(path, root):
    ap = os.path.abspath(path)
    ar = os.path.abspath(root)
    return ap == ar or ap.startswith(ar + os.sep)


def fresh(path, seconds):
    return time.time() - os.path.getmtime(path) <= seconds


def gate_reason(path, rule):
    """None if the gate is OPEN for `path` under `rule` (i.e. validated), else a
    reason string. The nudge's "validated" is simply `gate_reason(...) is None`."""
    fm = read_frontmatter(path)
    block_data = fm.get(rule["block"])
    if not isinstance(block_data, dict):
        return "no %s: block" % rule["block"]

    if block_data.get(rule["hash_key"]) != body_hash(path):
        return "hash stale (edited after last check)"

    if rule["block"] == "result_check":
        if block_data.get("verdict") != "OK":
            return "result_check verdict: %s" % block_data.get("verdict")
        return None

    for name, ph in (block_data.get("phases") or {}).items():
        status = ph.get("status") if isinstance(ph, dict) else None
        if status != "passed":
            return "phase %s: %s" % (name, status)

    open_critical = [
        f.get("id", "?")
        for f in (block_data.get("findings") or [])
        if isinstance(f, dict)
        and f.get("severity") in BLOCK_ON
        and f.get("verdict") == "open"
    ]
    if open_critical:
        return "open CRITICAL: " + ", ".join(open_critical)

    return None


def validated(path, rule):
    """True if the artifact already passed its check for the CURRENT body."""
    return gate_reason(path, rule) is None


def block(candidate, reason, fix):
    sys.stderr.write(
        "🚧 IDD gate: %s has not passed validation.\n"
        "Reason: %s\n"
        "Action: run %s on %s in this session (it writes the wiki task page,\n"
        "which only the parent agent may do), resolve the CRITICAL findings,\n"
        "then retry.\n"
        % (candidate, reason, fix, candidate)
    )
    sys.exit(2)


def handle_write(data, tool, sid):
    path = (data.get("tool_input") or {}).get("file_path")
    if not path:
        sys.exit(0)

    if tool == "Write" and _under(path, PLANS_DIR) and path.endswith(".md"):
        content = (data.get("tool_input") or {}).get("content")
        spec = resolve_spec_from_chain(content) or resolve_candidate(SPEC_RULE, sid)
        if spec is None:
            sys.exit(0)
        reason = gate_reason(spec, SPEC_RULE)
        if reason is None:
            sys.exit(0)
        block(spec, reason, SPEC_RULE["fix"])

    if not _under(path, DOCS_ROOT):
        plan = resolve_candidate(PLAN_RULE, sid)
        if plan is None:
            sys.exit(0)
        if not fresh(plan, IMPL_GATE_FRESH_SECONDS):
            sys.exit(0)
        reason = gate_reason(plan, PLAN_RULE)
        if reason is None:
            sys.exit(0)
        block(plan, reason, PLAN_RULE["fix"])

    sys.exit(0)


def handle_skill(data, sid):
    skill = normalize_skill((data.get("tool_input") or {}).get("skill", ""))
    rules = GATE_MAP.get(skill)
    if not rules:
        sys.exit(0)
    for rule in rules:
        candidate = resolve_candidate(rule, sid)
        if candidate is None:
            continue
        reason = gate_reason(candidate, rule)
        if reason is None:
            sys.exit(0)
        block(candidate, reason, rule["fix"])
    sys.exit(0)


def rule_for(path):
    """The nudge rule whose dir+glob matches path (under DOCS_ROOT), else None."""
    ap = os.path.abspath(path)
    for rule in NUDGE_RULES:
        root = os.path.abspath(os.path.join(DOCS_ROOT, rule["dir"]))
        if (ap == root or ap.startswith(root + os.sep)) and \
           fnmatch.fnmatch(os.path.basename(ap), rule["glob"]):
            return rule
    return None


def emit_nudge(path, fix):
    msg = (
        "IDD artifact %s was just written and has not passed validation yet. "
        "Run %s on it in this session so the IDD gate is open before the next "
        "chain transition." % (path, fix)
    )
    print(json.dumps({
        "hookSpecificOutput": {
            "hookEventName": "PostToolUse",
            "additionalContext": msg,
        }
    }))


def handle_nudge(data):
    """PostToolUse: nudge after a Write of an unvalidated intent/spec/plan artifact.
    Edits are not nudged (would spam mid-authoring); result is never nudged."""
    if data.get("tool_name") != "Write":
        return
    path = (data.get("tool_input") or {}).get("file_path")
    if not path:
        return
    rule = rule_for(path)
    if rule is None:
        return
    if not os.path.exists(path):
        return
    if validated(path, rule):
        return
    emit_nudge(path, rule["fix"])


def main():
    try:
        data = json.loads(sys.stdin.read())
    except (json.JSONDecodeError, ValueError):
        sys.exit(0)

    event = data.get("hook_event_name")
    if not event:
        event = "PostToolUse" if "tool_response" in data else "PreToolUse"
    tool = data.get("tool_name")
    sid = data.get("session_id")
    try:
        if event == "PostToolUse":
            handle_nudge(data)
            sys.exit(0)
        # PreToolUse
        record_ownership(data, tool, sid)
        if tool == "Skill":
            handle_skill(data, sid)
        elif tool in ("Write", "Edit", "MultiEdit"):
            handle_write(data, tool, sid)
        else:
            sys.exit(0)
    except Exception as exc:  # fail-open
        print("chain-gate: internal error, skipping (fail-open): %s" % exc,
              file=sys.stderr)
        sys.exit(0)


if __name__ == "__main__":
    main()
