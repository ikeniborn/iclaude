# Design: lat hooks portable + lat-check/lat-search skills

**Date:** 2026-05-25
**Status:** approved
**Intent:** [2026-05-25-lat-hooks-portable-skills-intent.md](../intents/2026-05-25-lat-hooks-portable-skills-intent.md)

## Problem

Three places embed absolute paths to the lat binary:

1. `settings.json` hook commands — `inject_lat_mcp()` writes `$LAT_BIN` (absolute) at inject time
2. `.git/hooks/pre-commit` in each project — `install_lat_precommit()` writes `${LAT_BIN}` (absolute)
3. `scripts/lat-mcp-wrapper.sh` — relative path uses `../../../` (3 levels) instead of `../..` (2 levels); binary is never found, always falls through to `command -v lat` which is not on PATH

Additionally, no skills exist for `lat check` / `lat search`, so Claude invokes raw bash `lat` which is not on PATH in other projects.

## Solution

### 1. `scripts/lat-runner.sh` — universal binary resolver

New script at `.nvm-isolated/.claude-isolated/scripts/lat-runner.sh`. Single resolution point for all callers.

Resolution order:
1. `$NPM_CONFIG_PREFIX/bin/lat` — exported by iclaude, inherited by hooks and Claude subprocesses
2. `<script-dir>/../../npm-global/bin/lat` — relative fallback for contexts where NPM_CONFIG_PREFIX is absent
3. `command -v lat` — system PATH last resort

All hook commands and pre-commit use this script or the same resolution logic.

### 2. Fix `scripts/lat-mcp-wrapper.sh`

Change relative path: `../../../npm-global/bin/lat` → `../../npm-global/bin/lat`.

### 3. `lib/lat/mcp.sh` — `inject_lat_mcp()`

Hook commands change from:
```
"/absolute/path/to/lat" hook claude UserPromptSubmit
```
to:
```
"${CLAUDE_CONFIG_DIR}/scripts/lat-runner.sh" hook claude UserPromptSubmit
```

`$CLAUDE_CONFIG_DIR` is always set by iclaude before Claude Code launches — available in all hook subprocesses. No absolute paths in `settings.json`.

Re-inject happens automatically on next `./iclaude.sh` launch — fixes existing `settings.json`.

### 4. `lib/lat/check.sh` — `install_lat_precommit()`

Pre-commit hook block changes from hardcoded `"${LAT_BIN}"` to portable resolution:

```bash
_lat="${NPM_CONFIG_PREFIX:+${NPM_CONFIG_PREFIX}/bin/lat}"
[[ -x "$_lat" ]] || _lat="$(command -v lat 2>/dev/null)"
[[ -x "$_lat" ]] && "$_lat" check || true
```

Works in both iclaude context (NPM_CONFIG_PREFIX set) and bare git commit context (falls back to command -v).

### 5. New skill: `skills/lat-check/SKILL.md`

Tells Claude how to run `lat check` portably:
- Find binary via `${CLAUDE_CONFIG_DIR}/scripts/lat-runner.sh` or `${NPM_CONFIG_PREFIX}/bin/lat`
- Run from project directory (not iclaude dir)
- Report broken refs; exit 0 = OK, exit 1 = broken links

### 6. New skill: `skills/lat-search/SKILL.md`

Tells Claude how to run lat search/section/refs/locate portably:
- Same binary resolution as lat-check
- Commands: `lat search "<query>"`, `lat section <ref>`, `lat refs <ref>`, `lat locate <name>`
- If `LAT_LLM_KEY` not set: inform user, offer `lat locate` as alternative (no key needed)
- Run from project directory

### 7. Update dependent skills and docs (Guarded — diff shown before apply)

| File | Change |
|------|--------|
| `skills/lat-md/SKILL.md` | 4× `lat check` → "invoke lat-check skill" |
| `commands/update-docs.md` | Phase 2 `Bash(lat check)` → `Skill(lat-check)` |
| `CLAUDE.md` (project) | Post-task checklist `lat check` → `Skill(lat-check)` |
| `CLAUDE.md` (project) | "Before starting work" `lat search` → `Skill(lat-search)` |

**Not changed:**
- `skills/idd/SKILL.md` — uses `lat_search` MCP tool correctly
- CLAUDE.md code-block CLI reference — documentation, not instructions

## Architecture Diagram

```
iclaude.sh
  └── exports: CLAUDE_CONFIG_DIR, NPM_CONFIG_PREFIX, LAUNCH_DIR
        └── Claude Code inherits env
              ├── hooks (UserPromptSubmit, Stop)
              │     └── ${CLAUDE_CONFIG_DIR}/scripts/lat-runner.sh hook claude ...
              │           └── resolves: $NPM_CONFIG_PREFIX/bin/lat
              ├── MCP server: lat
              │     └── ${CLAUDE_CONFIG_DIR}/scripts/lat-mcp-wrapper.sh (fixed: ../../)
              │           └── resolves: $NPM_CONFIG_PREFIX/bin/lat
              └── Claude reads skills/lat-check, skills/lat-search
                    └── Bash: ${CLAUDE_CONFIG_DIR}/scripts/lat-runner.sh check|search ...
```

```
.git/hooks/pre-commit (per project)
  └── _lat="${NPM_CONFIG_PREFIX:+${NPM_CONFIG_PREFIX}/bin/lat}"
        || command -v lat
        → "$_lat" check
```

## Invariants

- `settings.json` never contains absolute paths to lat binary
- `lat-runner.sh` is the single source of truth for binary resolution
- Skills `lat-check` / `lat-search` work in any project launched via iclaude
- Pre-commit hook works both inside and outside iclaude context
- MCP server continues to work (fixes existing bug as side-effect)

## Files Changed

- `scripts/lat-runner.sh` — new
- `scripts/lat-mcp-wrapper.sh` — fix relative path
- `lib/lat/mcp.sh` — hook commands use lat-runner.sh
- `lib/lat/check.sh` — pre-commit uses portable resolution
- `skills/lat-check/SKILL.md` — new
- `skills/lat-search/SKILL.md` — new
- `skills/lat-md/SKILL.md` — update lat check refs
- `commands/update-docs.md` — update lat check call
- `CLAUDE.md` — update post-task checklist and before-work instructions
