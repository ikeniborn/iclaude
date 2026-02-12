# Phase 9.5: Update Module - Summary

**Date:** 2026-02-12
**Branch:** `refactor/phase-9.5-update-module`
**Status:** ✅ COMPLETE

---

## Overview

Phase 9.5 extracted Update functionality from `iclaude-legacy.sh` into dedicated modules. Update module provides functions for updating Claude Code in isolated and system environments, with cleanup and symlink management.

**Scope:**
- 4 functions extracted
- 3 modules created
- ~550 lines modularized
- Zero breaking changes

---

## Modules Created

### 1. lib/update/isolated.sh (101 lines)

**Purpose:** Update Claude Code in isolated NVM environment

**Functions:**
- `update_isolated_claude()` - Update Claude Code via npm in isolated environment

**Update Workflow:**
1. Setup isolated NVM environment
2. Source nvm.sh
3. Verify Node.js and npm availability
4. Get current Claude Code version
5. Run `npm update -g @anthropic-ai/claude-code`
6. Clear bash command hash cache
7. Get new version
8. Update lockfile with new version
9. Show version comparison

**Error Handling:**
- Missing NVM environment
- Missing Node.js/npm
- Claude Code not found
- npm update failure

**Dependencies:**
- `lib/nvm/setup.sh` (setup_isolated_nvm)
- `lib/lockfile/save.sh` (save_isolated_lockfile)
- `lib/core/logging.sh` (print_info/success/error/warning)

### 2. lib/update/cleanup.sh (232 lines)

**Purpose:** Cleanup old Claude installations and recreate symlinks

**Functions:**
- `cleanup_old_claude_installations()` - Remove temporary .claude-code-* folders
- `recreate_claude_symlinks()` - Recreate claude symlink after update

**cleanup_old_claude_installations() Workflow:**
1. Check if NVM environment
2. Find temporary .claude-code-* folders
3. Separate old (>7 days) and recent folders
4. Auto-remove old folders without confirmation
5. Ask confirmation for recent folders
6. Find and remove broken symlinks in bin/
7. Remove incomplete installations (without cli.js)

**Age-Based Cleanup:**
- **Old folders (>7 days):** Auto-remove (no confirmation)
- **Recent folders (<7 days):** Ask for confirmation
- **Broken symlinks:** Ask for confirmation
- **Incomplete installations:** Ask for confirmation

**recreate_claude_symlinks() Workflow:**
1. Check if NVM environment
2. Find actual cli.js (prioritize standard installation)
3. If not found, find newest temporary installation
4. Remove all old Claude symlinks
5. Create new standard symlink: `claude -> cli.js`
6. Set executable permissions
7. Show version of symlink target

**Symlink Priority:**
1. Standard installation: `claude-code/cli.js`
2. Newest temporary: `.claude-code-*/cli.js` (sorted by mtime)

**Dependencies:**
- `lib/nvm/detect.sh` (get_cli_version)
- `lib/core/logging.sh` (print_info/success/warning/error)

### 3. lib/update/update.sh (238 lines)

**Purpose:** Universal update function for system and NVM installations

**Functions:**
- `update_claude_code()` - Update Claude Code (system or NVM)

**Update Workflow:**
1. Detect environment (system or NVM)
2. Check isolated environment (source nvm.sh if needed)
3. Verify sudo privileges (system only)
4. Warn if using sudo with NVM
5. Get current and latest versions
6. Check if already up to date
7. Confirm update with user
8. Pre-update cleanup (NVM only):
   - Remove ALL symlinks (avoid EEXIST errors)
   - Remove ALL .claude-code-* folders (avoid ENOTEMPTY errors)
   - Remove incomplete installations
9. Install update via `npm install -g @anthropic-ai/claude-code@latest`
10. Clear bash command hash cache
11. Verify installation success
12. Post-update actions:
    - **Isolated:** Repair environment + update lockfile
    - **System NVM:** Cleanup + recreate symlinks
13. Check if version actually updated

**Environment Detection:**
- **System installation:** Requires sudo
- **NVM installation:** No sudo (will update wrong installation)
- **Isolated NVM:** Automatic lockfile update

**Pre-Update Cleanup (NVM only):**
- Prevents EEXIST errors (symlink already exists)
- Prevents ENOTEMPTY errors (folder not empty)
- Removes incomplete installations

