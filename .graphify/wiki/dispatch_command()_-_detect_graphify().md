# dispatch_command() / detect_graphify()

> 52 nodes · cohesion 0.07

## Key Concepts

- **iclaude.sh (main entry point)** (28 connections) — `iclaude.sh`
- **launch_claude()** (15 connections) — `lib/launcher/launch.sh`
- **start_pii_proxy_server()** (9 connections) — `lib/launcher/launch.sh`
- **ISOLATED_NVM_DIR (env var)** (9 connections) — `lib/nvm/setup.sh`
- **setup_isolated_nvm()** (8 connections) — `lib/nvm/setup.sh`
- **install_from_lockfile()** (7 connections) — `lib/lockfile/install.sh`
- **install_graphify()** (6 connections) — `lib/graphify/install.sh`
- **save_isolated_lockfile()** (6 connections) — `lib/lockfile/save.sh`
- **_graphify_rebuild_graph()** (5 connections) — `lib/graphify/install.sh`
- **check_lockfile_changes()** (5 connections) — `lib/lockfile/save.sh`
- **detect_pii_proxy()** (5 connections) — `lib/pii-proxy/detect.sh`
- **detect_graphify()** (4 connections) — `lib/graphify/detect.sh`
- **_patch_graphify_watch()** (4 connections) — `lib/graphify/install.sh`
- **check_graphify_status()** (4 connections) — `lib/graphify/status.sh`
- **start_ccr_server()** (4 connections) — `lib/launcher/launch.sh`
- **update_lockfile_hash()** (4 connections) — `lib/lockfile/save.sh`
- **detect_nvm()** (4 connections) — `lib/nvm/detect.sh`
- **install_isolated_nvm()** (4 connections) — `lib/nvm/install.sh`
- **GRAPHIFY_OUT (env var)** (4 connections) — `iclaude.sh`
- **GRAPHIFY_TOOL_DIR (env var)** (4 connections) — `lib/graphify/install.sh`
- **_graphify_resolve_proxy()** (3 connections) — `lib/graphify/install.sh`
- **_graphify_resolve_uv()** (3 connections) — `lib/graphify/install.sh`
- **get_nvm_claude_path()** (3 connections) — `lib/nvm/detect.sh`
- **ISOLATED_LOCKFILE (env var)** (3 connections) — `lib/lockfile/save.sh`
- **stop_pii_proxy_server()** (2 connections) — `lib/launcher/launch.sh`
- *... and 27 more nodes in this community*

## Relationships

- No strong cross-community connections detected

## Source Files

- `iclaude.sh`
- `lib/command/dispatch.sh`
- `lib/command/parse.sh`
- `lib/command/usage.sh`
- `lib/graphify/detect.sh`
- `lib/graphify/install.sh`
- `lib/graphify/status.sh`
- `lib/launcher/launch.sh`
- `lib/lockfile/install.sh`
- `lib/lockfile/save.sh`
- `lib/nvm/claude.sh`
- `lib/nvm/cleanup.sh`
- `lib/nvm/detect.sh`
- `lib/nvm/install.sh`
- `lib/nvm/setup.sh`
- `lib/pii-proxy/detect.sh`
- `lib/pii-proxy/status.sh`
- `lib/router/status.sh`

## Audit Trail

- EXTRACTED: 190 (97%)
- INFERRED: 5 (3%)
- AMBIGUOUS: 0 (0%)

---

*Part of the graphify knowledge wiki. See [[index]] to navigate.*