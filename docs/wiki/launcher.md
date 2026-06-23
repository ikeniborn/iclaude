# Launcher

## Overview

The launcher module (`lib/launcher/launch.sh`) is the final stage of iclaude startup. It assembles the runtime environment, starts optional subsystems (router, PII proxy, microVM), and hands off to the Claude Code binary via `exec` or SSH.

## Entry Point

`launch_claude()` is the single public function. It accepts an optional first argument `skip_isolated` (`"true"` skips the isolated NVM environment) and passes all remaining arguments through to the Claude binary. It does not return — it ends with `exec` or, when the PII proxy is active, by invoking the binary and calling `exit $?` to allow the EXIT trap to fire cleanup.

## Pre-launch Steps

Before selecting a binary, `launch_claude()` performs two housekeeping actions in order:

1. **`unset CHROME_DESKTOP`** — VS Code sets `CHROME_DESKTOP=code.desktop`; leaving it set causes the Claude-in-Chrome extension to open the wrong browser.
2. **`check_oauth_token`** and **`cleanup_stale_session_env`** — validates OAuth before launch and removes old per-session directories under `$ISOLATED_CONFIG_DIR/session-env/` (empty dirs after 7 days, non-empty after 28 days, configurable via `SESSION_ENV_RETENTION_DAYS`).

## Mode Selection

Three runtime modes are evaluated before binary detection:

