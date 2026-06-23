---
review:
  plan_hash: feab95670dbc7f1d
  spec_hash: da0a6658f79adc61
  last_run: 2026-06-23
  phases:
    structure:     { status: passed }
    coverage:      { status: passed }
    dependencies:  { status: passed }
    verifiability: { status: passed }
    consistency:   { status: passed }
  findings: []
chain:
  intent: null
  spec: docs/superpowers/specs/2026-06-23-iwiki-hook-failopen-guard-design.md
---
# iwiki Hook Fail-Open Guard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make all five iwiki plugin hooks fail OPEN when their script file is missing or cannot start, instead of blocking the operation.

**Architecture:** Wrap each `command` string in `plugin/iwiki/hooks/hooks.json` with an inline POSIX guard that (a) exits 0 if the script file is absent, (b) runs the script if present, (c) maps only the script's `exit 2` to a block and any other non-zero (crash) to allow. stdout is passed through untouched, preserving stdout-JSON decisions. A shell test exercises the real command strings from `hooks.json` against stub scripts.

**Tech Stack:** POSIX shell (hook command), Python 3 (JSON parse in test + the existing hook scripts), Bash (test harness).

## Global Constraints

- Only `plugin/iwiki/hooks/hooks.json` changes for the fix (the five `.py` scripts, matchers, timeouts, and structure stay untouched). Verbatim from spec.
- The guard must preserve the validator's intentional `exit 2` (a real block) and the stdout-JSON decisions used by `iwiki-bootstrap.py`, `iwiki-recall.py`, `iwiki-sync.py`.
- The guard is applied uniformly to all 5 hooks: `iwiki-bootstrap.py`, `iwiki-recall.py`, `iwiki-validate.py`, `iwiki-reindex.py`, `iwiki-sync.py`.
- Exact guard (shell form), varying only the script basename:
  `f="${CLAUDE_PLUGIN_ROOT}/hooks/<script>.py"; [ -f "$f" ] || exit 0; python3 "$f"; [ $? -eq 2 ] && exit 2 || exit 0`
- Branch `dev-fix-iwiki-hook-failopen` off `origin/dev`; worktree `iclaude.worktrees/dev-fix-iwiki-hook-failopen`; PR into `dev`.

---

## File Structure

- `plugin/iwiki/hooks/hooks.json` — **modify**: replace the five `command` string values with the guarded form. Sole fix file.
- `tests/test_iwiki_hook_failopen.sh` — **create**: bash test that parses the real `hooks.json`, runs each command via `sh -c` with a controlled `CLAUDE_PLUGIN_ROOT`, and asserts the guard contract (missing→0, exit2→2, crash→0, stdout-passthrough, all-5-guarded). Lives in `tests/`, alongside the repo's other shell tests.

This is a single, self-contained deliverable: a guarded `hooks.json` proven by one test file. One task, one TDD cycle.

---

### Task 1: Guard all five iwiki hook commands (fail-open on missing/crashing script)

**Files:**
- Create: `tests/test_iwiki_hook_failopen.sh`
- Modify: `plugin/iwiki/hooks/hooks.json` (the five `command` values)

**Interfaces:**
- Consumes: the existing `plugin/iwiki/hooks/hooks.json` structure (`hooks.<Event>[].hooks[].command`); `python3` and `bash` on PATH.
- Produces: a guarded `hooks.json` whose every hook command fails open when `${CLAUDE_PLUGIN_ROOT}/hooks/<script>.py` is missing; a reusable regression test `tests/test_iwiki_hook_failopen.sh` (exit 0 = all pass).

- [ ] **Step 1: Write the failing test**

Create `tests/test_iwiki_hook_failopen.sh` with exactly this content:

