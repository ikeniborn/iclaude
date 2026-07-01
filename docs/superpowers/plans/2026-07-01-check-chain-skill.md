# check-chain Skill + chain-gate Hook Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the four `check-{intent,spec,plan,result}` slash commands with one `skills/check-chain/SKILL.md` validator, and merge the two IDD hooks (`idd-gate.py` + `idd-nudge.py`) into one `hooks/chain-gate.py`.

**Architecture:** One markdown skill carries the shared validator boilerplate once plus four per-stage profiles, and runs in two modes (whole-chain sequential gate / single stage). One Python hook branches on `hook_event_name` (PreToolUse → block; PostToolUse → nudge) over shared helpers. All gate/nudge *decisions* are ported verbatim; only the file layout and the remediation strings (`/check-chain <stage>`) change.

**Tech Stack:** Markdown skill prompt (Claude Code custom skill); Python 3 hook (stdlib + lazy `yaml` import); bash `awk`/`sha256sum` for canonical hashing; JSON `settings.json`.

## Global Constraints

- Canonical body-hash one-liner, **byte-identical** in the skill and the hook: `awk 'BEGIN{fm=0} /^---$/{fm++; next} fm>=2{print}' <FILE> | sha256sum | cut -c1-16`.
- `BLOCK_ON = {"CRITICAL"}`; `IMPL_GATE_FRESH_SECONDS = 7200`.
- Every remediation string the gate/nudge shows is `/check-chain <stage>` (never `/check-intent` etc.).
- Frontmatter contract unchanged: `review:` with `intent_hash`/`spec_hash`/`plan_hash`, `phases.<name>.status`, `findings[].{severity,verdict,...}`; `result_check:` with `verdict` + `plan_hash`.
- HTML report unchanged: `html-report` skill, `mode: chain`, `tab: <stage>`, output `docs/superpowers/reports/<topic>-results.html` (one file, four tabs).
- `docs/TODO.md`: one row per `<topic>`.
- PostToolUse nudge **excludes** `result` (needs a diff + a plan path).
- Fail-open: any internal hook error → exit 0.
- Language: code, comments, docs in **English**; the skill's user-facing report text in **Russian**.
- Surgical: do not touch historical artifacts under `docs/superpowers/{intents,specs,plans,reports}/`.

---

### Task 1: `chain-gate.py` — merged gate + nudge hook (with characterization tests)

Build the merged hook and a stdin-payload test harness **first**, without wiring it
into `settings.json` yet (Task 3 does that). The two old hooks stay live and unchanged
during this task.

**Files:**
- Create: `.nvm-isolated/.claude-isolated/hooks/chain-gate.py`
- Create: `.nvm-isolated/.claude-isolated/hooks/test_chain_gate.py`
- Reference (read-only, do not edit): `.nvm-isolated/.claude-isolated/hooks/idd-gate.py`, `.nvm-isolated/.claude-isolated/hooks/idd-nudge.py`

**Interfaces:**
- Produces: a hook script run as `python3 chain-gate.py` reading a JSON tool payload on stdin. PreToolUse → exit 2 (block) or 0 (allow); PostToolUse → exit 0, optional JSON `additionalContext` on stdout. Branches on `data["hook_event_name"]` (fallback: `PostToolUse` iff payload has `tool_response`, else `PreToolUse`).
- Consumes: nothing from earlier tasks.

- [ ] **Step 1: Write the failing test**

Create `.nvm-isolated/.claude-isolated/hooks/test_chain_gate.py` with exactly:

```python
#!/usr/bin/env python3
"""Characterization tests for chain-gate.py — feed crafted payloads on stdin,
assert exit code / stdout. Run: python3 test_chain_gate.py (exit 0 = all pass)."""

import json
import os
import subprocess
import sys
import tempfile

HOOK = os.path.join(os.path.dirname(os.path.abspath(__file__)), "chain-gate.py")


def body_hash(path):
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
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
python3 .nvm-isolated/.claude-isolated/hooks/test_chain_gate.py
```

Expected: FAIL — `chain-gate.py` does not exist yet, so every `run(...)` subprocess errors / returns non-zero unexpectedly (the script exits 1 with failures, or the subprocess raises). The harness must run; the assertions must not pass.

- [ ] **Step 3: Write the merged hook**

Create `.nvm-isolated/.claude-isolated/hooks/chain-gate.py` with exactly:

```python
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
}

# PreToolUse skill → stage rule (chain-transition gate).
GATE_MAP = {
    "brainstorming": STAGE_RULES["intent"],
    "writing-plans": STAGE_RULES["spec"],
    "executing-plans": STAGE_RULES["plan"],
    "subagent-driven-development": STAGE_RULES["plan"],
    "finishing-a-development-branch": STAGE_RULES["result"],
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
        "Action: dispatch a subagent to run %s on %s (clean-context\n"
        "check-runner protocol), collect verdicts in the main session, "
        "resolve the CRITICAL\n"
        "findings, then retry.\n"
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
    rule = GATE_MAP.get(skill)
    if rule is None:
        sys.exit(0)
    candidate = resolve_candidate(rule, sid)
    if candidate is None:
        sys.exit(0)
    reason = gate_reason(candidate, rule)
    if reason is None:
        sys.exit(0)
    block(candidate, reason, rule["fix"])


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
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
python3 .nvm-isolated/.claude-isolated/hooks/test_chain_gate.py
```

Expected: `ALL PASS` (exit 0). All six checks PASS.

- [ ] **Step 5: Byte-check the canonical hash pipeline matches the constraint**

```bash
grep -F "awk 'BEGIN{fm=0} /^---\$/{fm++; next} fm>=2{print}' " .nvm-isolated/.claude-isolated/hooks/chain-gate.py
```

Expected: one match (the `body_hash` pipeline is byte-identical to the Global Constraints line).

- [ ] **Step 6: Commit**

```bash
git add .nvm-isolated/.claude-isolated/hooks/chain-gate.py .nvm-isolated/.claude-isolated/hooks/test_chain_gate.py
git commit -m "feat(hooks): add chain-gate.py — merged IDD gate + nudge

One hook branches on hook_event_name: PreToolUse blocks, PostToolUse nudges.
Shared stage rules, body-hash pipeline, frontmatter parsing, and the validated?
predicate. Remediation strings are /check-chain <stage>. Characterization tests
(test_chain_gate.py) cover both events + fail-open. Not yet wired into settings.json.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: `skills/check-chain/SKILL.md` — unified validator skill

Compose the skill from the shared core (authored once below) plus the four per-stage
closed checklists, which are **copied verbatim** from the still-present command files.
The skill is LLM-driven; verification is structural greps plus an optional manual smoke.

**Files:**
- Create: `.nvm-isolated/.claude-isolated/skills/check-chain/SKILL.md`
- Reference (read-only, source of the verbatim checklists — still present until Task 4): `.nvm-isolated/.claude-isolated/commands/check-intent.md`, `check-spec.md`, `check-plan.md`, `check-result.md`

**Interfaces:**
- Consumes: the `html-report` skill (`mode: chain`, `tab: <stage>`); the frontmatter contract written by/for `chain-gate.py` (Task 1).
- Produces: the `/check-chain` entry point (whole-chain + single-stage) referenced by `chain-gate.py`'s remediation strings.

- [ ] **Step 1: Create the skill file with frontmatter + shared core**

Create `.nvm-isolated/.claude-isolated/skills/check-chain/SKILL.md` starting with this
content (the frontmatter description carries the trigger keywords):

````markdown
---
name: check-chain
description: Use to validate the IDD→SDD chain (intent → spec → plan → result). Triggers on "/check-chain", "check chain", "validate intent/spec/plan/result", and is the remediation the chain-gate hook points to. Runs the whole chain (sequential gate) with no argument, or a single stage with "/check-chain <stage>".
---

# check-chain — unified IDD→SDD chain validator

One skill, two run modes, four stage profiles over one shared core. Replaces the
former `/check-intent`, `/check-spec`, `/check-plan`, `/check-result` commands.

## Invocation & argument parsing

```
/check-chain                       → whole chain (sequential gate)
/check-chain <stage>               → that stage only      (stage ∈ intent|spec|plan|result)
/check-chain <stage> <path>        → that stage, explicit file
/check-chain <path>                → infer stage from the file's directory, single-stage
```

Parse `$ARGUMENTS`:
- First token in `intent|spec|plan|result` → the target stage.
- A token that is a path → the explicit artifact file.
- No stage and no path → whole-chain mode.
- A lone path with no stage → resolve the stage from the directory (`intents/`→intent,
  `specs/`→spec, `plans/`→plan). `result` is never inferred from a path (it shares
  `plans/` with `plan`); it must be named explicitly.

## Shared core (applied by every stage)

### Canonical hashing (MANDATORY)

Run bash via the Bash tool; never recompute "in your head".
- **Body hash** (excludes frontmatter):
  ```bash
  awk 'BEGIN{fm=0} /^---$/{fm++; next} fm>=2{print}' <FILE> | sha256sum | cut -c1-16
  ```
- **Section hash** — the body from a `##`/`###` heading to the next heading of the same
  or higher level (exclusive), piped through `sha256sum | cut -c1-16`.