**Dependencies:**
- `lib/nvm/detect.sh` (detect_nvm, get_claude_version)
- `lib/nvm/repair.sh` (repair_isolated_environment)
- `lib/lockfile/save.sh` (save_isolated_lockfile)
- `lib/update/cleanup.sh` (cleanup_old_claude_installations, recreate_claude_symlinks)
- `lib/core/logging.sh` (print_info/success/error/warning)

---

## Functions Extracted from iclaude-legacy.sh

| Function | Lines (Before) | Module | Purpose |
|----------|---------------|--------|---------|
| `update_isolated_claude()` | 1632-1711 | isolated.sh | Update Claude Code in isolated environment |
| `cleanup_old_claude_installations()` | 5677-5810 | cleanup.sh | Remove temporary installations and broken symlinks |
| `recreate_claude_symlinks()` | 5816-5871 | cleanup.sh | Recreate claude symlink after update |
| `update_claude_code()` | 5878-6109 | update.sh | Universal update function (system + NVM) |

---

## Guards Added to iclaude-legacy.sh

All 4 functions protected with guards (2 already existed, 2 new):

```bash
if ! declare -F update_claude_code &>/dev/null; then
update_claude_code() {
    # ... legacy implementation ...
}
fi  # End guard for update_claude_code
```

**Guard Locations:**
- Line 1632: `update_isolated_claude()` guard (pre-existing)
- Line 5677: `cleanup_old_claude_installations()` guard (pre-existing)
- Line 5816: `recreate_claude_symlinks()` guard (**NEW**)
- Line 5878: `update_claude_code()` guard (**NEW**)

---

## iclaude.sh Updates

**Version bump:** 2.9 → **3.0** (Major milestone!)

**Added module loading section:**
```bash
#######################################
# Load Update modules (Phase 9.5)
#######################################
if [[ -d "$LIB_DIR/update" ]]; then
    source "${LIB_DIR}/update/isolated.sh"
    source "${LIB_DIR}/update/cleanup.sh"
    source "${LIB_DIR}/update/update.sh"
fi
```

**Loading order:**
1. Core modules (Phase 0)
2. Proxy modules (Phase 2)
3. NVM modules (Phase 3)
4. Lockfile modules (Phase 4)
5. Config modules (Phase 5)
6. OAuth modules (Phase 6)
7. Router modules (Phase 7)
8. LSP modules (Phase 8.1)
9. Statusline modules (Phase 8.2)
10. Oh-My-Posh modules (Phase 8.3)
11. Sandbox modules (Phase 9.1)
12. GH CLI modules (Phase 9.2)
13. **Update modules (Phase 9.5)** ← NEW
14. Legacy implementation

---

## Testing Results

### Function Priority Test

Created `/tmp/test_update_guards.sh` to verify module functions take priority over legacy:

```
=== Testing Update module function priority ===

After loading Update modules:
update_isolated_claude 12 /path/to/lib/update/isolated.sh
cleanup_old_claude_installations 11 /path/to/lib/update/cleanup.sh
recreate_claude_symlinks 153 /path/to/lib/update/cleanup.sh
update_claude_code 14 /path/to/lib/update/update.sh

Loading legacy...

After loading legacy:
update_isolated_claude 12 /path/to/lib/update/isolated.sh
cleanup_old_claude_installations 11 /path/to/lib/update/cleanup.sh
recreate_claude_symlinks 153 /path/to/lib/update/cleanup.sh
update_claude_code 14 /path/to/lib/update/update.sh

Result: 4/4 functions from modules
✓ ALL GUARDS WORKING!
```

**Result:** ✅ All update functions load from modules, not legacy

### Command Tests

**--update:** ✅ Updates Claude Code via module functions
**Syntax validation:** ✅ `bash -n iclaude-legacy.sh` passes

---

## Metrics

**Lines Extracted:**
- isolated.sh: 101 lines
- cleanup.sh: 232 lines
- update.sh: 238 lines
- **Total:** 571 lines

**Cumulative Progress:**
- **Phases 0-9.5 complete:** 40 modules, 81 functions, ~5,728 lines (69.9%)
- **Remaining:** 8 modules, 35 functions, ~2,467 lines (30.1%)

**Phase 9.5 Specific:**
- Modules created: 3
- Functions extracted: 4
- Lines modularized: ~571
- Guards added: 2 (2 pre-existing)
- Breaking changes: 0

---

## Update Integration Notes

**Purpose:**
- Update Claude Code to latest version
- Cleanup old installations
- Maintain lockfile consistency
- Handle both isolated and system environments

**Update Methods:**
1. **Isolated environment:** `./iclaude.sh --update`
2. **System installation:** `sudo ./iclaude.sh --update`

