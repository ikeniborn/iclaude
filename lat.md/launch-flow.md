# Launch Flow

`launch_claude()` in `[[lib/launcher/launch.sh]]` is the final stage before Claude Code runs. It decides which execution path to use based on active flags.

## Decision Tree

Flags are checked in this order; each path is mutually exclusive at the `exec` level:

```
launch_claude()
├── sync GRAPHIFY_OUT → settings.json env block
├── unset CHROME_DESKTOP  (VS Code sets this; confuses Claude-in-Chrome)
├── check_oauth_token()
├── cleanup_stale_session_env()
│
├── [USE_MICRO_VM_FLAG=true]
│   ├── start CCR daemon (if --router)
│   ├── start PII proxy (if --pii-proxy)
│   ├── start_microvm()
│   ├── rsync workspace → guest
│   ├── SSH into guest → run claude
│   ├── rsync workspace ← guest (full mode)
│   └── stop microVM + proxy + CCR (trap EXIT/INT/TERM)
│
├── [USE_ROUTER_FLAG=true, no microVM]
│   ├── [--pii-proxy]: start CCR daemon + PII proxy → fall through to native launch
│   └── [solo]: exec ccr code "$@"
│
└── [native launch]
    ├── [--pii-proxy]: start_pii_proxy_server() + run claude (no exec — EXIT trap needed)
    └── [standard]: exec "${claude_cmd_arr[@]}" "$@"
```

## Binary-Absent Error Handling

When `claude_cmd` is empty after all detection steps, `launch_claude()` exits 1 with a context-aware message:

| `skip_isolated` | Message |
|-----------------|---------|
| `false` (default) | `--repair-isolated` hint |
| `true` (`--system` flag) | `npm install -g` hint |

The npx fallback (`npx @anthropic-ai/claude-code`) was removed. Binaries are delivered only via CI/CD (`git pull` + `--install-from-lockfile`).

## Pull-Time Binary Refresh

`bin/claude.exe` is gitignored, so `git pull` delivers the version bump in the tracked metadata but not the executable. Two pieces close the gap.

Both compare the lockfile `claudeCodeVersion` against the **real binary** (`claude --version`, not the tracked `package.json`) and reuse `--install-from-lockfile`:

- **`.githooks/post-merge`** — proactive, fires after `git pull`. Opt-out via `ICLAUDE_NO_AUTO_UPDATE=1`; guards on the lockfile actually changing in the merge; fail-soft (silent in-sync, warn-only non-interactive, never blocks the pull).
- **`check_lockfile_changes()`** (`[[lib/lockfile/save.sh#check_lockfile_changes]]`) — reactive fallback at iclaude launch, for pulls that bypass git hooks (GUI clients, opt-out, fresh clone before `--repair-isolated`).

## Attribution Header

When `--router` or `--no-attribution-header` is active, `CLAUDE_CODE_ATTRIBUTION_HEADER=0` is set. This disables the `x-anthropic-billing-header` (`cch=`) that changes every request and invalidates KV cache on CCR/Ollama/Bedrock proxies.

## Combined Modes

Traffic chains when multiple features are active simultaneously.

| Mode | Chain |
|------|-------|
| PII only | `claude → PII proxy(:PORT) → api.anthropic.com` |
| Router only | `exec ccr code → providers` |
| PII + Router | `claude → PII proxy(:PORT) → CCR(:3456) → providers` |
| microVM only | `SSH → guest claude → api.anthropic.com` |
| microVM + PII | `SSH → guest claude → PII proxy(host:PORT) → api.anthropic.com` |
| microVM + PII + Router | `SSH → guest claude → PII proxy → CCR → providers` |
