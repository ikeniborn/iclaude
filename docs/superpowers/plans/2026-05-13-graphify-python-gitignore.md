# graphify_python gitignore fix — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prevent `.graphify/.graphify_python` (machine-specific absolute Python path) from being committed to git, breaking other machines after `git pull`.

**Architecture:** Three surgical edits — add gitignore rule, untrack existing file from index, fix SKILL.md line 116 to write relative `.graphify_root`. No logic changes to re-resolve, no new files.

**Tech Stack:** bash, git

---

## Files Modified

| File | Change |
|------|--------|
| `.gitignore` | Add `.graphify/.graphify_python` entry |
| `.nvm-isolated/.claude-isolated/skills/graphify/SKILL.md` | Line 116: `echo "$(cd INPUT_PATH && pwd)"` → `echo "."` |
| git index | `git rm --cached .graphify/.graphify_python` (untrack, keep local copy) |

---

### Task 1: Gitignore `.graphify_python`

**Files:**
- Modify: `.gitignore`

- [ ] **Step 1: Add `.graphify_python` to `.gitignore`**

Append after the `graphify-out/` line:

```
# graphify machine-specific interpreter path (re-resolved per-machine by SKILL.md Step 1)
.graphify/.graphify_python
```

- [ ] **Step 2: Verify pattern is correct**

```bash
git check-ignore -v .graphify/.graphify_python
```

Expected output:
```
.gitignore:<N>:.graphify/.graphify_python	.graphify/.graphify_python
```

- [ ] **Step 3: Untrack the file from git index (keep local copy)**

```bash
git rm --cached .graphify/.graphify_python
```

Expected output:
```
rm '.graphify/.graphify_python'
```

- [ ] **Step 4: Verify file is no longer tracked**

```bash
git ls-files .graphify/.graphify_python
```

Expected: empty output (no files listed).

- [ ] **Step 5: Verify local file still exists**

```bash
cat .graphify/.graphify_python
```

Expected: prints the absolute Python path (file preserved locally, just untracked).

- [ ] **Step 6: Commit**

```bash
git add .gitignore
git commit -m "chore(graphify): gitignore .graphify_python — machine-specific absolute path

.graphify_python stores sys.executable (absolute path to Python interpreter).
Tracked in git → breaks on other machines after git pull.

SKILL.md Step 1 re-resolves the interpreter on first /graphify run if the
file is absent, so gitignoring it is safe."
```

---

### Task 2: Fix SKILL.md line 116 — write `.` not absolute path

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/skills/graphify/SKILL.md:116`

- [ ] **Step 1: Verify current content of line 116**

```bash
sed -n '114,117p' .nvm-isolated/.claude-isolated/skills/graphify/SKILL.md
```

Expected:
```
"$PYTHON" -c "import sys; open('${GRAPHIFY_OUT}/.graphify_python', 'w').write(sys.executable)"
# Save scan root so `graphify update` (no args) knows where to look next time
echo "$(cd INPUT_PATH && pwd)" > "${GRAPHIFY_OUT}/.graphify_root"
```

- [ ] **Step 2: Replace absolute-path echo with literal `.`**

In `.nvm-isolated/.claude-isolated/skills/graphify/SKILL.md`, change line 116 from:
```
echo "$(cd INPUT_PATH && pwd)" > "${GRAPHIFY_OUT}/.graphify_root"
```
to:
```
echo "." > "${GRAPHIFY_OUT}/.graphify_root"
```

- [ ] **Step 3: Verify change**

```bash
sed -n '115,117p' .nvm-isolated/.claude-isolated/skills/graphify/SKILL.md
```

Expected:
```
# Save scan root so `graphify update` (no args) knows where to look next time
echo "." > "${GRAPHIFY_OUT}/.graphify_root"
```

- [ ] **Step 4: Confirm no other `$(cd INPUT_PATH && pwd)` patterns remain in SKILL.md**

```bash
grep -n "cd INPUT_PATH && pwd" .nvm-isolated/.claude-isolated/skills/graphify/SKILL.md
```

Expected: empty output.

- [ ] **Step 5: Commit**

```bash
git add .nvm-isolated/.claude-isolated/skills/graphify/SKILL.md
git commit -m "fix(graphify): write '.' to .graphify_root instead of absolute path

$(cd INPUT_PATH && pwd) expands to the absolute CWD, which is machine-specific.
iclaude always invokes graphify with '.' so the root is always the project dir.
Write '.' explicitly for correctness and consistency with watch.py patch 02."
```

---

## Verification

After both tasks:

```bash
# 1. .graphify_python not in git index
git ls-files .graphify/.graphify_python
# Expected: empty

# 2. .gitignore covers it
git check-ignore -v .graphify/.graphify_python
# Expected: .gitignore:<N>:.graphify/.graphify_python  .graphify/.graphify_python

# 3. SKILL.md line 116 is correct
grep -n 'graphify_root' .nvm-isolated/.claude-isolated/skills/graphify/SKILL.md | head -3
# Expected: 116:echo "." > "${GRAPHIFY_OUT}/.graphify_root"

# 4. No absolute-path pattern remains
grep -n 'cd INPUT_PATH && pwd' .nvm-isolated/.claude-isolated/skills/graphify/SKILL.md
# Expected: empty
```
