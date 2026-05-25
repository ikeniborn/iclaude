# Portable Config Paths Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace all absolute paths in tracked `settings.json` and `router.json` with `$ENV_VAR` references so the repo is portable across machines and directory moves.

**Architecture:** Three changes: (1) `router.json` transformer path → `${CLAUDE_CONFIG_DIR}/...`; (2) `inject_lat_mcp()` writes a literal `$CLAUDE_CONFIG_DIR` string instead of the evaluated bash variable; (3) `lat-mcp-wrapper.sh` takes over PATH/Node setup so the injected `env.PATH` can be removed entirely.

**Tech Stack:** Bash, Python (inline heredoc in mcp.sh), JSON

---

## File Map

| File | Action | What changes |
|------|--------|--------------|
| `.nvm-isolated/.claude-isolated/router.json` | Modify | `transformers[0].path` abs → `${CLAUDE_CONFIG_DIR}/...` |
| `.nvm-isolated/.claude-isolated/router.json.example` | Modify | Add `transformers` example block |
| `lib/lat/mcp.sh` | Modify lines 19–46 | Remove `node_bin`/`node_dir` vars; write literal `$CLAUDE_CONFIG_DIR` in Python; drop `env.PATH` |
| `.nvm-isolated/.claude-isolated/scripts/lat-mcp-wrapper.sh` | Modify | Add NVM source + `$ISOLATED_NVM_DIR/npm-global/bin` prepend to PATH |
| `.nvm-isolated/.claude-isolated/settings.json` | Modify | Apply portable `mcpServers.lat` entry directly (no abs paths) |

---

### Task 1: Fix `router.json` — portable transformer path

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/router.json`

- [ ] **Step 1: Verify current state fails portability check**

```bash
grep -c '/home/' .nvm-isolated/.claude-isolated/router.json
```
Expected output: `1` (one abs path present)

- [ ] **Step 2: Replace transformer path**

Open `.nvm-isolated/.claude-isolated/router.json`. Find the `transformers` section (lines 69–73):

```json
"transformers": [
  {
    "path": "/home/ikeniborn/Documents/Project/iclaude/.nvm-isolated/.claude-isolated/.claude-code-router/plugins/ollama-reasoning.js"
  }
]
```

Replace with:

```json
"transformers": [
  {
    "path": "${CLAUDE_CONFIG_DIR}/.claude-code-router/plugins/ollama-reasoning.js"
  }
]
```

- [ ] **Step 3: Verify no abs paths remain**

```bash
grep -c '/home/' .nvm-isolated/.claude-isolated/router.json
```
Expected output: `0`

- [ ] **Step 4: Validate JSON**

```bash
python3 -m json.tool .nvm-isolated/.claude-isolated/router.json > /dev/null && echo OK
```
Expected: `OK`

- [ ] **Step 5: Commit**

```bash
git add .nvm-isolated/.claude-isolated/router.json
git commit -m "fix(router): replace absolute transformer path with \${CLAUDE_CONFIG_DIR}"
```

---

### Task 2: Update `router.json.example` — add transformers block

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/router.json.example`

- [ ] **Step 1: Add transformers section at end of example file**

Open `.nvm-isolated/.claude-isolated/router.json.example`. After the closing `}` of `_Router_ollama_cloud_example` block (line 103), but before the final `}` on line 104, add:

```json
  "_comment_transformers": "Custom CCR transformers — use ${CLAUDE_CONFIG_DIR} for portable paths (no absolute paths)",
  "transformers": [
    {
      "_comment": "Example: custom reasoning transformer. Path uses ${CLAUDE_CONFIG_DIR} — expanded by CCR from iclaude env.",
      "path": "${CLAUDE_CONFIG_DIR}/.claude-code-router/plugins/ollama-reasoning.js"
    }
  ]
```

Full tail of file after edit should look like:

