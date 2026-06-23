# Launcher

## Overview

The launcher (`lib/launcher/launch.sh`) is the final startup stage. `launch_claude()` assembles the runtime, optionally starts router, PII proxy, and microVM (in any combination), tags traces per-project, then hands off to the Claude binary via `exec`, a non-exec invocation, or SSH into the guest. Helpers manage proxy/CCR lifecycle and stale-state cleanup.

## Entry Point

`launch_claude()` is the single public launch function. Its optional first argument `skip_isolated` (`"true"` = system mode, skip the isolated NVM env) is shifted off; the rest pass through to the binary. It never returns — it ends with `exec`, or (when a host-side proxy must outlive the call) a plain invocation followed by `exit $?` so the EXIT trap fires cleanup.

## Pre-launch Steps

Before mode selection, `launch_claude()` runs three housekeeping actions in order: `unset CHROME_DESKTOP` (VS Code sets `CHROME_DESKTOP=code.desktop`, which misdirects the Claude-in-Chrome extension); `check_oauth_token "$skip_isolated"` (validates OAuth, see [[oauth]]); and `cleanup_stale_session_env` (prunes old per-session env dirs, always).

## Mode Selection

Four flags are resolved before binary detection, and they compose freely:

- **Router** (`USE_ROUTER_FLAG=true` + `detect_router`) → `use_router`. See [[router#Detection]].
- **Langfuse capture** (`USE_LANGFUSE_CAPTURE=true`, config-only) → `use_langfuse_capture`, gated by `_should_capture`, which **suppresses capture in router mode** (LiteLLM already emits to Langfuse there — avoids double traces). See [[langfuse-capture#Activation]].
- **microVM** (`USE_MICRO_VM_FLAG=true` + `detect_microvm`) → `use_microvm`. Aborts in `--system` mode (isolated env only); a missing install warns and continues without isolation. See [[sandbox#Detection]].
- **PII proxy** (`USE_PII_PROXY_FLAG=true` OR capture requested, via `_should_start_proxy`) → `use_pii_proxy`. Aborts in `--system` mode (needs the isolated venv — fail-secure). For capture-only sessions `_proxy_masking_default` forces `PII_PROXY_MASKING_LEVEL=off` so the proxy is just the auth + capture hop. See [[pii-proxy#Detection]].

A `print_info` line names the active combination (e.g. "microVM + PII masking → CCR router chain"). The full three-way chain is `claude → PII proxy → CCR → providers`.

## Attribution Header

When router mode or `--no-attribution-header` (`NO_ATTRIBUTION_HEADER=true`) is active and `CLAUDE_CODE_ATTRIBUTION_HEADER` is not already set in the environment, the function exports `CLAUDE_CODE_ATTRIBUTION_HEADER=0`. This drops the per-request billing hash (`cch=`), which would otherwise invalidate KV cache on proxies/routers (Ollama, CCR, Bedrock) that fold it into the system prompt. An explicit env value is left untouched.

## Per-Project Tagging

In router OR Langfuse-capture mode, `_init_project_id` runs before any CCR/PII-proxy fork and exports `ICLAUDE_PROJECT_ID`. The value comes from `_derive_project_id()`: the git toplevel basename (else `$PWD` basename), lowercased and slugified (non-`[a-z0-9._-]` runs → `-`, edges trimmed, empty → `unknown`). An explicit env value is preserved. CCR's `x-project-id` transformer forwards it as the `X-Project-Id` header; the PII-proxy Langfuse emitter reads it directly — both record `project:<repo>`. See [[router#Per-Project Tagging (X-Project-Id → Langfuse)]] and [[langfuse-capture]].

## microVM Launch Path

When `use_microvm`, the launcher runs `cleanup_orphaned_microvm_sessions` (sweeps stale Firecracker sockets/dirs), starts CCR and/or the PII proxy **on the host first** (so `configure_guest_environment()` can see their ports), then `start_microvm`. Any start failure tears down what was already up and exits 1. A combined cleanup trap (`_cm_cleanup` + `stop_microvm` + the active host servers) is registered on EXIT/INT/TERM. E2E hooks (`ICLAUDE_E2E_KILL_AFTER_BOOT`, `ICLAUDE_E2E_EXIT_AFTER_BOOT`) allow crash/clean-exit simulation right after boot. Claude then runs inside the guest as `iclaude@<guest_ip>` via SSH; `--chrome` and `--ide` are stripped from the forwarded args (those subsystems live on the host). See [[sandbox#Runtime (start_microvm)]].

## microVM SSH ControlMaster

A persistent SSH mux (`ssh -M -N -f`, `ControlPersist=60`) is opened to the guest, cutting per-op overhead from ~200 ms to ~5 ms; orphaned connections auto-close after 60 s. Host-key verification uses the pinned `MICRO_VM_KNOWN_HOSTS` file when present (`StrictHostKeyChecking=yes`), else falls back to no verification with a warning nudging `--install-microvm`. Two `rsync -e` command strings are pre-built: `_e_ssh_cmd` (via the mux socket) and `_e_ssh_fallback` (direct, longer timeouts, for the final sync). The interactive Claude session requests a PTY (`-t`) only when stdin is a terminal.

## microVM Workspace Sync

`MICRO_VM_WORKSPACE_MODE` controls direction: `full` (default) syncs host→guest at start and guest→host at exit; `isolated` is host→guest only (guest changes discarded). Optional periodic background sync runs every `MICRO_VM_SYNC_INTERVAL` seconds (0 = off; set via `ICLAUDE_MICRO_VM_SYNC_INTERVAL`, de-prefixed by the [[config#Environment Variable Export]] layer), with a lock file for overlap protection and a check that the FC socket still exists.

Rsync is used only when the guest has a **working** rsync: detection runs `rsync --version` in the guest, not `command -v rsync` — a bare-binary injection (older v7 rootfs) leaves an rsync that exists but exits 127 (`error while loading shared libraries: libpopt.so.0`), so a presence check would wrongly pick it and every sync would fail. Current images ship a self-contained bundle under `/opt/iclaude-rsync/` (see [[sandbox#Installation]]) so the probe passes and delta sync is used. Otherwise sync falls back to tar-over-SSH (full gzip copy each time); an info line nudges `--install-microvm`.

## microVM Sync Excludes and Deletions

A single canonical exclude list (`_sync_excludes`, rsync-form `_rsync_excludes` derived once) is shared by **all** directions — host→guest start, periodic, and exit-time sync-back. Sharing it is load-bearing: host-only paths (`.git/`, `.nvm-isolated/`, `.claude_config`, `.claude_proxy_credentials`, `.iclaude-guest-env.sh`, `.iclaude-ssh/`, `.claude-guest/`) are absent in the guest, so without the exclude a `rsync --delete` sync-back would WIPE them from the host. `lost+found/` is also excluded: the guest's fresh ext4 image has a root-owned `lost+found` (0700) the non-root user cannot `opendir`, so a `--delete` scan over it fails EACCES (rsync exit 23) though files transfer fine. Extra paths via `MICRO_VM_SYNC_EXCLUDE` (colon-separated).

On the **tar fallback**, `tar -x` only adds/overwrites — it cannot remove guest-deleted files, so `full` mode would lose deletions. After each tar guest→host sync the launcher fetches the guest's file list (`_MICROVM_GUEST_SCAN_CMD`, same protected-path prune) and `_microvm_mirror_deletions()` removes host files absent from it — matching `rsync --delete` semantics (the rsync path never calls it). It is a no-op on an empty list, so a transient SSH/scan error never mass-deletes. Sync stderr is captured to `/tmp/iclaude-<session-id>-sync.log` (not discarded) so failures name a log path.

## Router Launch Path (native)

In solo router mode the launcher resolves `ccr_cmd` via `get_router_path`, overrides `HOME` to the isolated env (`CCR_HOME`, since CCR has no `CCR_HOME` var and reads `os.homedir()`), copies `router.json` into `~/.claude-code-router/config.json`, prepends a Node v20+ bin (CCR 2.0.0 needs the `File` global) plus `npm-global/bin` to `PATH`, exports `ICLAUDE_ROUTER_ACTIVE=1` (statusline signal), then `HOME="$ccr_home" exec "$ccr_cmd" code "$@"`. In **combined PII+router** mode it instead starts CCR as a background daemon and the PII proxy in front of it, registers a `stop_pii_proxy_server; stop_ccr_server` trap, and falls through to the native claude launch (no exec). See [[router#Combined Mode: PII Proxy + Router]].

## Binary Detection

For the native (non-microVM) launch the binary is located in priority order: (1) NVM isolated env via `get_nvm_claude_path()` after `detect_nvm`; (2) system paths `/usr/local/bin/claude`, `/usr/bin/claude`, then `$PATH` (local/cwd installs are skipped with a warning); (3) npm global prefix (`npm prefix -g`), including temporary `.claude-*` binaries. If none is found, an actionable error (system vs. isolated phrasing) is printed and the function exits 1. See [[nvm#Claude Binary Detection]] for the three-step inner order (npm symlink → `bin/claude.exe` native → legacy `cli.js`).

## Final Exec

`claude_cmd` is split into an array via `read -ra` so the legacy two-word form `node /path/cli.js` runs (the native binary is one element). Caveman config is exported through to the hook/statusline when set (`CAVEMAN_DEFAULT_MODE`, `CAVEMAN_STATUSLINE` — see [[caveman]]); `DEBUG_LAUNCH=1` dumps the command and key env vars first. The standard path is `exec "${claude_cmd_arr[@]}" "$@"`. When the PII proxy is active, `exec` is replaced by a plain invocation + `exit $?` so the EXIT trap can call `stop_pii_proxy_server()` — exec would kill the proxy before claude's first request.

## PII Proxy Start

`start_pii_proxy_server()` resolves the venv Python and server script, then walks several reuse guards before starting anything. **Inherited-SID guard:** if `ICLAUDE_PII_ACTIVE=1` and `ANTHROPIC_BASE_URL` are inherited from a parent session (e.g. a Bash-tool sub-invocation), it reuses the parent proxy, sets `PII_PROXY_SESSION_OWNED=false`, and returns before any consumer accounting — so the sub-invocation can never kill the live session's proxy. Combined PII+CCR is excluded (it needs a fresh proxy chained to its own CCR). A same-SID live PID-file check provides a second reuse path. On a successful start it exports `ANTHROPIC_BASE_URL=http://127.0.0.1:<port>`, `ICLAUDE_PII_ACTIVE=1`, masking level, port, log level/path (statusline signals) and polls `/api/health` (TCP probe first, then HTTP; 15 s max). See [[pii-proxy#Architecture]] and [[statusline]].

## Shared PII Proxy Mode

Non-CCR clean-PII sessions share **one** Python process (avoids loading Presidio NLP per session). A `flock` on `shared.lock` serializes the decision: `_sweep_dead_pii_consumers` reaps dead `consumers/<pid>.pid` files (keyed by PID, since one SID can span a session + its Bash-tool calls), then the session either attaches to a live `shared.pid` proxy (registering a consumer, querying `/api/meta` for display) or starts a new one. A live proxy with **zero** registered consumers is treated as an orphan and killed before restart. Owners set `PII_PROXY_SESSION_OWNED=shared`. CCR sessions bypass this entirely (`CCR_UPSTREAM_ACTIVE=true`) and always get a per-session proxy so the chain reaches CCR, not a shared proxy whose upstream was baked as api.anthropic.com.

## CCR Daemon Lifecycle

`start_ccr_server()` parses host/port from `router.json` (`get_ccr_port`). If something is already listening it **reuses** it (`CCR_SESSION_OWNED=false`, `CCR_UPSTREAM_ACTIVE=true`); otherwise it launches `ccr start` (server-only, no claude child) via `nohup`, logs to `ccr-daemon.log`, and polls the port (5 s max). On success it sets `ANTHROPIC_BASE_URL=http://CCR_HOST:CCR_PORT` so the subsequent `start_pii_proxy_server()` captures CCR as its upstream (then overwrites the var with the proxy port). `stop_ccr_server()` kills the daemon only if this session started it (`CCR_SESSION_OWNED=true`), with a graceful-then-SIGKILL wait.

## PII Proxy Stop

`stop_pii_proxy_server()` (trap on EXIT/INT/TERM) branches on ownership: `false` (inherited reuse) does nothing; `shared` deregisters this session's consumer under flock and kills the shared proxy only when no consumers remain; otherwise (per-session owner) it kills the PID, removes the port file, and — in non-debug `info` mode — deletes the session log **after** process termination (so Python's SIGTERM shutdown entry can't recreate it). Debug-mode logs are preserved.

## Cleanup Helpers

Three sweepers keep state tidy across sessions:

- `cleanup_stale_session_env()` — runs every launch; removes `$ISOLATED_CONFIG_DIR/session-env/*` dirs past retention (empty after `SESSION_ENV_RETENTION_DAYS`, default 7; non-empty after ×4, default 28). Safe under concurrency — active dirs have recent mtime.
- `cleanup_orphaned_pii_proxies()` — called from `start_pii_proxy_server()`; drops dead PID/port files (new `pii-proxy-pid/` layout + legacy root files, live legacy ones left so their owners can still stop them), and rotates non-aggregate session logs older than `PII_LOG_RETENTION_DAYS` (default 7; `access.log`/`ccr-daemon.log` never rotated).
- `_sweep_dead_pii_consumers()` / `_register_pii_consumer()` — flock-guarded consumer registry for shared-proxy reference counting.

See [[pii-proxy]] for the proxy server, [[router]] for CCR config, [[sandbox]] for the microVM guest, and [[chrome]] for the Chrome toggle.