- If frontmatter is absent (`fm` < 2) — hash the whole file: `sha256sum <FILE> | cut -c1-16`.

### Step 0 — quick exit by state

If frontmatter has a `review:` block, `current_body_hash == review.<hash_key>` AND every
phase `status == passed` AND no finding with `severity == CRITICAL ∧ verdict == open` →
output `OK (cached, hash match)` and finish. (`result` uses `result_check.verdict == OK`
with a matching `plan_hash`.) Otherwise continue. The advisory `alignment` phase is not
recomputed on a hash match — trust the previous run.

### Step 1 — scope resolution

Locate the stage artifact by: explicit path arg → by `<topic>` in the stage dir → the
most-recently-modified file in the stage dir. If not found, report
«Не найден <stage>. Укажи путь: `/check-chain <stage> path/to/file.md`» and stop.

### Step 2 — confirm & init state

Report «Буду проверять: `<путь>`. Верно?» and, after confirmation: read the frontmatter;
if there is no `review:` block, scaffold one for the stage's phase set; compute section
hashes; reset any finding whose `section_hash` changed to `verdict: open`; update the
stage hash + `last_run`; maintain the `chain:` block for downstream stages
(`spec` → `chain.intent`; `plan` → `chain.intent` + `chain.spec`; `intent` writes none).
Never edit the artifact body — only its frontmatter.

### Step 3 — phase execution & finding-handling

Phases run strictly sequentially; phase N+1 starts only when phase N has no CRITICAL with
`verdict: open`. For each phase apply its **closed checklist** (do NOT extend) to the
body. For each finding: dedupe by `section + text + section_hash`; otherwise create
`id: F-NNN` (monotonic), `phase`, `severity`, `section`, `section_hash`, `fragment`
(≤140-char quote, `null` for structural), `text`, `fix`, `verdict: open`, `verdict_at: null`.
Write the updated frontmatter; report the phase; request verdicts (CRITICAL mandatory
`accepted|wontfix|fixed`, WARNING desirable, INFO optional). All CRITICAL closed →
`phase.status = passed`; else `in_progress`, stop and ask to fix and rerun.

### Step 4 — final verdict

Apply the Step 0 exit criterion: `OK` or «требует доработки: <N> critical open, <M> warning open».

### Step 5 — HTML report

After the verdict (including the cached quick-exit), invoke the `html-report` skill
(`skill: "html-report"`) with `mode: chain`, `tab: <stage>`, output
`docs/superpowers/reports/<topic>-results.html` (one file, four tabs Intent/Spec/Plan/Result;
update only this stage's tab, preserve the others; create all four if absent with the
placeholder «Этап ещё не проверен»; data passed inline; all report text in Russian).
Determine `<topic>`: basename minus `.md`, strip the `^YYYY-MM-DD-` date prefix, strip a
trailing `-intent`/`-design`/`-plan` suffix if present; fallback to the bare basename.

### Step 6 — TODO.md upsert

After the verdict, upsert the chain's row in `docs/TODO.md` keyed by `<topic>` (see the
Task Log convention in `CLAUDE.md`). Create the file with the header row if absent. Mark
this stage's cell `✓` on `OK` (`–` if it still needs work); `intent` opens the row, a
missing upstream stage is `n/a`; `result` on `OK` closes the row (`Result: OK`,
`Status: done`, `Closed: <today>`).

## Rules (prohibited)

- Extending a phase checklist — the closed list keeps the check deterministic and the
  hash-cache reproducible.
- Inventing requirements absent from the source (and the conversation, for `intent`).
- Editing the artifact body (frontmatter is the only exception).
- Writing «вероятно подразумевается» without a textual anchor.
- (`result`) Running a code review — that is `/review`, not this check.
````

- [ ] **Step 2: Append the stage profiles + per-stage closed checklists**

Append a `## Stage profiles` section to `SKILL.md`. Start with this table:

```markdown
## Stage profiles

| stage | dir | glob | hash key | state block | phases |
|---|---|---|---|---|---|
| intent | intents/ | *-intent.md | intent_hash | review | structure, completeness, clarity, consistency, alignment(advisory) |
| spec | specs/ | *-design.md | spec_hash | review | structure, coverage, clarity, consistency |
| plan | plans/ | *.md | plan_hash | review | structure, coverage, dependencies, verifiability, consistency |
| result | plans/ | *.md | plan_hash | result_check | non-phased: git diff reconciliation |
```

Then, under a `### <stage> checklist` heading for each of intent / spec / plan, copy the
**closed phase checklists verbatim** from the corresponding command file's `#### Phase …`
sections:
- `### intent checklist` ← from `commands/check-intent.md`, the five `#### Phase 1..5`
  blocks (structure, completeness, clarity, consistency, alignment) **including** the
  "advisory / not a gate / do not recompute on hash match" note for `alignment`, the
  Status-guard in `consistency`, and the forward footer `Next step: superpowers:brainstorming`.
- `### spec checklist` ← from `commands/check-spec.md`, the four `#### Phase 1..4` blocks
  (structure, coverage, clarity, consistency).
- `### plan checklist` ← from `commands/check-plan.md`, the five `#### Phase 1..5` blocks
  (structure, coverage, dependencies, verifiability, consistency).

For `result`, add a `### result reconciliation` section copied verbatim from
`commands/check-result.md`: the git-diff steps (`git diff HEAD`, `--since=<ref>`), the
DONE/PARTIAL/MISSING/EXCESS classification, the intent/spec coverage check, the Severity
table (CRITICAL = step absent from diff; WARNING = partial/excess; INFO = semantic), and
the `result_check: { verdict, plan_hash, last_run }` stamp into the **plan** frontmatter
(never `review:`, never the plan body).

Do not alter any wording while copying — these checklists are the validators' contract.

- [ ] **Step 3: Append the two run-mode procedures**

Append a `## Run modes` section to `SKILL.md` with exactly:

````markdown
## Run modes

### Whole chain (sequential gate) — no stage argument

1. Resolve `<topic>` from the argument or the most-recently-modified artifact; locate
   every existing stage file for that topic.
2. Confirm the set once: «Проверю chain `<topic>`: intent=…, spec=…, plan=…. Верно?»
3. For each stage in `[intent, spec, plan, result]`:
   - artifact absent → record it (`Intent: n/a` etc.) and continue;
   - Step 0 quick-exit passes → `✓ cached`, continue;
   - else run the stage's full Step 1–6 (findings → verdicts → frontmatter → HTML tab → TODO cell);
   - stage ends `needs_work` (open CRITICAL) → STOP: «chain остановлен на `<stage>`,
     почини и перезапусти». Do not run downstream stages.
4. `result` needs a `git diff`. Reached with an empty diff → emit INFO
   «result pending implementation», chain verdict «OK up to plan», leave the TODO
   `Result` cell `–` (not `done`). Non-empty diff → reconcile; on `OK` close the row.
5. Print the chain summary and the path to the HTML report.

### Single stage — `/check-chain <stage> [path]`

Run Step 0–6 for exactly that one stage. This reproduces the former per-command
behaviour 1:1 (same confirmation, findings, verdicts, frontmatter, HTML tab, TODO cell,
footer).
````

- [ ] **Step 4: Verify the skill structure**

```bash
F=.nvm-isolated/.claude-isolated/skills/check-chain/SKILL.md
grep -c "^name: check-chain" "$F"
grep -F "awk 'BEGIN{fm=0} /^---\$/{fm++; next} fm>=2{print}' <FILE> | sha256sum | cut -c1-16" "$F"
grep -cE "^### (intent|spec|plan) checklist|^### result reconciliation" "$F"
grep -cE "^## (Stage profiles|Run modes)" "$F"
grep -c "/check-chain" "$F"
```

Expected: line 1 → `1`; line 2 → one match (canonical pipeline present byte-identical);
line 3 → `4` (three stage checklists + result reconciliation); line 4 → `2`; line 5 → ≥1.

- [ ] **Step 5: Commit**

```bash
git add .nvm-isolated/.claude-isolated/skills/check-chain/SKILL.md
git commit -m "feat(skills): add check-chain — unified IDD→SDD chain validator

Shared core (hashing, quick-exit, init, finding loop, HTML, TODO) authored once;
four stage profiles with the per-stage closed checklists copied verbatim from the
check-* commands. Two run modes: whole-chain sequential gate and single stage.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: Re-wire `settings.json` and remove the old hooks

Now that `chain-gate.py` exists and is tested (Task 1) and the skill it points at exists
(Task 2), switch the live hooks over and delete the originals. Order matters: edit
`settings.json` **before** deleting the old files, so the live session never references a
missing script.

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/settings.json`
- Delete: `.nvm-isolated/.claude-isolated/hooks/idd-gate.py`
- Delete: `.nvm-isolated/.claude-isolated/hooks/idd-nudge.py`