```json
  "_Router_ollama_cloud_example": {
    ...
  },

  "_comment_transformers": "Custom CCR transformers — use ${CLAUDE_CONFIG_DIR} for portable paths (no absolute paths)",
  "transformers": [
    {
      "_comment": "Example: custom reasoning transformer. Path uses ${CLAUDE_CONFIG_DIR} — expanded by CCR from iclaude env.",
      "path": "${CLAUDE_CONFIG_DIR}/.claude-code-router/plugins/ollama-reasoning.js"
    }
  ]
}
```

- [ ] **Step 2: Validate JSON**

```bash
python3 -m json.tool .nvm-isolated/.claude-isolated/router.json.example > /dev/null && echo OK
```
Expected: `OK`

- [ ] **Step 3: Commit**

```bash
git add .nvm-isolated/.claude-isolated/router.json.example
git commit -m "docs(router): add transformers example with portable \${CLAUDE_CONFIG_DIR} path"
```

---

### Task 3: Update `lat-mcp-wrapper.sh` — self-contained PATH setup

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/scripts/lat-mcp-wrapper.sh`

- [ ] **Step 1: Verify current wrapper has no PATH setup**

```bash
grep -c 'NVM_DIR\|ISOLATED_NVM_DIR' .nvm-isolated/.claude-isolated/scripts/lat-mcp-wrapper.sh
```
Expected: `0`

- [ ] **Step 2: Replace wrapper content**

Replace the entire file with:

```bash
#!/bin/bash
# lat MCP wrapper — resolves project dir from $LAUNCH_DIR at runtime.
# Installed by inject_lat_mcp() in lib/lat/mcp.sh.
# LAUNCH_DIR and ISOLATED_NVM_DIR are exported by iclaude; Claude Code inherits
# them and passes to MCP subprocess env.

# Set up PATH: source NVM for Node 20+ (lat.md requires RegExp 'v' flag), add npm-global/bin.
# This replaces the env.PATH injection in settings.json — keeps settings.json portable.
if [[ -n "$ISOLATED_NVM_DIR" ]]; then
    export NVM_DIR="$ISOLATED_NVM_DIR/.nvm"
    [[ -s "$NVM_DIR/nvm.sh" ]] && . "$NVM_DIR/nvm.sh"
    export PATH="$ISOLATED_NVM_DIR/npm-global/bin:$PATH"
fi

exec_dir="${LAUNCH_DIR:-$PWD}"
lat_bin="$(dirname "$0")/../../npm-global/bin/lat"
[[ -x "$lat_bin" ]] || lat_bin="$(command -v lat 2>/dev/null)"
cd "$exec_dir" && exec "$lat_bin" mcp "$@"
```

- [ ] **Step 3: Syntax check**

```bash
bash -n .nvm-isolated/.claude-isolated/scripts/lat-mcp-wrapper.sh && echo OK
```
Expected: `OK`

- [ ] **Step 4: Commit**

```bash
git add .nvm-isolated/.claude-isolated/scripts/lat-mcp-wrapper.sh
git commit -m "feat(lat): move NVM/PATH setup from injected env.PATH into wrapper script"
```

---

### Task 4: Update `inject_lat_mcp()` — write literal `$CLAUDE_CONFIG_DIR`, remove env.PATH

**Files:**
- Modify: `lib/lat/mcp.sh` lines 19–46

- [ ] **Step 1: Write test that checks inject output has no abs paths**

```bash
# Create temp settings.json
tmpdir=$(mktemp -d)
cat > "$tmpdir/settings.json" << 'EOF'
{"hooks": {}}
EOF

# Run inject with dummy LAT_BIN
(
  source lib/core/init.sh 2>/dev/null || true
  CLAUDE_CONFIG_DIR="$tmpdir"
  LAT_BIN="$tmpdir/lat"
  touch "$LAT_BIN"
  # Stub inject — source only mcp.sh functions
  source lib/lat/mcp.sh 2>/dev/null
  inject_lat_mcp
)