```bash
#!/usr/bin/env bash
# Verify the iwiki plugin hook commands fail OPEN when the hook script is
# missing or crashes, while preserving an intentional exit-2 block and any
# stdout-based decision. Exercises the REAL command strings in hooks.json.
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOKS_JSON="$REPO_ROOT/plugin/iwiki/hooks/hooks.json"
OUT="$(mktemp)"
fail=0

# Print the hook command whose string contains the given script basename.
get_cmd() {
  python3 - "$HOOKS_JSON" "$1" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
needle = sys.argv[2]
for event in data.get("hooks", {}).values():
    for group in event:
        for h in group.get("hooks", []):
            cmd = h.get("command", "")
            if needle in cmd:
                print(cmd)
                sys.exit(0)
sys.exit(1)
PY
}

# Run a command string with CLAUDE_PLUGIN_ROOT=$2 and stdin=$3; stdout -> $OUT.
run_cmd() {
  CLAUDE_PLUGIN_ROOT="$2" sh -c "$1" <<<"$3" >"$OUT" 2>/dev/null
}

assert_exit() {
  if [ "$3" = "$2" ]; then
    echo "PASS: $1 (exit $3)"
  else
    echo "FAIL: $1 — want exit $2, got $3"; fail=1
  fi
}

CMD="$(get_cmd iwiki-validate.py)" || { echo "FAIL: no validate command in hooks.json"; exit 1; }
PAYLOAD='{"tool_name":"Write","tool_input":{"file_path":"docs/wiki/x.md","content":"# T\n\n## A\n"}}'

# 1) Missing script -> allow (exit 0). Core regression for the reported bug.
EMPTY="$(mktemp -d)"; mkdir -p "$EMPTY/hooks"
run_cmd "$CMD" "$EMPTY" "$PAYLOAD"; assert_exit "missing script -> allow" 0 "$?"

# 2) Present script that exits 2 (real block) -> exit 2 preserved.
BLOCK="$(mktemp -d)"; mkdir -p "$BLOCK/hooks"
cat > "$BLOCK/hooks/iwiki-validate.py" <<'PY'
import sys
sys.exit(2)
PY
run_cmd "$CMD" "$BLOCK" "$PAYLOAD"; assert_exit "present + exit 2 -> block" 2 "$?"

# 3) Present script that crashes (exit 1) -> allow (exit 0).
CRASH="$(mktemp -d)"; mkdir -p "$CRASH/hooks"
cat > "$CRASH/hooks/iwiki-validate.py" <<'PY'
import sys
sys.exit(1)
PY
run_cmd "$CMD" "$CRASH" "$PAYLOAD"; assert_exit "present + crash -> allow" 0 "$?"

# 4) Present script that prints stdout JSON and exits 0 -> allow + stdout kept.
OKDIR="$(mktemp -d)"; mkdir -p "$OKDIR/hooks"
cat > "$OKDIR/hooks/iwiki-validate.py" <<'PY'
print('{"decision":"block"}')
PY
run_cmd "$CMD" "$OKDIR" "$PAYLOAD"; assert_exit "present + stdout json -> allow" 0 "$?"
if grep -q '"decision":"block"' "$OUT"; then
  echo "PASS: stdout passed through"
else
  echo "FAIL: stdout not passed through"; fail=1
fi

# 5) Every one of the five hook commands carries the guard.
for s in iwiki-bootstrap.py iwiki-recall.py iwiki-validate.py iwiki-reindex.py iwiki-sync.py; do
  c="$(get_cmd "$s")" || { echo "FAIL: no command for $s"; fail=1; continue; }
  case "$c" in
    *'[ -f '*' ] || exit 0'*) echo "PASS: $s guarded" ;;
    *) echo "FAIL: $s not guarded: $c"; fail=1 ;;
  esac
done

rm -rf "$EMPTY" "$BLOCK" "$CRASH" "$OKDIR" "$OUT"
if [ "$fail" = 0 ]; then echo "ALL PASS"; exit 0; else echo "SOME FAILED"; exit 1; fi
```

- [ ] **Step 2: Make the test executable and run it to verify it FAILS**

Run:
```bash
chmod +x tests/test_iwiki_hook_failopen.sh
bash tests/test_iwiki_hook_failopen.sh; echo "exit: $?"
```
Expected: FAIL. Pre-fix, test case 1 reports `FAIL: missing script -> allow — want exit 0, got 2` and test case 3 reports `FAIL: present + crash -> allow — want exit 0, got 1` (the unguarded `python3` exits 2 on a missing file, 1 on a crashing one), and the Step-5 loop reports `FAIL: ... not guarded`. Final line `SOME FAILED`, `exit: 1`.

- [ ] **Step 3: Apply the guard — overwrite `plugin/iwiki/hooks/hooks.json`**

Write `plugin/iwiki/hooks/hooks.json` with exactly this content (only the five `command` values changed from the original):

