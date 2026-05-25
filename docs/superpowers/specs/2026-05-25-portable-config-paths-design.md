---
title: Portable Config Paths Design
state: draft
review:
  spec_hash: d0bdae621ef31a1c
  last_run: "2026-05-25"
  phases:
    structure:    { status: passed }
    coverage:     { status: passed }
    clarity:      { status: passed }
    consistency:  { status: passed }
  findings:
    - id: F-001
      phase: clarity
      severity: WARNING
      section: "Change 1: `router.json` → transformer path"
      section_hash: "326f216cc38eb8e1"
      text: "CCR var expansion in `transformers.path` stated as fact; needs verification step in Verification section"
      verdict: fixed
      verdict_at: "2026-05-25"
    - id: F-002
      phase: clarity
      severity: WARNING
      section: "Change 2: `settings.json` MCP command — write literal `$CLAUDE_CONFIG_DIR`"
      section_hash: "a93e36de8d75713b"
      text: "'expected to behave identically' — ambiguous. Fallback exists but Verification lacks explicit step for the fallback path"
      verdict: fixed
      verdict_at: "2026-05-25"
section_hashes:
  Problem: "0948115bf97460fb"
  "Solution: Lazy Expansion (Approach A)": "5881c98510608882"
  "Change 1: `router.json` → transformer path": "326f216cc38eb8e1"
  "Change 2: `settings.json` MCP command — write literal `$CLAUDE_CONFIG_DIR`": "a93e36de8d75713b"
  "Change 3: `settings.json` MCP env.PATH — remove, move to wrapper": "ea7ad576b0b71ce9"
  "Result in tracked files": "394d8a7714f3dbf8"
  "Files Changed": "123d16f517e5ce2e"
  Verification: "7caa19f1c1037ef6"
  "Not Changed": "9aac0cac629e4ef1"
---

# Portable Config Paths Design

Replace absolute paths in `settings.json` and `router.json` with `$ENV_VAR` references so tracked files are portable across machines and directory moves.

## Problem

Both files are tracked in git. Three absolute paths break on machine change, directory move, or cross-user checkout:

| File | Field | Current value |
|------|-------|---------------|
| `settings.json` | `mcpServers.lat.command` | `/home/.../lat-mcp-wrapper.sh` |
| `settings.json` | `mcpServers.lat.env.PATH` | `/home/.nvm/versions/node/vX.Y.Z/bin:...` |
| `router.json` | `transformers[0].path` | `/home/.../.claude-code-router/plugins/ollama-reasoning.js` |

Root cause: `inject_lat_mcp()` evaluates bash variables before passing them to the Python heredoc → JSON contains resolved strings, not `$VAR` placeholders.

## Solution: Lazy Expansion (Approach A)

Use `$CLAUDE_CONFIG_DIR` and `$ISOLATED_NVM_DIR` as literal strings. Both vars are exported by iclaude before Claude Code / CCR launch, so the respective runtimes inherit them.

### Change 1: `router.json` → transformer path

CCR performs `${VAR}` substitution in its config (already used for API keys). Apply the same to the transformer path.

**Before:**
```json
"transformers": [{ "path": "/home/ikeniborn/.../plugins/ollama-reasoning.js" }]
```

**After:**
```json
"transformers": [{ "path": "${CLAUDE_CONFIG_DIR}/.claude-code-router/plugins/ollama-reasoning.js" }]
```

Also add a `transformers` example block to `router.json.example` showing the pattern.

### Change 2: `settings.json` MCP command — write literal `$CLAUDE_CONFIG_DIR`

`inject_lat_mcp()` currently evaluates `$lat_wrapper` before writing. Change Python code to write the literal string:

```python
# Before (evaluated in bash before heredoc):
cmd = lat_wrapper  # resolves to abs path

# After (write literal env var reference):
cmd = '$CLAUDE_CONFIG_DIR/scripts/lat-mcp-wrapper.sh'
```

Claude Code expands `$VAR` in command fields (confirmed: statusLine and hooks use the same pattern). MCP command field is expected to behave identically.

**Fallback (if MCP command does NOT expand vars):** Change to `bash -c` invocation:
```python
s['mcpServers']['lat'] = {
    'type': 'stdio',
    'command': 'bash',
    'args': ['-c', '$CLAUDE_CONFIG_DIR/scripts/lat-mcp-wrapper.sh'],
}
```
Test: run `./iclaude.sh`, verify lat MCP works. If not, apply fallback.

### Change 3: `settings.json` MCP env.PATH — remove, move to wrapper

The injected PATH contains two absolute parts:
- NVM node bin: `/home/user/.nvm/versions/node/vX.Y.Z/bin` — version-specific, machine-specific
- npm-global/bin: `$ISOLATED_NVM_DIR/npm-global/bin` — project-relative but absolute

Remove `env` from the MCP server entry entirely. Move PATH setup into `lat-mcp-wrapper.sh`:

```bash
# Source NVM to get correct node version
if [[ -n "$ISOLATED_NVM_DIR" ]]; then
    export NVM_DIR="$ISOLATED_NVM_DIR/.nvm"
    [[ -s "$NVM_DIR/nvm.sh" ]] && . "$NVM_DIR/nvm.sh"
fi
# Prepend npm-global/bin for lat binary
[[ -n "$ISOLATED_NVM_DIR" ]] && export PATH="$ISOLATED_NVM_DIR/npm-global/bin:$PATH"
```

`ISOLATED_NVM_DIR` is exported by iclaude → MCP subprocess inherits it.

## Result in tracked files

**`settings.json` mcpServers.lat after change:**
```json
"lat": {
  "type": "stdio",
  "command": "$CLAUDE_CONFIG_DIR/scripts/lat-mcp-wrapper.sh"
}
```

**`router.json` transformers after change:**
```json
"transformers": [
  { "path": "${CLAUDE_CONFIG_DIR}/.claude-code-router/plugins/ollama-reasoning.js" }
]
```

No machine-specific strings remain in tracked files.

## Files Changed

| File | Change |
|------|--------|
| `lib/lat/mcp.sh` | Write literal `$CLAUDE_CONFIG_DIR` string; remove env.PATH injection |
| `scripts/lat-mcp-wrapper.sh` | Add NVM source + PATH setup at top |
| `.nvm-isolated/.claude-isolated/settings.json` | Updated by inject on next launch |
| `.nvm-isolated/.claude-isolated/router.json` | Replace abs path with `${CLAUDE_CONFIG_DIR}/...` |
| `.nvm-isolated/.claude-isolated/router.json.example` | Add transformers example block |

## Verification

1. `git diff` after change → no abs paths in tracked files
2. Launch `./iclaude.sh` → lat MCP connects (run `/lat locate` in Claude)
   - If lat MCP fails to connect: apply fallback (`command: bash`, `args: ["-c", "$CLAUDE_CONFIG_DIR/scripts/lat-mcp-wrapper.sh"]`), relaunch, retest
3. Router with transformer: launch with `./iclaude.sh --router`, check CCR startup log → no errors loading `ollama-reasoning.js` (confirms `${VAR}` expansion works in `transformers.path`)
   - If CCR fails to load transformer: file bug against CCR; workaround — use absolute path in router.json and add to .gitignore_local
4. Simulate directory move: rename iclaude dir, launch → no broken paths

## Not Changed

- Hooks in `settings.json` — already use `$CLAUDE_CONFIG_DIR` correctly
- `statusLine.command` — already correct
- Provider API key expansion in `router.json` — already uses `${VAR}`