python3 -c "
import json
s = json.load(open('$tmpdir/settings.json'))
cmd = s['mcpServers']['lat']['command']
assert '/home/' not in cmd, f'Abs path in command: {cmd}'
assert 'env' not in s['mcpServers']['lat'], f'env.PATH still present'
print('PASS: no abs paths in inject output')
"
rm -rf "$tmpdir"
```

Expected at this point: `AssertionError: Abs path in command: /home/...` (test FAILS — confirms problem exists)

- [ ] **Step 2: Edit `lib/lat/mcp.sh` — remove node_bin/node_dir, change Python**

Replace lines 19–46 in `lib/lat/mcp.sh`:

**Before (lines 19–46):**
```bash
    # Resolve isolated node bin dir — lat.md requires Node 20+ (uses RegExp 'v' flag)
    # Pass explicitly so MCP subprocess inherits the right PATH regardless of how Claude Code spawns it.
    local node_bin node_dir lat_wrapper
    node_bin="$(command -v node 2>/dev/null)"
    node_dir="$(dirname "$node_bin" 2>/dev/null)"
    lat_wrapper="${CLAUDE_CONFIG_DIR}/scripts/lat-mcp-wrapper.sh"

    if ! python3 - "$settings_file" "$LAT_BIN" "$lat_wrapper" "${node_dir:-}" << 'PYEOF'
import json, sys, os
settings_path, lat_bin, lat_wrapper, node_dir = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
with open(settings_path) as f:
    s = json.load(f)

# Build explicit PATH for MCP subprocess: isolated node first, then system fallback.
# lat.md requires Node 20+; without this, Claude Code may spawn with system Node 18.
npm_bin_dir = os.path.dirname(lat_bin)
path_parts = [p for p in [node_dir, npm_bin_dir, '/usr/local/bin', '/usr/bin', '/bin'] if p]
mcp_env = {'PATH': ':'.join(dict.fromkeys(path_parts))}  # deduplicate, preserve order

# Use wrapper script instead of lat binary directly.
# Wrapper cd's to $LAUNCH_DIR (inherited from iclaude's env) at spawn time, so lat
# always operates on the current project's lat.md — not the project from last inject.
cmd = lat_wrapper if os.path.isfile(lat_wrapper) else lat_bin
s.setdefault('mcpServers', {})['lat'] = {
    'type': 'stdio',
    'command': cmd,
    'env': mcp_env,
}
```

**After:**
```bash
    if ! python3 - "$settings_file" << 'PYEOF'
import json, sys
settings_path = sys.argv[1]
with open(settings_path) as f:
    s = json.load(f)

# Use literal $CLAUDE_CONFIG_DIR — expanded by Claude Code at spawn time (same as hooks/statusLine).
# Wrapper handles NVM/PATH setup internally, so no env.PATH needed here.
# This keeps settings.json portable across machines and directory moves.
s.setdefault('mcpServers', {})['lat'] = {
    'type': 'stdio',
    'command': '$CLAUDE_CONFIG_DIR/scripts/lat-mcp-wrapper.sh',
}
```

- [ ] **Step 3: Syntax check mcp.sh**

```bash
bash -n lib/lat/mcp.sh && echo OK
```
Expected: `OK`

- [ ] **Step 4: Re-run the test from Step 1 — expect PASS**

```bash
tmpdir=$(mktemp -d)
cat > "$tmpdir/settings.json" << 'EOF'
{"hooks": {}}
EOF

(
  source lib/core/init.sh 2>/dev/null || true
  CLAUDE_CONFIG_DIR="$tmpdir"
  LAT_BIN="$tmpdir/lat"
  touch "$LAT_BIN"
  source lib/lat/mcp.sh 2>/dev/null
  inject_lat_mcp
)

