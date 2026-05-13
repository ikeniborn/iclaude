# Design: graphify_python gitignore fix

**Date:** 2026-05-13  
**Problem:** `.graphify/.graphify_python` stores absolute path to Python interpreter (e.g. `/home/user/.../.nvm-isolated/.claude-isolated/graphify/graphifyy/bin/python`). File is tracked in git → breaks on other machines after `git pull`. `.graphify_root` is not a problem — always contains `.` (relative), portable across machines.

## Root Cause

SKILL.md строка 114:
```bash
"$PYTHON" -c "import sys; open('${GRAPHIFY_OUT}/.graphify_python', 'w').write(sys.executable)"
```
`sys.executable` — абсолютный путь, машино-специфичный. Оба файла `.graphify_python` и `.graphify_root` попадают в git без ограничений.

## Solution: gitignore + untrack

### Changes

| File | Change |
|------|--------|
| `.gitignore` | Add `.graphify/.graphify_python` |
| git index | `git rm --cached .graphify/.graphify_python` |
| `SKILL.md` line 116 | `echo "$(cd INPUT_PATH && pwd)"` → `echo "."` |

### Why it works

**`.graphify_python`:** On a fresh clone, running `/graphify` always triggers SKILL.md Step 1 (lines 89–116), which resolves Python (uv → shebang → python3) and writes `.graphify_python` with the correct local path. Additionally, lines 785–794 provide a guard before subcommands — if `.graphify_python` is missing it re-resolves from the `graphify` binary shebang.

**`.graphify_root`:** Always `.` since iclaude always invokes graphify with `.`. Stays tracked in git — no portability issue. SKILL.md line 116 fixed to `echo "."` for correctness (was writing absolute path via `$(cd INPUT_PATH && pwd)`).

### What does NOT change

- Re-resolve logic (lines 782–794) — already correct, no edits needed
- All `$(cat "${GRAPHIFY_OUT}/.graphify_python")` call sites — unchanged
- `lib/graphify/install.sh` — unchanged
- All 5 portability patches — unchanged

## Behavior After Fix

1. Developer A commits graph → `.graphify_python` NOT in commit, `.graphify_root` in commit as `.`
2. Developer B clones → `.graphify_python` absent, `.graphify_root` = `.` (correct)
3. Developer B runs `/graphify` → SKILL.md Step 1 creates `.graphify_python` with B's local path
4. `.graphify_root` stays `.` — no action needed

## Out of Scope

- Changing re-resolve strategy (shebang vs uv tool run)
- Making `.graphify_python` portable across machines without gitignore
