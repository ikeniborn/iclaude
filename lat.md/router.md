# Router

Claude Code Router (CCR) integration — routes Claude API traffic to alternative providers (OpenRouter, DeepSeek, Ollama, Bedrock). Activated via `--router` flag.

## How It Works

In solo router mode, `launch_claude()` uses `exec ccr code "$@"` — CCR becomes the process and internally spawns Claude Code with `ANTHROPIC_BASE_URL` pointed at its own HTTP server.

In combined PII+router mode, CCR runs as a background daemon (`ccr start`) and PII proxy chains in front of it.

## CCR Config

Router config lives at `$ISOLATED_CONFIG_DIR/router.json`. Copied to `$CCR_HOME/.claude-code-router/config.json` before launch so CCR reads the isolated config, not `~/.claude-code-router/config.json`.

`CCR_HOME` is set to `$ISOLATED_CONFIG_DIR` (isolated mode) or `$HOME` (system mode) to keep CCR state out of the global home directory.

## Node.js Requirement

CCR v2.0.0 requires Node.js v20+ (`File` global unavailable in v18). `launch_claude()` prepends the highest v20+ node version from `$ISOLATED_NVM_DIR/versions/node/` to `PATH` before running CCR.

## Port Configuration

`get_ccr_port()` parses `CCR_HOST` and `CCR_PORT` from `router.json`. Defaults: `127.0.0.1:3456`.

If CCR is already running on `CCR_HOST:CCR_PORT` when combined mode starts, `start_ccr_server()` reuses it (`CCR_SESSION_OWNED=false`) instead of starting a new daemon.

## Attribution Header

Router mode auto-sets `CLAUDE_CODE_ATTRIBUTION_HEADER=0` to disable the `cch=` billing hash.

The hash changes per-request and invalidates KV cache on proxies (CCR/Ollama/Bedrock) that treat the system prompt as a cache key. Only set if not already in environment — respects user override.

## Transformers

Custom CCR transformers are defined in `router.json` under the `transformers` array. Each entry has a `path` pointing to a JS plugin.

Use `${CLAUDE_CONFIG_DIR}` in `path` instead of an absolute filesystem path — CCR expands `${VAR}` at startup from the inherited environment. This keeps `router.json` portable across machines and directory moves (both files are tracked in git).

```json
"transformers": [
  { "path": "${CLAUDE_CONFIG_DIR}/.claude-code-router/plugins/ollama-reasoning.js" }
]
```

## API Keys

CCR requires a real API key (`sk-ant-api03-...`), not an OAuth token (`sk-ant-oat01-...`). Store in `.claude_config`:
```bash
export DEEPSEEK_API_KEY=...
export OPENROUTER_API_KEY=...
```
