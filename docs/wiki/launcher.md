# Launcher

The launcher module (`lib/launcher/launch.sh`) is the final stage of iclaude startup. It assembles the runtime environment, starts optional subsystems (router, PII proxy, microVM), and hands off to the Claude Code binary via `exec` or SSH.

## Entry Point

`launch_claude()` is the single public function. It accepts an optional first argument `skip_isolated` (`"true"` skips the isolated NVM environment) and passes all remaining arguments through to the Claude binary. It does not return — it ends with `exec` or, when the PII proxy is active, by invoking the binary and calling `exit $?` to allow the EXIT trap to fire cleanup.

## Pre-launch Steps

Before selecting a binary, `launch_claude()` performs three housekeeping actions in order:

1. **`_sync_graphify_env_to_settings()`** — writes the current value of `GRAPHIFY_OUT` into the `env` block of `settings.json` so that Bash tool subshells (which do not inherit exported variables) see the same output path as the parent process (see [[graphify]] for the knowledge-graph subsystem itself).
2. **`unset CHROME_DESKTOP`** — VS Code sets `CHROME_DESKTOP=code.desktop`; leaving it set causes the Claude-in-Chrome extension to open the wrong browser.
3. **`check_oauth_token`** and **`cleanup_stale_session_env`** — validates OAuth before launch and removes old per-session directories under `$ISOLATED_CONFIG_DIR/session-env/` (empty dirs after 7 days, non-empty after 28 days, configurable via `SESSION_ENV_RETENTION_DAYS`).

## Mode Selection

Three runtime modes are evaluated before binary detection:

- **Router** (`USE_ROUTER_FLAG=true`): calls `detect_router()`, then either `exec ccr code "$@"` (solo) or starts CCR as a background daemon via `start_ccr_server()` (combined mode with PII proxy).
- **microVM** (`USE_MICRO_VM_FLAG=true`): calls `detect_microvm()`, runs workspace sync (rsync or tar-over-SSH), starts an SSH ControlMaster, and runs claude inside the guest as `iclaude@<guest_ip>` via `ssh`. Flags `--chrome` and `--ide` are stripped from the forwarded argument list because those subsystems run on the host and cannot reach the guest network.
- **PII proxy** (`USE_PII_PROXY_FLAG=true`): calls `start_pii_proxy_server()`, redirects `ANTHROPIC_BASE_URL` to `http://127.0.0.1:<port>`, and registers a cleanup trap.

None of these modes are mutually exclusive; `launch_claude()` handles all combinations including microVM + PII + router (three-way chain).

## Attribution Header

When router mode or `--no-attribution-header` (`NO_ATTRIBUTION_HEADER=true`) is active and `CLAUDE_CODE_ATTRIBUTION_HEADER` is not already set in the environment, the function exports `CLAUDE_CODE_ATTRIBUTION_HEADER=0`. This prevents the billing hash (`cch=`) that Claude Code appends to each request from invalidating KV cache on proxies and routers.

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

Rsync is used when the guest rootfs includes it (v7+); older rootfs images fall back to tar-over-SSH. The SSH ControlMaster reduces per-operation overhead from ~200 ms to ~5 ms; `ControlPersist=60` auto-closes orphaned connections.

Files excluded from sync: `.nvm-isolated/`, `.git/`, `.claude_config`, `.claude_proxy_credentials`, `.iclaude-guest-env.sh`, `.iclaude-ssh/`. Additional exclusions can be added via `MICRO_VM_SYNC_EXCLUDE` (colon-separated).

## Session Environment Cleanup

`cleanup_stale_session_env()` is called unconditionally on every launch. It removes directories under `$ISOLATED_CONFIG_DIR/session-env/` whose mtime exceeds the retention thresholds. The function is safe for concurrent sessions because active directories have recent mtimes.

## PII Proxy Lifecycle Functions

`launch.sh` also contains:

- `start_pii_proxy_server()` / `stop_pii_proxy_server()` — per-session and shared-proxy start/stop, consumer reference counting, orphan cleanup.
- `start_ccr_server()` / `stop_ccr_server()` — CCR background daemon lifecycle for combined mode.
- `cleanup_orphaned_pii_proxies()` — sweeps dead PID and port files from previous sessions, rotates session logs older than `PII_LOG_RETENTION_DAYS` (default 7).

See [[pii-proxy]] for the proxy server itself, [[router]] for CCR configuration, and [[chrome]] for the Chrome integration toggle.
