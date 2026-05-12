# isolated_config_dir

> 6 nodes · cohesion 0.33

## Key Concepts

- **ISOLATED_CONFIG_DIR env var** (3 connections) — `lib/core/init.sh`
- **setup_isolated_nvm()** (2 connections) — `lib/nvm/setup.sh`
- **detect_statusline()** (2 connections) — `lib/statusline/detect.sh`
- **download-ohmyposh-binaries.sh** (1 connections) — `scripts/download-ohmyposh-binaries.sh`
- **ssh_exec()** (1 connections) — `tests/test_microvm_workspace.sh`
- **update_isolated_claude()** (1 connections) — `lib/update/isolated.sh`

## Relationships

- No strong cross-community connections detected

## Source Files

- `lib/core/init.sh`
- `lib/nvm/setup.sh`
- `lib/statusline/detect.sh`
- `lib/update/isolated.sh`
- `scripts/download-ohmyposh-binaries.sh`
- `tests/test_microvm_workspace.sh`

## Audit Trail

- EXTRACTED: 6 (60%)
- INFERRED: 4 (40%)
- AMBIGUOUS: 0 (0%)

---

*Part of the graphify knowledge wiki. See [[index]] to navigate.*