- **Router** (`USE_ROUTER_FLAG=true`): calls `detect_router()`, then either `exec ccr code "$@"` (solo) or starts CCR as a background daemon via `start_ccr_server()` (combined mode with PII proxy).
- **microVM** (`USE_MICRO_VM_FLAG=true`): calls `detect_microvm()`, runs workspace sync (rsync or tar-over-SSH), starts an SSH ControlMaster, and runs claude inside the guest as `iclaude@<guest_ip>` via `ssh`. Flags `--chrome` and `--ide` are stripped from the forwarded argument list because those subsystems run on the host and cannot reach the guest network.
- **PII proxy** (`USE_PII_PROXY_FLAG=true`, or `USE_LANGFUSE_CAPTURE=true` for capture-only): `_should_start_proxy` starts `start_pii_proxy_server()` when masking OR Langfuse capture is requested, redirects `ANTHROPIC_BASE_URL` to `http://127.0.0.1:<port>`, and registers a cleanup trap. For capture-only sessions `_proxy_masking_default` forces `PII_PROXY_MASKING_LEVEL=off` so the proxy runs purely as the auth + capture hop. See [[langfuse-capture#Activation]].

None of these modes are mutually exclusive; `launch_claude()` handles all combinations including microVM + PII + router (three-way chain).

## Attribution Header

When router mode or `--no-attribution-header` (`NO_ATTRIBUTION_HEADER=true`) is active and `CLAUDE_CODE_ATTRIBUTION_HEADER` is not already set in the environment, the function exports `CLAUDE_CODE_ATTRIBUTION_HEADER=0`. This prevents the billing hash (`cch=`) that Claude Code appends to each request from invalidating KV cache on proxies and routers.

## Per-Project Tagging

In router mode OR Langfuse-capture mode, `launch_claude()` calls `_init_project_id "$use_router" "$use_langfuse_capture"` before any CCR or PII-proxy fork — to export `ICLAUDE_PROJECT_ID`. The value is the git toplevel basename (or `$PWD` basename) sanitized to a tag-safe slug by `_derive_project_id()`; an explicit value already in the environment is preserved. CCR's `x-project-id` transformer (router) forwards it as the `X-Project-Id` header, and the PII-proxy Langfuse emitter (capture) uses it directly; both record `project:<repo-name>`. See [[router#Per-Project Tagging (X-Project-Id → Langfuse)]] and [[langfuse-capture]] for the two chains.

## Binary Detection

When running natively (no microVM), `launch_claude()` locates the Claude Code binary in priority order:

1. NVM isolated environment (`get_nvm_claude_path()` via `detect_nvm()`).
2. System paths: `/usr/local/bin/claude`, `/usr/bin/claude`, then `$PATH`.
3. npm global prefix (`npm prefix -g`), including temporary `.claude-*` binaries.

If none are found, an actionable error is printed and the function exits 1. See [[nvm#Claude Binary Detection]] for the three-step detection order (npm symlink → `bin/claude.exe` native binary → legacy `cli.js`).

## Final Exec

In the standard path the binary is launched with:

```bash
exec "${claude_cmd_arr[@]}" "$@"
```

`claude_cmd` is split into an array (`read -ra`) to support the legacy two-word form `node /path/cli.js`. When the PII proxy is active, `exec` is replaced with a plain invocation followed by `exit $?` so the EXIT trap can call `stop_pii_proxy_server()`.

## microVM Workspace Sync

`MICRO_VM_WORKSPACE_MODE` controls sync direction:

- `full` (default): host→guest at start, guest→host at exit. Periodic background sync is available via `MICRO_VM_SYNC_INTERVAL` (seconds; 0 = disabled).
- `isolated`: host→guest only; guest changes are discarded.

Rsync is used when the guest has a **working** rsync (v7+ rootfs with the rsync bundle); otherwise sync falls back to tar-over-SSH. Detection runs `rsync --version` in the guest, not `command -v rsync` — a bare-binary injection (older v7) leaves an rsync that exists but exits 127 (`error while loading shared libraries: libpopt.so.0`), so a mere presence check would wrongly pick rsync and every sync would fail. Executing it proves it loads. Current rootfs images ship a self-contained rsync bundle (host binary + lib closure + loader + wrapper under `/opt/iclaude-rsync/`, see [[sandbox#Installation]]) so the probe passes and delta sync is used. The SSH ControlMaster reduces per-operation overhead from ~200 ms to ~5 ms; `ControlPersist=60` auto-closes orphaned connections.

A single canonical exclude list (`_rsync_excludes`, derived once) is shared by **all** sync directions — host→guest start, the periodic background sync, and the guest→host sync-back. Sharing it is load-bearing: host-only paths (`.git/`, `.nvm-isolated/`, `.claude_config`, ...) are absent in the guest, so without the exclude a `rsync --delete` on sync-back would WIPE them from the host. The list also excludes `lost+found` — the guest's fresh ext4 image has a root-owned `lost+found` (mode 0700) that the non-root guest user cannot `opendir`, so a `--delete` scan over it fails with EACCES (rsync exit 23, "workspace sync had errors") even though files transfer fine; excluding it skips the scan.

Files excluded from sync: `.nvm-isolated/`, `.git/`, `.claude_config`, `.claude_proxy_credentials`, `.iclaude-guest-env.sh`, `.iclaude-ssh/`, `.claude-guest/`, `lost+found/`. Additional exclusions can be added via `MICRO_VM_SYNC_EXCLUDE` (colon-separated).

Sync stderr is captured to `/tmp/iclaude-<session-id>-sync.log` (not discarded) so failures are diagnosable; on error the warning names the log path. The guest's auth credential is forwarded separately via the env file, not the workspace sync — see [[sandbox#Guest Environment & Authentication]].

**Deletions on the tar fallback.** `tar -x` only adds/overwrites — it cannot remove files deleted in the guest. So `full` mode would lose guest→host deletions on the tar path. To fix this without rsync, after each tar guest→host sync the launcher fetches the guest's file list (`find` over `/workspace`, same protected-path prune as the sync excludes) and `_microvm_mirror_deletions()` removes host workspace files absent from that list — giving tar the same delete semantics `rsync --delete` provides natively (the rsync path does not call it). It is a no-op unless the guest scan succeeds and returns a non-empty list, so a transient SSH/scan error never mass-deletes host files. The rsync bundle ([[sandbox#Installation]]) is still preferred for speed (delta vs full-copy); the launcher prints an info line nudging `--install-microvm` when it falls back to tar.

## Session Environment Cleanup

`cleanup_stale_session_env()` is called unconditionally on every launch. It removes directories under `$ISOLATED_CONFIG_DIR/session-env/` whose mtime exceeds the retention thresholds. The function is safe for concurrent sessions because active directories have recent mtimes.

## PII Proxy Lifecycle Functions

`launch.sh` also contains:

- `start_pii_proxy_server()` / `stop_pii_proxy_server()` — per-session and shared-proxy start/stop, consumer reference counting, orphan cleanup.
- `start_ccr_server()` / `stop_ccr_server()` — CCR background daemon lifecycle for combined mode.
- `cleanup_orphaned_pii_proxies()` — sweeps dead PID and port files from previous sessions, rotates session logs older than `PII_LOG_RETENTION_DAYS` (default 7).

See [[pii-proxy]] for the proxy server itself, [[router]] for CCR configuration, and [[chrome]] for the Chrome integration toggle.
