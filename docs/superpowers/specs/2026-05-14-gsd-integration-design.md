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
    # Use glob expansion with nullglob-safe check (ls -d fails on empty glob)
    local skills_dir="${CLAUDE_CONFIG_DIR}/skills"
    [[ -d "$skills_dir" ]] || return 1
    local found
    found=$(find "$skills_dir" -maxdepth 1 -type d -name 'gsd-*' 2>/dev/null | head -1)
    [[ -n "$found" ]]
}
```

**`install.sh`** — install and update:

`install_gsd([--force])`:
1. Check `$ISOLATED_NVM_DIR` exists (pre-condition)
2. Run GSD installer with isolated config dir:
   ```bash
   CLAUDE_CONFIG_DIR="$CLAUDE_CONFIG_DIR" npx get-shit-done-cc@latest --global
   ```
3. Call `save_isolated_lockfile()` to pin the installed version

`update_gsd_if_installed()`:
- If `detect_gsd` returns non-zero: print info, return 0 (skip silently)
- If installed: call `install_gsd()` (GSD installer is idempotent, updates to latest)

**`status.sh`** — report status for `--check-gsd` and `--check-isolated`:

`check_gsd_status()`:
- Print whether GSD is installed
- If installed: print version and list of installed skill directories

### Source Loading in `iclaude.sh`

Added to Phase 7.x (after graphify sources), before command dispatch:
```bash
source "$LIB_DIR/gsd/detect.sh"
source "$LIB_DIR/gsd/install.sh"
source "$LIB_DIR/gsd/status.sh"
```

---

## CLI Flags

Two new flags in `iclaude.sh` command dispatch (after `--install-graphify` block):

```
--install-gsd [--force]
```
- Blocked with `--system` (GSD only in isolated env)
- Sources credentials if present
- Calls `install_gsd [--force]`
- Exits with install return code

```
--check-gsd
```
- Calls `check_gsd_status`
- Exits 0

---

## Lockfile Integration

### Version Detection

`save_isolated_lockfile()` in `lib/lockfile/save.sh` gains a GSD version detection block:

```bash
local gsd_version="not installed"
if detect_gsd &>/dev/null; then
    # GSD v2 is a standalone CLI: query version via npx
    gsd_version=$(CLAUDE_CONFIG_DIR="$CLAUDE_CONFIG_DIR" \
        npx get-shit-done-cc --version 2>/dev/null \
        | grep -oP '\d+\.\d+\.\d+' | head -1 || echo "unknown")
fi
```

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
        npx "get-shit-done-cc@$gsd_version" --global \
        || print_warning "GSD install failed (non-critical)"
fi
```

Failure is non-critical (same pattern as router in `install_from_lockfile`).

---

## Auto-Update via `--update`

`update_isolated_claude()` in `lib/update/isolated.sh` gains a GSD update call after the npm install succeeds, before `save_isolated_lockfile()`:

```bash
# Update GSD if installed
if declare -f update_gsd_if_installed &>/dev/null; then
    update_gsd_if_installed
fi
```

This mirrors the existing `repair_vendor_permissions` guard pattern.

---

## `--check-isolated` Integration

`check_gsd_status` is called as part of the existing `--check-isolated` output section (same pattern as graphify status check). Adds one line to the status report.

---

## Error Handling

| Scenario | Behavior |
|----------|----------|
| `--install-gsd` with `--system` | `print_error` + exit 1 |
| `ISOLATED_NVM_DIR` not found | `print_error` + return 1 |
| `npx` fails during install | `print_error` + return 1 |
| GSD update fails during `--update` | `print_warning`, continue |
| GSD install fails during `install_from_lockfile` | `print_warning`, continue |
| `gsdVersion` absent in lockfile | Treat as `"not installed"`, skip |

---

## Files Changed

| File | Change |
|------|--------|
| `lib/gsd/detect.sh` | **new** — `detect_gsd()` |
| `lib/gsd/install.sh` | **new** — `install_gsd()`, `update_gsd_if_installed()` |
| `lib/gsd/status.sh` | **new** — `check_gsd_status()` |
| `iclaude.sh` | source lib/gsd/*, add `--install-gsd`, `--check-gsd` flags |
| `lib/update/isolated.sh` | call `update_gsd_if_installed()` in `update_isolated_claude()` |
| `lib/lockfile/save.sh` | detect GSD version, add `gsdVersion` to JSON |
| `lib/lockfile/install.sh` | install GSD from lockfile if `gsdVersion` present |
| `CLAUDE.md` | add GSD to features table and commands section |

Total: 3 new files, 5 modified files.

---

## Open Questions

1. **npx version pinning**: `npx get-shit-done-cc@1.40.0 --global` — verify GSD installer accepts `@version` syntax (GSD npm package name is `get-shit-done-cc`).
2. **Version detection**: `npx get-shit-done-cc --version` needs confirmation once installed. May need to read version from skill manifest or package.json instead.
3. **Proxy support**: GSD installer uses npm/npx which inherits `HTTP_PROXY`/`HTTPS_PROXY` from environment. No special proxy handling needed (npx respects env vars). Verify with `--test`.

---

## Out of Scope

- Tracking GSD skills in git (like superpowers) — GSD files change with each update; tracking adds noise
- GSD auto-launch flag (e.g. `--gsd`) — GSD is used inside Claude Code sessions, not at launch time
- GitHub Actions auto-update for GSD — separate concern, not part of this integration
