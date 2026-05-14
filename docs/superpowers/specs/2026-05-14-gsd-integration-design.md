# GSD Framework Integration Design

**Date:** 2026-05-14  
**Status:** Draft  
**Scope:** Add `--install-gsd` optional command to iclaude with lockfile pinning and auto-update via `--update`

---

## Overview

[GSD (Get Shit Done)](https://github.com/gsd-build/get-shit-done) is a meta-prompting, context engineering, and spec-driven development framework for Claude Code (53K+ stars). It solves context window degradation by breaking projects into atomic task plans executed in fresh subagent contexts.

**Key constraint:** iclaude uses `CLAUDE_CONFIG_DIR` isolation — all Claude Code config lives in `.nvm-isolated/.claude-isolated/` instead of `~/.claude/`. GSD respects `CLAUDE_CONFIG_DIR` at install time, making integration straightforward.

---

## Architecture

### New Module: `lib/gsd/`

Three files, identical pattern to `lib/graphify/`:

```
lib/gsd/
  detect.sh    # detect_gsd()
  install.sh   # install_gsd(), update_gsd_if_installed()
  status.sh    # check_gsd_status()
```

### Module Responsibilities

**`detect.sh`** — check if GSD is installed:
```bash
detect_gsd() {
    # GSD installs skills to ${CLAUDE_CONFIG_DIR}/skills/gsd-*/
    # Use find instead of ls glob (nullglob-safe)
    local skills_dir="${CLAUDE_CONFIG_DIR}/skills"
    [[ -d "$skills_dir" ]] || return 1
    local found
    found=$(find "$skills_dir" -maxdepth 1 -type d -name 'gsd-*' 2>/dev/null | head -1)
    [[ -n "$found" ]]
}
```

**`install.sh`** — install and update:

`install_gsd([--force])`:
1. Check `$ISOLATED_NVM_DIR` exists (pre-condition: print_error + return 1 if not)
2. Call `setup_isolated_nvm` to ensure PATH includes isolated npm/npx
3. If `--force`: remove all `${CLAUDE_CONFIG_DIR}/skills/gsd-*` dirs and the `.gsd-version` marker
4. Run GSD installer with isolated config dir:
   ```bash
   CLAUDE_CONFIG_DIR="$CLAUDE_CONFIG_DIR" npx get-shit-done-cc@latest --global
   ```
5. Write installed version to marker file:
   ```bash
   # npm cache is warm after the preceding npx install; a separate network round-trip
   # is usually avoided, but not guaranteed if cache is expired or the registry is slow.
   local ver
   ver=$(npm view get-shit-done-cc version 2>/dev/null || echo "unknown")
   echo "$ver" > "${CLAUDE_CONFIG_DIR}/.gsd-version"
   ```
6. Print next steps (does NOT call `save_isolated_lockfile` — caller's responsibility)

`update_gsd_if_installed()`:
- If `detect_gsd` returns non-zero: `print_info "GSD not installed, skipping update"` + return 0
- If installed: call `install_gsd` (idempotent, no `--force`; updates to latest, rewrites `.gsd-version`)

**`status.sh`** — report status for `--check-gsd`:

`check_gsd_status()`:
- Print GSD installed/not-installed
- If installed: print version from `${CLAUDE_CONFIG_DIR}/.gsd-version`, list `skills/gsd-*` dirs

### Source Loading in `iclaude.sh`

Added as **Phase 8.5** (after Caveman §8.4, before Sandbox §9.1):
```bash
#######################################
# Load GSD modules (Phase 8.5)
#######################################
if [[ -d "$LIB_DIR/gsd" ]]; then
    source "${LIB_DIR}/gsd/detect.sh"
    source "${LIB_DIR}/gsd/install.sh"
    source "${LIB_DIR}/gsd/status.sh"
fi
```

---

## CLI Flags

Two new flags in `iclaude.sh` command dispatch (after `--install-graphify` / `--check-graphify` block):

```
--install-gsd [--force]
```
- Blocked with `--system` (GSD only in isolated env)
- Sources credentials if present (`[[ -f "$CREDENTIALS_FILE" ]] && source "$CREDENTIALS_FILE"`)
- Calls `install_gsd [--force]`
- On success: calls `save_isolated_lockfile` to persist `gsdVersion`
- Exits with return code

```
--check-gsd
```
- Calls `check_gsd_status`
- Exits 0

**Note:** `--check-gsd` is a standalone flag only. It is NOT integrated into `--check-isolated` (which delegates to `check_isolated_status()` in `lib/config/status.sh` — a separate function that does not call `check_gsd_status`). Same pattern as `--check-graphify` vs `--check-isolated`.

---

## Lockfile Integration

### Version Detection

`save_isolated_lockfile()` in `lib/lockfile/save.sh` reads GSD version from the marker file written during install:

```bash
local gsd_version="not installed"
if detect_gsd &>/dev/null; then
    local marker="${CLAUDE_CONFIG_DIR}/.gsd-version"
    if [[ -f "$marker" ]]; then
        gsd_version=$(cat "$marker" 2>/dev/null | tr -d '[:space:]' || echo "unknown")
    else
        # Marker absent (manual install): fall back to npm registry query
        gsd_version=$(npm view get-shit-done-cc version 2>/dev/null | tr -d '[:space:]' || echo "unknown")
    fi
fi
```

Reading from `.gsd-version` is offline and instant. `npm view` fallback requires network but only triggers when marker is absent (manual/pre-integration installs).

### Schema Change

One new key added to the lockfile JSON (via jq `--arg`):
```json
{
  "gsdVersion": "1.40.0"
}
```
Value is `"not installed"` if GSD was not installed at save time.

### Install from Lockfile

`install_from_lockfile()` in `lib/lockfile/install.sh` gains a GSD section after router install:

```bash
local gsd_version
gsd_version=$(jq -r '.gsdVersion // "not installed"' "$ISOLATED_LOCKFILE" 2>/dev/null || echo "not installed")

if [[ "$gsd_version" != "not installed" ]] && [[ "$gsd_version" != "unknown" ]]; then
    print_info "Installing GSD version: $gsd_version"
    CLAUDE_CONFIG_DIR="$CLAUDE_CONFIG_DIR" \
        npx get-shit-done-cc@"$gsd_version" --global \
        && echo "$gsd_version" > "${CLAUDE_CONFIG_DIR}/.gsd-version" \
        || print_warning "GSD install failed (non-critical)"
fi
```

`npx package@version` is standard npm syntax — confirmed supported.

Failure is non-critical (same pattern as router in `install_from_lockfile`).

---

## Auto-Update via `--update`

`update_isolated_claude()` in `lib/update/isolated.sh` gains a GSD update call after npm install succeeds, before `save_isolated_lockfile()`:

```bash
# Update GSD if installed
if declare -f update_gsd_if_installed &>/dev/null; then
    update_gsd_if_installed
fi
```

`update_gsd_if_installed()` calls `install_gsd()` which does NOT call `save_isolated_lockfile()`. The single call to `save_isolated_lockfile()` at the end of `update_isolated_claude()` captures the updated `gsdVersion` from the `.gsd-version` marker. No double-save.

This mirrors the existing `repair_vendor_permissions` guard pattern.

---

## Error Handling

| Scenario | Behavior |
|----------|----------|
| `--install-gsd` with `--system` | `print_error` + exit 1 |
| `ISOLATED_NVM_DIR` not found | `print_error` + return 1 |
| `npx` fails during install | `print_error` + return 1 |
| GSD update fails during `--update` | `print_warning`, continue (non-critical) |
| GSD install fails during `install_from_lockfile` | `print_warning`, continue (non-critical) |
| `gsdVersion` absent in lockfile | Treat as `"not installed"`, skip |
| `.gsd-version` marker absent after install | Falls back to `npm view` query |

---

## Proxy Support

GSD installer runs via `npx`, which inherits `HTTP_PROXY` / `HTTPS_PROXY` from the environment. iclaude exports these before running npm commands. No special proxy handling needed in `lib/gsd/` — same behaviour as the LSP module.

---

## Files Changed

| File | Change |
|------|--------|
| `lib/gsd/detect.sh` | **new** — `detect_gsd()` |
| `lib/gsd/install.sh` | **new** — `install_gsd()`, `update_gsd_if_installed()` |
| `lib/gsd/status.sh` | **new** — `check_gsd_status()` |
| `iclaude.sh` | Phase 8.5 source block; `--install-gsd`, `--check-gsd` flags |
| `lib/update/isolated.sh` | call `update_gsd_if_installed()` in `update_isolated_claude()` |
| `lib/lockfile/save.sh` | detect GSD version via marker, add `gsdVersion` to JSON |
| `lib/lockfile/install.sh` | install GSD from lockfile if `gsdVersion` present |
| `CLAUDE.md` | add GSD to features table and commands section |

Total: 3 new files, 5 modified files.

---

## Out of Scope

- Tracking GSD skills in git (like superpowers) — GSD files change with each update; tracking adds noise
- GSD auto-launch flag (e.g. `--gsd`) — GSD is used inside Claude Code sessions, not at launch time
- GitHub Actions auto-update for GSD — separate concern, not part of this integration
- `--check-isolated` integration — `check_gsd_status` is a standalone `--check-gsd` flag only