**Pre-Update Cleanup (NVM only):**
- Removes ALL symlinks (prevent EEXIST errors)
- Removes ALL .claude-code-* folders (prevent ENOTEMPTY errors)
- Removes incomplete installations

**Post-Update Actions:**
- **Isolated:** Repair symlinks + update lockfile
- **System NVM:** Cleanup old installations + recreate symlinks

**Temporary Installation Folders:**
- npm creates `.claude-code-<hash>` folders during update
- These should be removed after successful update
- Auto-cleanup for folders >7 days old

**Common Update Errors:**
- **EEXIST:** Symlink already exists (fixed by pre-update cleanup)
- **ENOTEMPTY:** Folder not empty (fixed by pre-update cleanup)
- **Version mismatch:** Shell using cached version (run `hash -r`)

**Lockfile Tracking:**
- `claudeCodeVersion`: Updated automatically after isolated environment update
- Used by `--install-from-lockfile` for reproducibility

---

## Common Use Cases

**Update isolated environment:**
```bash
./iclaude.sh --update
```

**Update system installation:**
```bash
sudo ./iclaude.sh --update
```

**Cleanup old installations:**
```bash
# Triggered automatically during update, or manually:
# (cleanup_old_claude_installations function not exposed as CLI command)
```

**Check if update needed:**
```bash
./iclaude.sh --check-isolated
# Shows current version vs latest
```

---

## Files Changed

**Created:**
- `lib/update/isolated.sh`
- `lib/update/cleanup.sh`
- `lib/update/update.sh`
- `docs/phase9.5-summary.md`

**Modified:**
- `iclaude.sh` (version 2.9 → 3.0, added update module loading)
- `iclaude-legacy.sh` (added 2 new function guards)

---

## Dependencies

**Update modules depend on:**
- `lib/core/init.sh` - ISOLATED_NVM_DIR constant
- `lib/core/logging.sh` - print_info, print_success, print_error, print_warning
- `lib/nvm/setup.sh` - setup_isolated_nvm()
- `lib/nvm/detect.sh` - detect_nvm(), get_claude_version(), get_cli_version()
- `lib/nvm/repair.sh` - repair_isolated_environment()
- `lib/lockfile/save.sh` - save_isolated_lockfile()

**External dependencies:**
- npm (for updating packages)
- Node.js (for running cli.js)

---

## Known Limitations

**System Installation:**
- Requires sudo privileges
- Cannot update isolated environment as root

**NVM Detection:**
- Warns if using sudo with NVM installation
- Auto-detects isolated vs system NVM

**Temporary Installations:**
- npm may create .claude-code-* folders during update
- Requires manual cleanup if update fails mid-process
- Auto-cleanup for folders >7 days old

**Version Detection:**
- May show stale version if bash command cache not cleared
- Run `hash -r` to clear cache

---

## Next Steps

**Phase 9 Continues:**
1. **Phase 9.6: Launcher Module** (3 functions, ~400 lines) ⭐⭐⭐ HIGH ← **ФИНАЛЬНАЯ ФАЗА перед удалением legacy**
2. Phase 9.3: Loop Mode (11 functions, ~400 lines) ⭐ LOW (optional)
3. Phase 9.4: Context (21 functions, ~600 lines) ⭐ LOW (optional)

**Immediate Next:** Phase 9.6 - Launcher Module (FINAL high-priority phase!)

---

## Verification Checklist

- [x] All 4 update functions extracted to modules
- [x] Guards added to iclaude-legacy.sh (2 new, 2 pre-existing)
- [x] iclaude.sh updated to load update modules
- [x] Version bumped (2.9 → 3.0) - Major milestone!
- [x] Function priority test passes (4/4 from modules)
- [x] --update works correctly
- [x] Syntax validation passes (bash -n)
- [x] Zero breaking changes confirmed
- [x] Documentation created (phase9.5-summary.md)

---

## Success Criteria

✅ **Functional:** All update commands work identically
✅ **Modular:** Update functions isolated in lib/update/
✅ **Guarded:** Module functions take priority over legacy
✅ **Tested:** Function priority test passes (4/4)
✅ **Documented:** This summary covers all changes
✅ **Backward Compatible:** Zero breaking changes

---

**Phase 9.5 Status:** ✅ COMPLETE
**Next Phase:** Phase 9.6 - Launcher Module (FINAL high-priority phase!)

**Total Progress:** 69.9% → 100% (40/48 modules complete)

**Major Milestone:** 🎉 Reached version 3.0 and nearly 70% complete!