python3 -c "
import json
s = json.load(open('$tmpdir/settings.json'))
cmd = s['mcpServers']['lat']['command']
assert '/home/' not in cmd, f'Abs path in command: {cmd}'
assert 'env' not in s['mcpServers']['lat'], f'env.PATH still present'
print('PASS: no abs paths in inject output')
"
rm -rf "$tmpdir"
```

Expected: `PASS: no abs paths in inject output`

- [ ] **Step 5: Commit**

```bash
git add lib/lat/mcp.sh
git commit -m "fix(lat): write literal \$CLAUDE_CONFIG_DIR in inject_lat_mcp, drop env.PATH"
```

---

### Task 5: Update committed `settings.json` — apply portable value directly

`inject_lat_mcp()` will overwrite the entry on next launch, but we need the committed file to be clean now.

**Files:**
- Modify: `.nvm-isolated/.claude-isolated/settings.json`

- [ ] **Step 1: Verify current mcpServers.lat has abs paths**

```bash
python3 -c "
import json
s = json.load(open('.nvm-isolated/.claude-isolated/settings.json'))
lat = s.get('mcpServers', {}).get('lat', {})
print('command:', lat.get('command'))
print('env:', lat.get('env'))
"
```

Expected: prints `/home/...` in command and PATH

- [ ] **Step 2: Apply portable value with Python**

```bash
python3 - << 'EOF'
import json
path = '.nvm-isolated/.claude-isolated/settings.json'
with open(path) as f:
    s = json.load(f)

s.setdefault('mcpServers', {})['lat'] = {
    'type': 'stdio',
    'command': '$CLAUDE_CONFIG_DIR/scripts/lat-mcp-wrapper.sh',
}

with open(path, 'w') as f:
    json.dump(s, f, indent=2)
    f.write('\n')
print('Done')
EOF
```

Expected: `Done`

- [ ] **Step 3: Verify no abs paths remain**

```bash
python3 -c "
import json
s = json.load(open('.nvm-isolated/.claude-isolated/settings.json'))
lat = s['mcpServers']['lat']
assert '/home/' not in lat.get('command',''), 'abs path in command'
assert 'env' not in lat, 'env still present'
print('PASS')
"
```

Expected: `PASS`

- [ ] **Step 4: Validate full settings.json**

```bash
python3 -m json.tool .nvm-isolated/.claude-isolated/settings.json > /dev/null && echo OK
```

Expected: `OK`

- [ ] **Step 5: Commit**

```bash
git add .nvm-isolated/.claude-isolated/settings.json
git commit -m "fix(settings): replace absolute mcpServers.lat paths with portable \$CLAUDE_CONFIG_DIR"
```

---

### Task 6: Integration test

**No files changed — verification only.**

- [ ] **Step 1: Check no abs paths in any tracked file**

```bash
git diff HEAD~5..HEAD -- \
  .nvm-isolated/.claude-isolated/settings.json \
  .nvm-isolated/.claude-isolated/router.json \
  lib/lat/mcp.sh \
  .nvm-isolated/.claude-isolated/scripts/lat-mcp-wrapper.sh \
  | grep '^\+' | grep '/home/' | grep -v '^+++' || echo "PASS: no abs paths introduced"
```

Expected: `PASS: no abs paths introduced`

- [ ] **Step 2: Launch iclaude and test lat MCP**

```bash
./iclaude.sh
```

In the opened Claude session, run:
```
/lat locate "Problem"
```

Expected: lat responds with a section location (not an MCP connection error).

If lat fails to connect → apply Approach A fallback: edit `lib/lat/mcp.sh` to use:
```python
s.setdefault('mcpServers', {})['lat'] = {
    'type': 'stdio',
    'command': 'bash',
    'args': ['-c', '$CLAUDE_CONFIG_DIR/scripts/lat-mcp-wrapper.sh'],
}
```
Then re-run Task 4 Steps 3–5 and Task 5 Steps 2–5.

- [ ] **Step 3: Test router transformer (if `--router` is in use)**

```bash
./iclaude.sh --router
```

Check CCR startup output — no errors about loading `ollama-reasoning.js`.

If CCR fails to load transformer → `${CLAUDE_CONFIG_DIR}` is not expanded in `transformers.path`. Workaround: add `router.json` to `.gitignore_local` and keep abs path locally.

- [ ] **Step 4: Verify settings.json stays clean on subsequent launches**

After Step 2, close iclaude. Run:

```bash
git status .nvm-isolated/.claude-isolated/settings.json
```

Expected: `nothing to commit` (inject_lat_mcp re-writes the same portable value, no git churn).
