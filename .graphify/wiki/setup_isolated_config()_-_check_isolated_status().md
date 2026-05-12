# setup_isolated_config() / check_isolated_status()

> 21 nodes · cohesion 0.10

## Key Concepts

- **ISOLATED_NVM_DIR** (13 connections) — `lib/core/init.sh`
- **_create_microvm_nvm_image()** (3 connections) — `lib/sandbox/install.sh`
- **setup_isolated_config()** (2 connections) — `lib/config/isolated.sh`
- **check_isolated_status()** (2 connections) — `lib/config/status.sh`
- **detect_ohmyposh_platform()** (2 connections) — `lib/ohmyposh/detect.sh`
- **get_ohmyposh_path()** (2 connections) — `lib/ohmyposh/detect.sh`
- **check_ohmyposh_status()** (2 connections) — `lib/ohmyposh/status.sh`
- **get_claude_version()** (2 connections) — `lib/core/remaining.sh`
- **detect_router()** (2 connections) — `lib/router/detect.sh`
- **get_router_path()** (2 connections) — `lib/router/detect.sh`
- **show_native_installer_info()** (1 connections) — `lib/config/status.sh`
- **CLAUDE_CONFIG_DIR** (1 connections) — `lib/core/init.sh`
- **install_isolated_lsp_servers()** (1 connections) — `lib/lsp/install.sh`
- **repair_plugin_paths()** (1 connections) — `lib/lsp/repair.sh`
- **check_lsp_status()** (1 connections) — `lib/lsp/status.sh`
- **detect_ohmyposh()** (1 connections) — `lib/ohmyposh/detect.sh`
- **install_isolated_ohmyposh()** (1 connections) — `lib/ohmyposh/install.sh`
- **check_update()** (1 connections) — `lib/core/remaining.sh`
- **create_symlink_only()** (1 connections) — `lib/core/remaining.sh`
- **install_isolated_router()** (1 connections) — `lib/router/install.sh`
- **_priv_run()** (1 connections) — `lib/sandbox/install.sh`

## Relationships

- No strong cross-community connections detected

## Source Files

- `lib/config/isolated.sh`
- `lib/config/status.sh`
- `lib/core/init.sh`
- `lib/core/remaining.sh`
- `lib/lsp/install.sh`
- `lib/lsp/repair.sh`
- `lib/lsp/status.sh`
- `lib/ohmyposh/detect.sh`
- `lib/ohmyposh/install.sh`
- `lib/ohmyposh/status.sh`
- `lib/router/detect.sh`
- `lib/router/install.sh`
- `lib/sandbox/install.sh`

## Audit Trail

- EXTRACTED: 41 (95%)
- INFERRED: 2 (5%)
- AMBIGUOUS: 0 (0%)

---

*Part of the graphify knowledge wiki. See [[index]] to navigate.*