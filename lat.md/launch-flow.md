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

## Attribution Header

When `--router` or `--no-attribution-header` is active, `CLAUDE_CODE_ATTRIBUTION_HEADER=0` is set. This disables the `x-anthropic-billing-header` (`cch=`) that changes every request and invalidates KV cache on CCR/Ollama/Bedrock proxies.

## Combined Modes

| Mode | Chain |
|------|-------|
| PII only | `claude → PII proxy(:PORT) → api.anthropic.com` |
| Router only | `exec ccr code → providers` |
| PII + Router | `claude → PII proxy(:PORT) → CCR(:3456) → providers` |
| microVM only | `SSH → guest claude → api.anthropic.com` |
| microVM + PII | `SSH → guest claude → PII proxy(host:PORT) → api.anthropic.com` |
| microVM + PII + Router | `SSH → guest claude → PII proxy → CCR → providers` |