```json
{
  "description": "iwiki automation — bootstrap + baseline at SessionStart, record edits on PostToolUse, and at Stop batch-reindex any wiki changes then drive a wiki update for sources this session changed. All fail-soft and individually kill-switchable via IWIKI_AUTO_BOOTSTRAP / IWIKI_AUTO_QUERY / IWIKI_AUTO_REINDEX / IWIKI_AUTO_SYNC = 0.",
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "f=\"${CLAUDE_PLUGIN_ROOT}/hooks/iwiki-bootstrap.py\"; [ -f \"$f\" ] || exit 0; python3 \"$f\"; [ $? -eq 2 ] && exit 2 || exit 0",
            "timeout": 15
          }
        ]
      }
    ],
    "UserPromptSubmit": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "f=\"${CLAUDE_PLUGIN_ROOT}/hooks/iwiki-recall.py\"; [ -f \"$f\" ] || exit 0; python3 \"$f\"; [ $? -eq 2 ] && exit 2 || exit 0",
            "timeout": 20
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "matcher": "Write|Edit|MultiEdit",
        "hooks": [
          {
            "type": "command",
            "command": "f=\"${CLAUDE_PLUGIN_ROOT}/hooks/iwiki-validate.py\"; [ -f \"$f\" ] || exit 0; python3 \"$f\"; [ $? -eq 2 ] && exit 2 || exit 0",
            "timeout": 10
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Write|Edit|MultiEdit",
        "hooks": [
          {
            "type": "command",
            "command": "f=\"${CLAUDE_PLUGIN_ROOT}/hooks/iwiki-reindex.py\"; [ -f \"$f\" ] || exit 0; python3 \"$f\"; [ $? -eq 2 ] && exit 2 || exit 0",
            "timeout": 10
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "f=\"${CLAUDE_PLUGIN_ROOT}/hooks/iwiki-sync.py\"; [ -f \"$f\" ] || exit 0; python3 \"$f\"; [ $? -eq 2 ] && exit 2 || exit 0",
            "timeout": 120
          }
        ]
      }
    ]
  }
}
```

- [ ] **Step 4: Verify the JSON is valid**

Run:
```bash
python3 -m json.tool plugin/iwiki/hooks/hooks.json >/dev/null && echo "JSON OK"
```
Expected: `JSON OK` (no traceback).

- [ ] **Step 5: Run the test to verify it PASSES**

Run:
```bash
bash tests/test_iwiki_hook_failopen.sh; echo "exit: $?"
```
Expected: every line `PASS: ...`, final `ALL PASS`, `exit: 0`. This confirms missing→allow (the spec's rename-repro, in automated form), exit-2→block preserved, crash→allow, stdout passthrough, and all five commands guarded — covering all four spec Verification items (the `sh -c` + `CLAUDE_PLUGIN_ROOT` invocation also exercises the `$f`/`$?`/`${CLAUDE_PLUGIN_ROOT}` shell-expansion sanity check).

- [ ] **Step 6: Commit**

```bash
git add plugin/iwiki/hooks/hooks.json tests/test_iwiki_hook_failopen.sh
git commit -m "fix(iwiki): fail-open guard for plugin hook commands

A missing hook script made python3 exit 2; for the PreToolUse hook that
blocked all Write/Edit/MultiEdit. Wrap each of the 5 hook commands in
hooks.json with an inline POSIX guard: skip when the script file is absent,
run it when present, map only exit 2 to a block and any other non-zero to
allow, and pass stdout through. Add tests/test_iwiki_hook_failopen.sh.

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

## Self-Review

**1. Spec coverage:**
- Fail-open on missing file → Task 1, test case 1 + guard `[ -f "$f" ] || exit 0`. ✓
- Preserve intentional exit 2 → test case 2 + guard `[ $? -eq 2 ] && exit 2`. ✓
- Preserve stdout-JSON (bootstrap/recall/sync) → test case 4 (stdout passthrough); guard never touches stdout. ✓
- Change only hooks.json → Step 3 rewrites only command values; test file is new, not a source change. ✓
- All 5 hooks guarded → Step 3 covers all five; test case 5 asserts it. ✓
- Spec Verification items 1–4 → Steps 4 + 5 (json validity; missing/violation/valid behaviour; rename-repro as automated case 1; shell-expansion via `sh -c`). ✓
- Branch/PR off origin/dev → Global Constraints + worktree already created. ✓

**2. Placeholder scan:** No TBD/TODO; all code and commands are literal and complete. ✓

**3. Type consistency:** Helper names (`get_cmd`, `run_cmd`, `assert_exit`) and the guard string (`f=`, `$f`, `$?`, `${CLAUDE_PLUGIN_ROOT}`) are identical across the test, the Global Constraints, and the hooks.json content. The guard-pattern glob in test case 5 (`[ -f `...` ] || exit 0`) matches the string written in Step 3. ✓
