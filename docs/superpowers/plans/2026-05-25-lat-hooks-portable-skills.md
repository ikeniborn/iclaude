---
review:
  plan_hash: e7dc667de85949dc
  spec_hash: 52952a3d9f029e6c
  last_run: 2026-05-25
  phases:
    structure:     { status: passed }
    coverage:      { status: passed }
    dependencies:  { status: passed }
    verifiability: { status: passed }
    consistency:   { status: passed }
  findings:
    - id: F-001
      phase: coverage
      severity: WARNING
      section: "Task 7: Rename `skills/lat-md` → `skills/lat-init` + update content"
      section_hash: 1eb464447d46f8b4
      text: >-
        Spec requires only updating lat-md/SKILL.md (4× lat check → skill ref).
        Plan renames lat-md → lat-init and deletes old dir — extra scope not in spec.
        Spec Files Changed lists `skills/lat-md/SKILL.md`, not `lat-init`.
      verdict: fixed
    - id: F-002
      phase: coverage
      severity: WARNING
      section: "Task 10: Implement SKILL.md.new preservation in `--lat-init` handler"
      section_hash: 4ea5bfa8bbe1ec8c
      text: >-
        Task 10 has no spec backing. Neither SKILL.md.new preservation logic,
        iclaude.sh --lat-init handler changes, nor cleanup_lat_project_artifacts()
        lat-init dir handling appear in spec's requirements or Files Changed.
      verdict: fixed
---

# lat Hooks Portable + lat-check/lat-search Skills — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make lat hooks/pre-commit portable (no absolute paths), add lat-check and lat-search skills, and update lat-md skill to invoke lat-check skill instead of running bare `lat check`.

**Architecture:** Create `lat-runner.sh` as single binary resolver; update all callers (hooks, pre-commit, MCP wrapper) to use it; add two skills for Claude to invoke lat portably; update lat-md skill references.

**Tech Stack:** Bash, Python3 (settings.json editing), YAML frontmatter (skill files), JSON (settings.json)

---

## File Structure

| Action | Path |
|--------|------|
| **Create** | `.nvm-isolated/.claude-isolated/scripts/lat-runner.sh` |
| **Modify** | `.nvm-isolated/.claude-isolated/scripts/lat-mcp-wrapper.sh` (line 7) |
| **Modify** | `lib/lat/mcp.sh` — `inject_lat_mcp()` hook commands |
| **Modify** | `lib/lat/check.sh` — `install_lat_precommit()` portable block |
| **Create** | `.nvm-isolated/.claude-isolated/skills/lat-check/SKILL.md` |
| **Create** | `.nvm-isolated/.claude-isolated/skills/lat-search/SKILL.md` |
| **Modify** | `.nvm-isolated/.claude-isolated/skills/lat-md/SKILL.md` — 4× `lat check` → `lat-check` skill ref |
| **Modify** | `.nvm-isolated/.claude-isolated/commands/update-docs.md` — Phase 2 |
| **Modify** | `CLAUDE.md` — post-task checklist + before-work line |
| **Modify** | `tests/test_lat_module.sh` — update test [6], add tests [14][15][16] |

---

## Task 1: Create `lat-runner.sh`

**Files:**
- Create: `.nvm-isolated/.claude-isolated/scripts/lat-runner.sh`

- [ ] **Step 1: Write the failing test**

Add test [14] to `tests/test_lat_module.sh`:

```bash
echo "[14] lat-runner.sh resolves lat via NPM_CONFIG_PREFIX"
(
  tmpdir=$(mktemp -d)
  # Fake lat binary
  mkdir -p "$tmpdir/bin"
  printf '#!/bin/bash\necho "lat ok"\n' > "$tmpdir/bin/lat"
  chmod +x "$tmpdir/bin/lat"
  NPM_CONFIG_PREFIX="$tmpdir"
  runner="$SCRIPT_DIR/.nvm-isolated/.claude-isolated/scripts/lat-runner.sh"
  out=$("$runner" --version 2>&1 || true)
  # Expect to find and run our fake lat
  [[ "$out" == "lat ok" ]] || { echo "FAIL: expected 'lat ok', got '$out'"; rm -rf "$tmpdir"; exit 1; }
  rm -rf "$tmpdir"
)
echo "✓ lat-runner.sh resolves binary via NPM_CONFIG_PREFIX"
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bash tests/test_lat_module.sh 2>&1 | grep -A2 "\[14\]"
```

