# Ralph-Loop to Bash Loop Migration Guide

**Version:** 1.0.0
**Date:** 2026-01-25
**Status:** ✅ COMPLETE

---

## Overview

This guide helps users migrate from the **deprecated ralph-loop plugin** to the new **bash loop mode** implemented in iclaude.sh.

---

## Why the Change?

### Ralph-Loop Plugin (Deprecated)
- ❌ npm installation method deprecated by Anthropic
- ❌ Plugin-based architecture (complex setup)
- ❌ Limited to Claude Code session context
- ❌ No parallel execution support
- ❌ No state persistence

### Bash Loop Mode (New)
- ✅ Native bash implementation (no external dependencies)
- ✅ Parallel execution with git worktrees
- ✅ State persistence for recovery
- ✅ AI-assisted conflict resolution
- ✅ More powerful and flexible

---

## Migration Steps

### Before (ralph-loop plugin)

**Inside Claude Code session:**
```bash
/ralph-loop "Fix TypeScript error TS2322 in app.ts:45" \
  --context "File: app.ts, Line: 45, PR: 123" \
  --completion-promise "All checks pass" \
  --max-iterations 5
```

### After (bash loop mode)

**Step 1: Create task definition (task.md)**
```markdown
# Task: Fix TypeScript Error TS2322

## Description
Fix type mismatch in app.ts:45
Type 'string' is not assignable to type 'number'

## Completion Promise
npm run type-check

## Validation Command
npm run type-check

## Max Iterations
5

## Git Config
Branch: fix/ts2322-app
Commit message: fix: resolve TS2322 type mismatch in app.ts
Auto-push: true
```

**Step 2: Run bash loop (external to Claude session)**
```bash
./iclaude.sh --loop task.md
```

---

## Feature Comparison

| Feature | Ralph-Loop Plugin | Bash Loop Mode |
|---------|-------------------|----------------|
| **Installation** | /plugin install | Already in iclaude.sh |
| **Execution** | Inside Claude session | External bash command |
| **Parallel** | ❌ No | ✅ Yes (--loop-parallel) |
| **Worktrees** | ❌ No | ✅ Yes (task isolation) |
| **State Persistence** | ❌ No | ✅ Yes (/tmp state file) |
| **AI Conflict Resolution** | ❌ No | ✅ Yes (auto-merge) |
| **Max Parallel** | 1 | Configurable (default: 5) |
| **Git Integration** | ⚠️ Basic | ✅ Advanced (branches, auto-push) |
| **Task Format** | Command-line args | Markdown file |

---

## Common Use Cases

### Use Case 1: Fix CI/CD Errors

**Before:**
```bash
/ralph-loop "Fix ESLint errors" \
  --completion-promise "gh pr checks 123 shows all ✓"
```

**After:**
```markdown
# Task: Fix ESLint Errors

## Description
Fix all ESLint violations in PR #123

## Completion Promise
gh pr checks 123

## Validation Command
gh pr checks 123 | grep -E "✓|success" | wc -l

## Max Iterations
5
```

```bash
./iclaude.sh --loop fix-eslint.md
```

### Use Case 2: Parallel Task Execution

**Before:** Not possible with ralph-loop

**After:**
```markdown
# Task: Refactor Module A

## Parallel Group
Group: 1

## Description
Refactor module A to use new API

---

# Task: Refactor Module B

## Parallel Group
Group: 1

## Description
Refactor module B to use new API
(runs in parallel with Module A)
```

```bash
./iclaude.sh --loop-parallel refactor-tasks.md
```

---

## Breaking Changes

### 1. No Auto-Invocation from Skills

**Before:** pr-automation skill automatically invoked ralph-loop

**After:** Manual invocation required

**Migration:**
```bash
# Old workflow (automatic)
/skill pr-automation
# (ralph-loop invoked automatically during error fixing)

# New workflow (manual)
/skill pr-automation
# (create PR, monitor CI/CD)
# Then manually:
./iclaude.sh --loop fix-errors.md
```

### 2. Task Definition Format

**Before:** Command-line arguments

**After:** Markdown file

**Migration:** Convert command-line args to Markdown sections (see examples above)

### 3. Schema Changes (pr-automation skill)

**Before:**
```json
{
  "ralphLoopState": {
    "active": true,
    "iteration": 2,
    "targetError": {...}
  }
}
```

**After:**
```json
{
  "fixIterations": 2,
  "autoFixedErrors": [...]
}
```

**Note:** `ralphLoopState` removed, but `fixIterations` and `autoFixedErrors` preserved.

---

## Troubleshooting

### Q: Can I still use ralph-loop plugin?

**A:** No. Ralph-loop plugin has been removed from dependencies. Use bash loop mode instead.

### Q: How do I run loop mode from within Claude Code?

**A:** You can't. Bash loop mode runs **external** to Claude session for better isolation. Use terminal/shell to invoke:
```bash
./iclaude.sh --loop task.md
```

### Q: Can I pass secrets in task definitions?

**A:** No. Task files should be committed to git. Use environment variables for secrets:
```markdown
## Validation Command
export API_KEY=$MY_SECRET && curl -H "Auth: $API_KEY" ...
```

### Q: What happens if max iterations reached?

**A:** Loop exits with code 1 (failure). Review logs in `/tmp/iclaude-loop-iter-N-$$.log` and adjust task or fix manually.

---

## Benefits of Migration

1. **More Powerful:** Parallel execution, worktrees, state persistence
2. **Better Isolation:** Each parallel task runs in separate worktree
3. **Easier Debugging:** Logs saved to `/tmp`, state saved for recovery
4. **Git-Friendly:** Task definitions committed to git (reproducible)
5. **No Plugin Setup:** No need for `/plugin install`

---

## Support

For issues or questions:
- Check examples: `examples/test-loop-*.md`
- Read docs: `CLAUDE.md#loop-mode-commands`
- Review: `WEEK1-IMPLEMENTATION-SUMMARY.md`, `WEEK2-IMPLEMENTATION-SUMMARY.md`

---

## Changelog

### 2026-01-25 - v1.0.0
- Initial migration guide
- Ralph-loop plugin deprecated
- Bash loop mode fully implemented (Week 1-2)
- All skills updated (Week 3)
- All templates updated (Week 4)
