# isolated_config_dir

> 11 nodes · cohesion 0.20

## Key Concepts

- **update_claude_code()** (4 connections) — `lib/update/update.sh`
- **ISOLATED_CONFIG_DIR env var** (3 connections) — `lib/core/init.sh`
- **save_isolated_lockfile()** (2 connections) — `lib/lockfile/lockfile.sh`
- **setup_isolated_nvm()** (2 connections) — `lib/nvm/setup.sh`
- **detect_statusline()** (2 connections) — `lib/statusline/detect.sh`
- **cleanup_old_claude_installations()** (2 connections) — `lib/update/cleanup.sh`
- **recreate_claude_symlinks()** (2 connections) — `lib/update/cleanup.sh`
- **update_isolated_claude()** (2 connections) — `lib/update/isolated.sh`
- **detect_nvm()** (1 connections) — `lib/nvm/detect.sh`
- **download-ohmyposh-binaries.sh** (1 connections) — `scripts/download-ohmyposh-binaries.sh`
- **ssh_exec()** (1 connections) — `tests/test_microvm_workspace.sh`

## Relationships

- No strong cross-community connections detected

## Source Files

- `lib/core/init.sh`
- `lib/lockfile/lockfile.sh`
- `lib/nvm/detect.sh`
- `lib/nvm/setup.sh`
- `lib/statusline/detect.sh`
- `lib/update/cleanup.sh`
- `lib/update/isolated.sh`
- `lib/update/update.sh`
- `scripts/download-ohmyposh-binaries.sh`
- `tests/test_microvm_workspace.sh`

## Audit Trail

- EXTRACTED: 16 (73%)
- INFERRED: 6 (27%)
- AMBIGUOUS: 0 (0%)

---

*Part of the graphify knowledge wiki. See [[index]] to navigate.*