Expected: FAIL or "No such file" (script doesn't exist yet)

- [ ] **Step 3: Create the script**

```bash
#!/bin/bash
# lat universal binary resolver — single source of truth for all callers.
# Resolution order:
#   1. $NPM_CONFIG_PREFIX/bin/lat  (iclaude exported env)
#   2. <script-dir>/../../npm-global/bin/lat  (relative fallback)
#   3. command -v lat  (system PATH last resort)
_lat="${NPM_CONFIG_PREFIX:+${NPM_CONFIG_PREFIX}/bin/lat}"
if [[ ! -x "$_lat" ]]; then
    _lat="$(dirname "$0")/../../npm-global/bin/lat"
fi
if [[ ! -x "$_lat" ]]; then
    _lat="$(command -v lat 2>/dev/null)"
fi
if [[ ! -x "$_lat" ]]; then
    echo "lat: binary not found (tried NPM_CONFIG_PREFIX, relative path, and PATH)" >&2
    exit 127
fi
exec "$_lat" "$@"
```

Make executable: `chmod +x .nvm-isolated/.claude-isolated/scripts/lat-runner.sh`

- [ ] **Step 4: Run test to verify it passes**

```bash
bash tests/test_lat_module.sh 2>&1 | grep -E "\[14\]|✓.*lat-runner"
```

Expected: `✓ lat-runner.sh resolves binary via NPM_CONFIG_PREFIX`

- [ ] **Step 5: Commit**

```bash
git add .nvm-isolated/.claude-isolated/scripts/lat-runner.sh tests/test_lat_module.sh
git commit -m "feat(lat): add lat-runner.sh — universal binary resolver"
```

---

## Task 2: Fix `lat-mcp-wrapper.sh` relative path

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/scripts/lat-mcp-wrapper.sh:7`

- [ ] **Step 1: Write the failing test**

Add test [15] to `tests/test_lat_module.sh`:

```bash
echo "[15] lat-mcp-wrapper.sh uses correct relative path (../../)"
wrapper="$SCRIPT_DIR/.nvm-isolated/.claude-isolated/scripts/lat-mcp-wrapper.sh"
grep -q '"\$(dirname.*\)\.\./\.\./npm-global/bin/lat"' "$wrapper" \
  || grep -q '"$(dirname "$0")/../../npm-global/bin/lat"' "$wrapper" \
  || { echo "FAIL: wrapper still uses wrong path (../../../)"; exit 1; }
echo "✓ lat-mcp-wrapper.sh uses ../../npm-global/bin/lat"
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bash tests/test_lat_module.sh 2>&1 | grep -A2 "\[15\]"
```

Expected: FAIL (wrapper currently has `../../../`)

- [ ] **Step 3: Fix the path**

In `.nvm-isolated/.claude-isolated/scripts/lat-mcp-wrapper.sh`, line 7:

Old:
```bash
lat_bin="$(dirname "$0")/../../../npm-global/bin/lat"
```

New:
```bash
lat_bin="$(dirname "$0")/../../npm-global/bin/lat"
```

- [ ] **Step 4: Run test to verify it passes**

```bash
bash tests/test_lat_module.sh 2>&1 | grep -E "\[15\]|✓.*wrapper"
```

Expected: `✓ lat-mcp-wrapper.sh uses ../../npm-global/bin/lat`

- [ ] **Step 5: Commit**

```bash
git add .nvm-isolated/.claude-isolated/scripts/lat-mcp-wrapper.sh tests/test_lat_module.sh
git commit -m "fix(lat): correct relative path in lat-mcp-wrapper.sh (3 levels → 2)"
```

---

## Task 3: Update `inject_lat_mcp()` — use `lat-runner.sh` in hooks

**Files:**
- Modify: `lib/lat/mcp.sh:50-51` (hook_submit and hook_stop lines in Python heredoc)
- Modify: `tests/test_lat_module.sh` — update test [6]

- [ ] **Step 1: Update test [6] to expect lat-runner.sh path**

In `tests/test_lat_module.sh`, test [6] currently asserts `lat['command'] == '/usr/local/bin/lat'`. Change to assert hook commands use `lat-runner.sh`.

Replace the test [6] python assertion block:

```python
python3 -c "
import json, sys
with open('$tmpdir/settings.json') as f:
    s = json.load(f)
assert 'mcpServers' in s, 'mcpServers missing'
assert 'lat' in s['mcpServers'], 'lat server missing'
lat = s['mcpServers']['lat']
# MCP command: still uses lat_wrapper (or lat_bin fallback)
assert lat['type'] == 'stdio', f'wrong type: {lat[\"type\"]}'
# Hook commands must use lat-runner.sh, not absolute lat_bin
hooks = s.get('hooks', {})
submit_cmds = [h.get('command','') for g in hooks.get('UserPromptSubmit',[]) for h in g.get('hooks',[])]
stop_cmds   = [h.get('command','') for g in hooks.get('Stop',[])            for h in g.get('hooks',[])]
assert any('lat-runner.sh' in c for c in submit_cmds), f'UserPromptSubmit hook missing lat-runner.sh: {submit_cmds}'
assert any('lat-runner.sh' in c for c in stop_cmds),   f'Stop hook missing lat-runner.sh: {stop_cmds}'
assert not any('/usr/local/bin/lat' in c for c in submit_cmds + stop_cmds), 'absolute lat path still in hooks'
print('JSON structure OK')
"
```

- [ ] **Step 2: Run test [6] to verify it fails**

```bash
bash tests/test_lat_module.sh 2>&1 | grep -A5 "\[6\]"
```

Expected: FAIL (hooks currently use absolute path)

- [ ] **Step 3: Update `inject_lat_mcp()` hook commands**

In `lib/lat/mcp.sh`, inside the Python heredoc (lines ~50–51), replace:

```python
hook_submit = {'type': 'command', 'command': f'[[ -d "$LAUNCH_DIR/lat.md" ]] && "{lat_bin}" hook claude UserPromptSubmit || true'}
hook_stop   = {'type': 'command', 'command': f'[[ -d "$LAUNCH_DIR/lat.md" ]] && "{lat_bin}" hook claude Stop || true'}
```

With (plain strings, no f-prefix, `$CLAUDE_CONFIG_DIR` expands at hook runtime):

```python
hook_submit = {'type': 'command', 'command': '[[ -d "$LAUNCH_DIR/lat.md" ]] && "${CLAUDE_CONFIG_DIR}/scripts/lat-runner.sh" hook claude UserPromptSubmit || true'}
hook_stop   = {'type': 'command', 'command': '[[ -d "$LAUNCH_DIR/lat.md" ]] && "${CLAUDE_CONFIG_DIR}/scripts/lat-runner.sh" hook claude Stop || true'}
```

- [ ] **Step 4: Run test [6] to verify it passes, run all tests**

```bash
bash tests/test_lat_module.sh 2>&1 | tail -20
```

Expected: all tests pass including `[6]` and `[7]`

- [ ] **Step 5: Commit**

```bash
git add lib/lat/mcp.sh tests/test_lat_module.sh
git commit -m "fix(lat): hooks use lat-runner.sh instead of absolute LAT_BIN path"
```

---

## Task 4: Fix `install_lat_precommit()` — portable binary resolution

**Files:**
- Modify: `lib/lat/check.sh:60-69` (heredoc block in `install_lat_precommit()`)

- [ ] **Step 1: Write the failing test**

Add test [16] to `tests/test_lat_module.sh`:

```bash
echo "[16] install_lat_precommit() uses portable resolution (no absolute LAT_BIN)"
(
  print_success() { :; }
  print_warning() { :; }
  print_error()   { :; }
  print_info()    { :; }
  tmpdir=$(mktemp -d)
  git init -q "$tmpdir"
  LAUNCH_DIR="$tmpdir"
  LAT_BIN="/absolute/path/to/lat"
  source "$SCRIPT_DIR/lib/lat/check.sh"
  install_lat_precommit
  hook="$tmpdir/.git/hooks/pre-commit"
  # Must NOT contain the absolute path — only portable resolution
  grep -q "/absolute/path/to/lat" "$hook" \
    && { echo "FAIL: absolute path found in hook"; rm -rf "$tmpdir"; exit 1; }
  grep -q "NPM_CONFIG_PREFIX" "$hook" \
    || { echo "FAIL: NPM_CONFIG_PREFIX not in hook"; rm -rf "$tmpdir"; exit 1; }
  grep -q "command -v lat" "$hook" \
    || { echo "FAIL: 'command -v lat' fallback not in hook"; rm -rf "$tmpdir"; exit 1; }
  rm -rf "$tmpdir"
)
echo "✓ install_lat_precommit() uses portable resolution"
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bash tests/test_lat_module.sh 2>&1 | grep -A3 "\[16\]"
```

Expected: FAIL (current hook embeds absolute `$LAT_BIN`)

- [ ] **Step 3: Fix the heredoc in `install_lat_precommit()`**

In `lib/lat/check.sh`, replace the `cat >> "$hook_file" << HOOKEOF ... HOOKEOF` block (lines ~61–69):

```bash
    cat >> "$hook_file" << HOOKEOF

${_LAT_HOOK_BEGIN}
# lat.md reference integrity check — installed by iclaude --lat-check
_lat="\${NPM_CONFIG_PREFIX:+\${NPM_CONFIG_PREFIX}/bin/lat}"
[[ -x "\$_lat" ]] || _lat="\$(command -v lat 2>/dev/null)"
[[ -x "\$_lat" ]] && "\$_lat" check || true
${_LAT_HOOK_END}
HOOKEOF
```

Note: `_LAT_HOOK_BEGIN`/`_LAT_HOOK_END` expand at write time (desired — they insert the marker strings). The `\$` sequences expand at hook runtime.

- [ ] **Step 4: Run tests to verify passes**

```bash
bash tests/test_lat_module.sh 2>&1 | tail -25
```

Expected: `[16]` passes and existing `[10]`, `[11]` still pass.

- [ ] **Step 5: Commit**

```bash
git add lib/lat/check.sh tests/test_lat_module.sh
git commit -m "fix(lat): pre-commit hook uses portable NPM_CONFIG_PREFIX resolution"
```

---

## Task 5: Create `skills/lat-check/SKILL.md`

**Files:**
- Create: `.nvm-isolated/.claude-isolated/skills/lat-check/SKILL.md`

- [ ] **Step 1: Create the skill file**

```markdown
---
name: lat-check
description: >-
  Run lat check portably in any project launched via iclaude. Validates all
  wiki links and code refs in lat.md/. Use when CLAUDE.md says "run lat check"
  or after editing lat.md/ files.
---

# lat-check

Run `lat check` portably using the binary resolver, from the project directory.

## How to run

Prefer the runner script when available:

```bash
"${CLAUDE_CONFIG_DIR}/scripts/lat-runner.sh" check
```

Alternative when `NPM_CONFIG_PREFIX` is exported:

```bash
"${NPM_CONFIG_PREFIX}/bin/lat" check
```

Always run from the project directory (not the iclaude dir). `LAUNCH_DIR` is the project root.

## Exit codes

- `0` — all wiki links and code refs valid; nothing to fix
- `1` — broken refs found; output lists each broken link with file path and line number

## When to use

- CLAUDE.md post-task checklist says "Run `lat check`"
- After creating or editing `lat.md/` files
- Before committing changes in a project with `lat.md/`

Do NOT run `lat check` via bare `Bash(lat check)` — the binary is not on PATH outside iclaude context.
```

- [ ] **Step 2: Verify file exists and skill name is correct**

```bash
grep "^name:" .nvm-isolated/.claude-isolated/skills/lat-check/SKILL.md
```

Expected: `name: lat-check`

- [ ] **Step 3: Commit**

```bash
git add .nvm-isolated/.claude-isolated/skills/lat-check/SKILL.md
git commit -m "feat(skills): add lat-check skill for portable lat check invocation"
```

---

## Task 6: Create `skills/lat-search/SKILL.md`

**Files:**
- Create: `.nvm-isolated/.claude-isolated/skills/lat-search/SKILL.md`

- [ ] **Step 1: Create the skill file**

```markdown
---
name: lat-search
description: >-
  Find lat.md sections and run semantic search portably in any project via
  iclaude. Use when CLAUDE.md says "run lat search" or when you need to locate
  documentation sections before starting work.
---

# lat-search

Run lat search, locate, refs, and section commands portably.

## Binary resolution

```bash
_lat="${CLAUDE_CONFIG_DIR}/scripts/lat-runner.sh"
# fallback: "${NPM_CONFIG_PREFIX}/bin/lat"
```

Always run from the project directory (`$LAUNCH_DIR`).

## Commands

```bash
# Semantic search (requires LAT_LLM_KEY in .claude_config)
"$_lat" search "your natural language query"

# Find section by name — no LLM key needed
"$_lat" locate "Section Name"

# Show section content
"$_lat" section path/to/file#Heading

# Find what references a section
"$_lat" refs path/to/file#Heading

# Expand [[refs]] in a prompt to file locations
"$_lat" expand "prompt text with [[Section Name]]"
```

## If LAT_LLM_KEY is not set

`lat search` requires an LLM key. If not available, use `lat locate` as a fallback (no key needed):

```bash
"${CLAUDE_CONFIG_DIR}/scripts/lat-runner.sh" locate "Section Name"
```

Inform the user: "LAT_LLM_KEY not set — using `lat locate` instead of `lat search`. Set `LAT_LLM_KEY` in `.claude_config` for semantic search."

## When to use

- CLAUDE.md "Before starting work" says "run `lat search`"
- You need to find documentation sections relevant to a task
- You need to expand `[[refs]]` to file locations

Do NOT run `lat search` via bare `Bash(lat search)` — the binary is not on PATH outside iclaude context.
```

- [ ] **Step 2: Verify skill name**

```bash
grep "^name:" .nvm-isolated/.claude-isolated/skills/lat-search/SKILL.md
```

Expected: `name: lat-search`

- [ ] **Step 3: Commit**

```bash
git add .nvm-isolated/.claude-isolated/skills/lat-search/SKILL.md
git commit -m "feat(skills): add lat-search skill for portable lat search/locate invocation"
```

---

## Task 7: Update `skills/lat-md/SKILL.md` — replace `lat check` refs with `lat-check` skill

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/skills/lat-md/SKILL.md` (4 lines)

- [ ] **Step 1: Verify 4 references exist**

```bash
grep -n "lat check" .nvm-isolated/.claude-isolated/skills/lat-md/SKILL.md
```

Expected: 4 matches

- [ ] **Step 2: Replace all 4 references**

In `.nvm-isolated/.claude-isolated/skills/lat-md/SKILL.md`, apply these substitutions:

| Old | New |
|-----|-----|
| `` `lat check` enforces this rule. `` | `Invoke the \`lat-check\` skill to enforce this rule.` |
| `` `lat check` validates that all targets exist. `` | `Invoke the \`lat-check\` skill to validate that all targets exist.` |
| `` - `lat check` flags unreferenced specs and dangling code refs `` | `- Invoke the \`lat-check\` skill to flag unreferenced specs and dangling code refs` |
| `` Always run `lat check` after editing `lat.md/` files. It validates: `` | `Always invoke the \`lat-check\` skill after editing \`lat.md/\` files. It validates:` |

- [ ] **Step 3: Verify 0 raw `lat check` refs remain**

```bash
grep -c "lat check" .nvm-isolated/.claude-isolated/skills/lat-md/SKILL.md
```

Expected: `0`

- [ ] **Step 4: Commit**

```bash
git add .nvm-isolated/.claude-isolated/skills/lat-md/SKILL.md
git commit -m "fix(skills): lat-md skill replaces bare lat check refs with lat-check skill invocation"
```

---

## Task 8: Update `commands/update-docs.md` — Phase 2

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/commands/update-docs.md:22-24`

- [ ] **Step 1: Verify current Phase 2 text**

```bash
grep -n "lat check\|lat-check\|Bash.*lat\|Skill.*lat" \
  .nvm-isolated/.claude-isolated/commands/update-docs.md
```

Expected: line with `Bash(lat check)` in Phase 2

- [ ] **Step 2: Update Phase 2**

In `commands/update-docs.md`, replace the Phase 2 block:

Old:
```
3. **Phase 2: Проверь целостность документации** — запусти `lat check` в проекте
   - `Bash(lat check)` в директории проекта
   - exit 0 → continue; exit 1 → выведи broken refs, предупреди пользователя
```

New:
```
3. **Phase 2: Проверь целостность документации** — вызови skill `lat-check`
   - `Skill(lat-check)` в директории проекта (binary не в PATH вне iclaude)
   - exit 0 → continue; exit 1 → выведи broken refs, предупреди пользователя
```

- [ ] **Step 3: Verify change**

```bash
grep -A3 "Phase 2" .nvm-isolated/.claude-isolated/commands/update-docs.md
```

Expected: mentions `Skill(lat-check)`, no `Bash(lat check)`

- [ ] **Step 4: Commit**

```bash
git add .nvm-isolated/.claude-isolated/commands/update-docs.md
git commit -m "fix(docs): update-docs Phase 2 uses Skill(lat-check) not Bash(lat check)"
```

---

## Task 9: Update `CLAUDE.md` — post-task checklist and before-work

**Files:**
- Modify: `CLAUDE.md:1-11`

- [ ] **Step 1: View current lines**

```bash
head -12 CLAUDE.md
```

Expected: see `lat search` in "Before starting work" and `lat check` in post-task checklist

- [ ] **Step 2: Update both references**

In `CLAUDE.md`, replace the top section:

Old:
```markdown
# Before starting work

- Run `lat search` to find sections relevant to your task. Read them before writing code.
- Run `lat expand` on user prompts to expand any `[[refs]]` — resolves section names to file locations.

# Post-task checklist (REQUIRED — do not skip)

After EVERY task, before responding to the user:

- [ ] Update `lat.md/` if you added or changed any functionality, architecture, tests, or behavior
- [ ] Run `lat check` — all wiki links and code refs must pass
```

New:
```markdown
# Before starting work

- Invoke `lat-search` skill to find sections relevant to your task. Read them before writing code.
- Run `lat expand` on user prompts to expand any `[[refs]]` — resolves section names to file locations.

# Post-task checklist (REQUIRED — do not skip)

After EVERY task, before responding to the user:

- [ ] Update `lat.md/` if you added or changed any functionality, architecture, tests, or behavior
- [ ] Invoke `lat-check` skill — all wiki links and code refs must pass
```

- [ ] **Step 3: Verify**

```bash
head -12 CLAUDE.md
```

Expected: `lat-search` skill and `lat-check` skill references

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md
git commit -m "fix(docs): CLAUDE.md uses lat-check/lat-search skills instead of bare bash"
```

---

## Self-Review

### Spec coverage check

| Spec requirement | Task |
|------------------|------|
| `lat-runner.sh` universal resolver (3-step resolution) | Task 1 |
| Fix `lat-mcp-wrapper.sh` path (`../../../` → `../../`) | Task 2 |
| `inject_lat_mcp()` hooks use `lat-runner.sh` | Task 3 |
| `install_lat_precommit()` portable resolution | Task 4 |
| `skills/lat-check/SKILL.md` | Task 5 |
| `skills/lat-search/SKILL.md` | Task 6 |
| `skills/lat-md/SKILL.md` 4× `lat check` → `lat-check` skill ref | Task 7 |
| `commands/update-docs.md` Phase 2 | Task 8 |
| `CLAUDE.md` post-task checklist + before-work | Task 9 |

All spec requirements covered. No placeholders. Types and function names consistent throughout.