- [ ] **Step 1: Point the PreToolUse hook at chain-gate.py**

In `.nvm-isolated/.claude-isolated/settings.json`, the PreToolUse entry whose `matcher`
is `"Skill|Write|Edit|MultiEdit"` has command
`python3 "$CLAUDE_CONFIG_DIR/hooks/idd-gate.py"`. Change `idd-gate.py` → `chain-gate.py`:

```
python3 "$CLAUDE_CONFIG_DIR/hooks/chain-gate.py"
```

- [ ] **Step 2: Point the PostToolUse hook at chain-gate.py**

In the same file, the PostToolUse entry whose `matcher` is `"Write"` has command
`python3 "$CLAUDE_CONFIG_DIR/hooks/idd-nudge.py"`. Change `idd-nudge.py` → `chain-gate.py`:

```
python3 "$CLAUDE_CONFIG_DIR/hooks/chain-gate.py"
```

- [ ] **Step 3: Verify settings.json is valid JSON and wired correctly**

```bash
python3 -m json.tool .nvm-isolated/.claude-isolated/settings.json > /dev/null && echo "JSON OK"
grep -c 'hooks/chain-gate.py' .nvm-isolated/.claude-isolated/settings.json
grep -c 'idd-gate.py\|idd-nudge.py' .nvm-isolated/.claude-isolated/settings.json
```

Expected: `JSON OK`; second line → `2` (both events); third line → `0` (no stale refs).

- [ ] **Step 4: Delete the two old hooks**

```bash
git rm .nvm-isolated/.claude-isolated/hooks/idd-gate.py .nvm-isolated/.claude-isolated/hooks/idd-nudge.py
```

- [ ] **Step 5: Re-run the hook test (regression) and confirm removal**

```bash
python3 .nvm-isolated/.claude-isolated/hooks/test_chain_gate.py
ls .nvm-isolated/.claude-isolated/hooks/idd-gate.py .nvm-isolated/.claude-isolated/hooks/idd-nudge.py 2>&1 | grep -c 'No such file'
```

Expected: `ALL PASS`; second command → `2` (both gone).

- [ ] **Step 6: Commit**

```bash
git add .nvm-isolated/.claude-isolated/settings.json
git commit -m "refactor(hooks): wire chain-gate.py on both events, remove idd-gate/idd-nudge

settings.json PreToolUse + PostToolUse now call chain-gate.py; the two superseded
hooks are deleted. Gate/nudge behaviour unchanged (decisions ported verbatim).

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: Delete the four commands and sync the global CLAUDE.md Task Log

Final cleanup: remove the superseded commands and update the only remaining live prose
that names them. After this task, no live config references `/check-intent|spec|plan|result`.

**Files:**
- Delete: `.nvm-isolated/.claude-isolated/commands/check-intent.md`, `check-spec.md`, `check-plan.md`, `check-result.md`
- Modify: `.nvm-isolated/.claude-isolated/CLAUDE.md` (Task Log section prose)

- [ ] **Step 1: Delete the four command files**

```bash
git rm .nvm-isolated/.claude-isolated/commands/check-intent.md \
       .nvm-isolated/.claude-isolated/commands/check-spec.md \
       .nvm-isolated/.claude-isolated/commands/check-plan.md \
       .nvm-isolated/.claude-isolated/commands/check-result.md
```

- [ ] **Step 2: Sync the CLAUDE.md Task Log prose**

In `.nvm-isolated/.claude-isolated/CLAUDE.md`, in the `## Task Log (docs/TODO.md)`
section, replace the command references with the unified skill. Apply these exact
substitutions (match on content, not line number):

- `(the shared chain key the `check-*` commands converge on)` → `(the shared chain key the `/check-chain` skill converges on)`
- `` `done` once `check-result` returns `OK`. `` → `` `done` once `/check-chain result` returns `OK`. ``
- `` `✓` once that stage's `check-*` passes `` → `` `✓` once that stage's `/check-chain <stage>` passes ``
- `**Lifecycle (driven by the `check-*` commands):**` → `**Lifecycle (driven by the `/check-chain` skill):**`
- `The first `check-*` run for a topic **opens** the row` → `The first `/check-chain <stage>` run for a topic **opens** the row`
- `Normally that is `check-intent`; if there is no intent, `check-spec` opens it` → `Normally that is `/check-chain intent`; if there is no intent, `/check-chain spec` opens it`
- `` `check-spec` / `check-plan` mark their own stage cell `✓` `` → `` `/check-chain spec` / `/check-chain plan` mark their own stage cell `✓` ``
- `` `check-result` **closes** the row on verdict `OK` `` → `` `/check-chain result` **closes** the row on verdict `OK` ``
- `the first `check-*` run creates it with the header row` → `the first `/check-chain <stage>` run creates it with the header row`
- `the commands then update the matching `<topic>` row` → `the skill then updates the matching `<topic>` row`

- [ ] **Step 3: Verify no live reference to the old commands remains**

```bash
grep -rnE '/check-(intent|spec|plan|result)\b' \
  .nvm-isolated/.claude-isolated/hooks \
  .nvm-isolated/.claude-isolated/skills \
  .nvm-isolated/.claude-isolated/commands \
  .nvm-isolated/.claude-isolated/CLAUDE.md 2>/dev/null | grep -c .
ls .nvm-isolated/.claude-isolated/commands/check-*.md 2>&1 | grep -c 'No such file'
grep -rl 'check-chain' .nvm-isolated/.claude-isolated/hooks .nvm-isolated/.claude-isolated/skills | wc -l
```

Expected: first command → `0` (no `/check-intent|spec|plan|result` anywhere in live
config); second → `1` (the glob matched nothing → "No such file"); third → ≥2
(`chain-gate.py` and `SKILL.md` reference `/check-chain`).

- [ ] **Step 4: Commit**

```bash
git add -A .nvm-isolated/.claude-isolated/commands .nvm-isolated/.claude-isolated/CLAUDE.md
git commit -m "chore(idd): remove check-* commands, point CLAUDE.md Task Log at /check-chain

The four check-* commands are superseded by the check-chain skill; the global
Task Log prose now names /check-chain <stage>.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

- [ ] **Step 5: Optional manual smoke (LLM-driven, not automated)**

On a throwaway copy so no committed artifact is mutated:

```bash
cp docs/superpowers/specs/2026-07-01-check-chain-skill-design.md /tmp/smoke-design.md
```

Invoke `/check-chain spec /tmp/smoke-design.md` and confirm it: asks the confirmation
question, runs the four spec phases, writes a `review:` block to `/tmp/smoke-design.md`,
and emits the HTML chain report path. Then invoke `/check-chain` (no arg) against this
chain's topic and confirm it walks intent (n/a) → spec → plan and stops at the first
stage needing work. Clean up: `rm /tmp/smoke-design.md`.

---

## Self-Review

**Spec coverage** (each spec section → task):
- §3.1 arg parsing → Task 2 Step 1 (parsing block).
- §3.2 shared core → Task 2 Step 1.
- §3.3 stage profiles + verbatim checklists → Task 2 Step 2.
- §3.4 chain-gate hook → Task 1 (impl) + Task 3 (wire/remove).
- §4 run modes → Task 2 Step 3.
- §5 preserved contracts → enforced by Global Constraints + Task 1 tests + Task 2 verbatim copy.
- §6 change-set → create skill (T2) + create chain-gate (T1) + delete two hooks (T3) + settings.json (T3) + delete four commands (T4) + CLAUDE.md sync (T4).
- §8 success criteria → #1/#2 skill (T2 + smoke T4.5); #3 grep (T4.3); #4 hook both events (T1 tests); #5 commands gone (T4.3); #6 history untouched (no task touches it); #7 hooks gone + settings wired (T3.3/T3.5).

**Placeholder scan:** no TBD/TODO/"handle edge cases"; the only "copy verbatim" instructions cite an exact present source file + section (a port, not a placeholder).

**Type/name consistency:** `chain-gate.py` helper names (`gate_reason`, `validated`, `rule_for`, `emit_nudge`, `handle_nudge`, `handle_skill`, `handle_write`, `STAGE_RULES`/`GATE_MAP`/`NUDGE_RULES`/`SPEC_RULE`/`PLAN_RULE`) are used consistently across Steps 1 (test) and 3 (impl); the test references `/check-chain spec` exactly as `STAGE_RULES["spec"]["fix"]` produces it. Settings command strings (`hooks/chain-gate.py`) match the created filename.
